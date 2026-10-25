#!/usr/bin/env ruby
# frozen_string_literal: true

# Analyze a Rails schema for index coverage.
# Reports columns that look like foreign keys and have no index leading with them,
# boolean columns that may want a partial index, and columns used in WHERE clauses.
#
# Exit status: 0 when the analysis ran, 1 when it could not run. Findings are
# reported on stdout, so a non-zero status always means the script itself failed.

require "set"

FOREIGN_KEY_COLUMN = /\A\w+_id\z/

def find_rails_root(start_path = ".")
  current = File.expand_path(start_path)
  loop do
    return current if File.exist?(File.join(current, "config", "application.rb"))
    parent = File.dirname(current)
    break if parent == current
    current = parent
  end
  abort "Error: Not in a Rails application directory"
end

# Rails' schema dumper writes indexes as `t.index` inside `create_table` from 5.0
# on, and schemas dumped before that use `add_index` after it, so read both forms.
def parse_schema(schema_file)
  content = File.read(schema_file)
  tables = {}
  current = nil

  content.each_line do |raw_line|
    line = raw_line.strip

    if (match = line.match(/\Acreate_table\s+"([^"]+)"/))
      current = tables[match[1]] = { columns: [], indexes: [], foreign_keys: Set.new }
    elsif current.nil?
      next
    # Only a whole line of `end` closes the block. Matching the letters anywhere
    # would end the table at a column such as "trial_ends_at",
    # hiding every column after it.
    elsif line == "end"
      current = nil
    elsif (match = line.match(/\At\.index\s+(.+)\z/))
      current[:indexes] << index_columns(match[1])
    elsif (match = line.match(/\At\.\w+\s+"([^"]+)"/))
      current[:columns] << match[1]
    end
  end

  content.scan(/^\s*add_index\s+"([^"]+)",\s*(\[[^\]]*\]|"[^"]*")/) do |table_name, argument|
    tables[table_name][:indexes] << index_columns(argument) if tables[table_name]
  end

  content.scan(/^\s*add_foreign_key\s+"([^"]+)",\s*"([^"]+)"(.*)$/) do |from_table, to_table, options|
    info = tables[from_table]
    info[:foreign_keys] << foreign_key_column(info, to_table, options) if info
  end

  tables
end

# `t.index ["a", "b"], name: "x"` and `t.index "a", name: "x"` are both valid, and
# the trailing options carry quoted strings too, so read only the column argument.
def index_columns(argument)
  if (list = argument[/\A\[(.*?)\]/, 1])
    list.scan(/"([^"]*)"/).flatten
  else
    [argument[/\A"([^"]*)"/, 1]].compact
  end
end

# `add_foreign_key "sessions", "users"` names the column implicitly. Match the
# target table against the columns the table actually has, which avoids
# inflection rules ("people" -> "person_id") that plain Ruby cannot apply.
def foreign_key_column(info, to_table, options)
  explicit = options[/\bcolumn:\s*"([^"]+)"/, 1]
  return explicit if explicit

  stem = to_table.split(".").last
  matching = info[:columns].grep(FOREIGN_KEY_COLUMN).select do |column|
    stem.start_with?(column.delete_suffix("_id"))
  end
  matching.max_by(&:length) || "#{stem.sub(/s\z/, "")}_id"
end

def indexed?(info, column)
  info[:indexes].any? { |columns| columns.first == column }
end

# A polymorphic column is served by an index leading with [type, id]. A
# single-column index on the id alone is not the useful shape here.
def polymorphic_index(info, column)
  type_column = column.sub(/_id\z/, "_type")
  return nil unless info[:columns].include?(type_column)

  info[:indexes].find { |columns| columns.first == type_column && columns[1] == column }
end

def analyze_missing_indexes(tables)
  issues = []
  polymorphic_covered = []

  tables.each do |table_name, info|
    candidates = info[:columns].grep(FOREIGN_KEY_COLUMN) | info[:foreign_keys].to_a

    candidates.each do |column|
      next if indexed?(info, column)

      if (composite = polymorphic_index(info, column))
        polymorphic_covered << "#{table_name}.#{column} (covered by [#{composite.join(", ")}])"
        next
      end

      declared = info[:foreign_keys].include?(column)
      issues << {
        table: table_name,
        column: column,
        type: "missing_foreign_key_index",
        severity: declared ? "warning" : "info",
        message: if declared
                   "add_foreign_key declares #{column} on #{table_name} and no index leads with it, " \
                     "so every parent delete or update scans this table"
                 else
                   "#{column} on #{table_name} has no index leading with it, and no add_foreign_key " \
                     "declares it. Confirm the application looks rows up by it — a `_id` suffix also " \
                     "fits an external identifier such as an API id"
                 end,
        suggestion: "add_index :#{table_name}, :#{column}"
      }
    end
  end

  [issues, polymorphic_covered]
end

