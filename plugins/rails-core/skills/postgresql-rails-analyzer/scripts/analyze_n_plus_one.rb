#!/usr/bin/env ruby
# frozen_string_literal: true

# Analyze Rails controllers for N+1 queries.
#
# Reads the association names the application declares in app/models, then looks
# for a query that is not eager loaded, iterated in the same file, with one of
# those associations touched on the block variable. Grounding the association
# names in the models is what keeps `post.title.upcase` out of the results.
#
# Exit status: 0 when the analysis ran, 1 when it could not run. Findings are
# reported on stdout, so a non-zero status always means the script itself failed.

RELATION_METHODS = %w[
  all where order reorder limit offset joins left_joins group having select distinct
  unscoped none find_by find_each in_batches pluck ids first last take
  includes preload eager_load
].freeze

EAGER_LOADING = /\b(?:includes|preload|eager_load)\(([^)]*)\)/

ITERATION = /
  # A lookbehind rather than \b, because \b never matches between a space and
  # the @ of an instance variable. The receiver is a chain rather than a bare
  # name so that `Model.where(...).map { }`, iterated without ever being bound
  # to a name, is still recognised as a query.
  (?<![\w.@])(?<receiver>@?\w+(?:\.\w+(?:\([^()]*\))?)*?)
  \.(?:each|each_with_index|each_with_object|map|flat_map|filter_map|collect|select|reject|sum|group_by|partition|find|detect|sort_by|min_by|max_by)
  \s*(?:\(.*?\)\s*)?
  (?:do|\{)
  \s*\|\s*(?<variable>\w+)
/x

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

# The application's own association declarations are the authority on what counts
# as an association access. Without them every `record.attribute.method` chain
# looks the same as an N+1.
def association_names(rails_root)
  names = {}

  Dir.glob(File.join(rails_root, "app", "models", "**", "*.rb")).each do |file_path|
    File.read(file_path).scan(
      /^\s*(?:belongs_to|has_one|has_many|has_and_belongs_to_many)\s+:(\w+)/
    ).flatten.each { |name| names[name] = file_path }
  rescue StandardError
    next
  end

  names
end

def query_expression?(source)
  return false unless source.match?(/\b[A-Z]\w*\./) || source.match?(/\b\w+\.(?:#{RELATION_METHODS.join("|")})\b/)

  source.match?(/\.(?:#{RELATION_METHODS.join("|")})\b/)
end

# Every word inside includes(...) / preload(...) / eager_load(...), which covers
# the nested `includes(posts: :comments)` form as well as a plain symbol list.
def eager_loaded(source)
  source.scan(EAGER_LOADING).flatten.join(" ").scan(/\w+/)
end

# Ruby blocks are not regular, so rather than matching braces this walks forward
# to the first line that closes a block at or above the opening indentation.
def block_body(lines, opening_index)
  opening = lines[opening_index]
  return [opening] if opening.match?(/\{[^}]*\|\s*\w+\s*\|[^}]*\}/)

  indent = opening[/\A\s*/].length
  body = [opening]

  ((opening_index + 1)...lines.length).each do |index|
    line = lines[index]
    stripped = line.strip
    break if (stripped == "end" || stripped == "}" || stripped.start_with?("end)", "end.", "}.")) &&
             line[/\A\s*/].length <= indent
    break if stripped.start_with?("def ")

    body << line
  end

  body
end

# What is being iterated: a name bound to a query earlier in the method, a query
# written inline, or a has_many read straight off a record. All three produce one
# query per iteration when the loop touches a further association.
def binding_for(receiver, index, associations, bindings)
  return bindings[receiver] if bindings[receiver]

  last_segment = receiver[/(\w+)\z/, 1]
  return unless query_expression?(receiver) || (last_segment && associations.key?(last_segment))

  { line: index + 1, eager_loaded: eager_loaded(receiver) }
end

def analyze_controller(file_path, content, associations)
  issues = []
  lines = content.split("\n")

  # One forward pass, so a name resolves to the assignment above it rather than to
  # whichever assignment happens to come last in the file. Bindings reset at each
  # method, which keeps one action's query from being attributed to another's loop.
  bindings = {}

  lines.each_with_index do |line, index|
    bindings.clear if line.match?(/\A\s*def\s/)

    if (assignment = line.match(/\A\s*(@?\w+)\s*(?:\|\|)?=\s*(.+)\z/))
      name, source = assignment.captures
      bindings[name] = { line: index + 1, eager_loaded: eager_loaded(source) } if query_expression?(source)
    end

    match = line.match(ITERATION)
    next unless match

    binding = binding_for(match[:receiver], index, associations, bindings)
    next unless binding

    variable = match[:variable]
    block_body(lines, index).each_with_index do |body_line, offset|
      body_line.scan(/\b#{Regexp.escape(variable)}\.(\w+)\b/) do |association,|
        next unless associations.key?(association)
        next if binding[:eager_loaded].include?(association)

        issues << {
          file: file_path,
          line: index + offset + 1,
          type: "n_plus_one",
          severity: "warning",
          message: "#{match[:receiver]} is queried at line #{binding[:line]} without eager loading, " \
                   "then #{variable}.#{association} is read inside the loop — one query per iteration",
          suggestion: "Add .includes(:#{association}) to the query on line #{binding[:line]}"
        }
      end
    end
  end

  issues.uniq { |issue| [issue[:file], issue[:line], issue[:message]] }
end

def scan_controllers(rails_root, associations)
  directory = File.join(rails_root, "app", "controllers")
  return [] unless Dir.exist?(directory)

  Dir.glob(File.join(directory, "**", "*.rb")).flat_map do |file_path|
    analyze_controller(file_path, File.read(file_path), associations)
  rescue StandardError => e
    warn "Error analyzing #{file_path}: #{e.message}"
    []
  end
end

rails_root = find_rails_root
associations = association_names(rails_root)

puts "Analyzing Rails application at: #{rails_root}"
puts "=" * 80
puts "Declared associations found in app/models: #{associations.length}"

if associations.empty?
  puts
  puts "No association declarations were found, so association access cannot be recognised."
  puts "This analysis needs app/models to declare belongs_to / has_many / has_one."
  exit 0
end

issues = scan_controllers(rails_root, associations)

puts "\nFound #{issues.length} N+1 queries:\n"

unless issues.empty?
  puts "\nWARNING (#{issues.length} issues):"
  puts "-" * 80
  issues.each do |issue|
    puts "  #{issue[:file]}:#{issue[:line]}"
    puts "  -> #{issue[:message]}"
    puts "  Fix: #{issue[:suggestion]}"
    puts
  end
end

if issues.empty?
  puts "No N+1 queries detected in app/controllers."
end

puts "-" * 80
puts "Scope: Ruby under app/controllers only. Association access inside a template is not"
puts "analyzed, so confirm templates separately, and use strict_loading for runtime coverage:"
puts "  config.active_record.strict_loading_by_default = true"
puts "  config.active_record.action_on_strict_loading_violation = :log"