def analyze_where_clauses(rails_root)
  issues = []
  seen = Set.new

  %w[app/models/**/*.rb app/controllers/**/*.rb].each do |pattern|
    Dir.glob(File.join(rails_root, pattern)).each do |file_path|
      content = File.read(file_path)
      basename = File.basename(file_path, ".rb")

      # Match .where(column: value) or .where("column = ?")
      [/\.where\(\s*(\w+):\s*/, /\.where\(["'](\w+)\s*=/].each do |re|
        content.scan(re).flatten.each do |column|
          key = "#{basename}:#{column}"
          next if seen.include?(key)

          seen << key
          issues << {
            file: file_path,
            column: column,
            type: "where_clause_column",
            severity: "info",
            message: "Column \"#{column}\" used in WHERE clause - consider indexing if queries are slow"
          }
        end
      end
    rescue => e
      # skip unreadable files
    end
  end

  issues
end

def analyze_boolean_columns(tables)
  issues = []
  boolean_names = %w[active enabled published deleted]

  tables.each do |table_name, info|
    info[:columns].each do |column|
      next unless column.start_with?("is_", "has_") || boolean_names.include?(column)
      next if indexed?(info, column)

      issues << {
        table: table_name,
        column: column,
        type: "boolean_index_opportunity",
        severity: "info",
        message: "Boolean column #{column} on #{table_name} has no index. A partial index pays off when " \
                 "queries filter on the value held by the minority of rows",
        suggestion: "add_index :#{table_name}, :#{column}, where: \"#{column} = true\"  " \
                    "# use the value your queries filter on"
      }
    end
  end

  issues
end

rails_root = find_rails_root
schema_file = File.join(rails_root, "db", "schema.rb")

unless File.exist?(schema_file)
  abort "Error: Could not find db/schema.rb"
end

puts "Analyzing database schema at: #{rails_root}"
puts "=" * 80

tables = parse_schema(schema_file)
index_count = tables.sum { |_name, info| info[:indexes].length }
declared_fk_count = tables.sum { |_name, info| info[:foreign_keys].length }
puts "Found #{tables.length} tables, #{index_count} indexes, #{declared_fk_count} declared foreign keys"

missing_fk, polymorphic_covered = analyze_missing_indexes(tables)
where_cols = analyze_where_clauses(rails_root)
boolean_ops = analyze_boolean_columns(tables)

all_issues = missing_fk + where_cols + boolean_ops
by_type = all_issues.group_by { |i| i[:type] }

puts "\nFound #{all_issues.length} indexing opportunities:\n"

if by_type["missing_foreign_key_index"]
  %w[warning info].each do |severity|
    issues = by_type["missing_foreign_key_index"].select { |i| i[:severity] == severity }
    next if issues.empty?

    heading = severity == "warning" ? "DECLARED FOREIGN KEYS WITHOUT AN INDEX" : "OTHER \"_id\" COLUMNS WITHOUT AN INDEX"
    puts "\n#{heading} (#{issues.length} #{severity == "warning" ? "issues" : "to confirm"}):"
    puts "-" * 80
    issues.each do |issue|
      puts "  Table: #{issue[:table]}, Column: #{issue[:column]}"
      puts "  -> #{issue[:message]}"
      puts "  Migration: #{issue[:suggestion]}"
      puts
    end
  end
end

# The bare `add_index` above is safe to paste into an ordinary migration. Building
# an index concurrently needs `disable_ddl_transaction!` as well, so the two are
# shown together rather than leaving a reader to add the flag on its own — a
# concurrent build inside the default transaction raises.
if by_type["missing_foreign_key_index"]
  first = by_type["missing_foreign_key_index"].first
  puts "\nBUILDING THESE ON A LIVE DATABASE:"
  puts "-" * 80
  puts "  Concurrent builds keep reads and writes running, and require disable_ddl_transaction!."
  puts "  That also makes the migration non-atomic, so use one index per migration:"
  puts
  puts "    class AddIndexTo#{first[:table].split("_").map(&:capitalize).join}#{first[:column].split("_").map(&:capitalize).join} < ActiveRecord::Migration[8.1]"
  puts "      disable_ddl_transaction!"
  puts
  puts "      def change"
  puts "        add_index :#{first[:table]}, :#{first[:column]}, algorithm: :concurrently"
  puts "      end"
  puts "    end"
  puts
end

unless polymorphic_covered.empty?
  puts "\nPOLYMORPHIC COLUMNS ALREADY COVERED (#{polymorphic_covered.length}):"
  puts "-" * 80
  puts "  A [type, id] composite is the useful index for these, and each one has it:"
  polymorphic_covered.each { |entry| puts "  - #{entry}" }
  puts
end

if by_type["boolean_index_opportunity"]
  issues = by_type["boolean_index_opportunity"]
  puts "\nBOOLEAN COLUMN INDEXING OPPORTUNITIES (#{issues.length} suggestions):"
  puts "-" * 80
  issues.first(5).each do |issue|
    puts "  Table: #{issue[:table]}, Column: #{issue[:column]}"
    puts "  -> #{issue[:message]}"
    puts "  Migration: #{issue[:suggestion]}"
    puts
  end
  puts "  ... and #{issues.length - 5} more" if issues.length > 5
end

if by_type["where_clause_column"]
  issues = by_type["where_clause_column"]
  unique_cols = issues.map { |i| i[:column] }.uniq.sort
  puts "\nCOLUMNS USED IN WHERE CLAUSES (#{unique_cols.length} columns):"
  puts "-" * 80
  puts "  Consider adding indexes to these columns if queries are slow:"
  unique_cols.first(10).each { |col| puts "  - #{col}" }
  puts "  - ... and #{unique_cols.length - 10} more" if unique_cols.length > 10
  puts
end

if all_issues.empty?
  puts "No obvious indexing issues detected!"
end
