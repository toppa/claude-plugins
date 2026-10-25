#!/usr/bin/env ruby
# frozen_string_literal: true

# Analyze database.yml and suggest PostgreSQL configuration improvements.
# Checks connection pool settings, timeouts, and common performance parameters.
#
# Exit status: 0 when the analysis ran, 1 when it could not run. Findings are
# reported on stdout, so a non-zero status always means the script itself failed.

require "yaml"

# Findings are printed to stdout and a parse failure aborts on stderr, so keep
# the two streams in step for whoever reads the combined output.
$stdout.sync = true

ERB_VALUE = "__ERB__"

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

def load_database_config(config_file)
  content = File.read(config_file)
  # ERB is evaluated at boot, so stand a plain token in for each output tag. The
  # token has no quotes or YAML metacharacters, so it survives whether the tag
  # was written bare or inside a quoted scalar.
  content = content.gsub(/<%=.*?%>/, ERB_VALUE).gsub(/<%.*?%>/, "")
  # The generated file writes `default: &default` and `<<: *default`, so alias
  # resolution is what lets a stock database.yml load at all.
  YAML.safe_load(content, permitted_classes: [Symbol], aliases: true)
end

# A multi-database environment maps names to configurations, and each named
# database carries its own pool and timeout settings.
def database_configs(env_name, env_config)
  return [[env_name, env_config]] if env_config.empty?
  return [[env_name, env_config]] unless env_config.values.all? { |value| value.is_a?(Hash) }

  env_config.map { |name, config| ["#{env_name} (#{name})", config] }
end

# Rails 8.1 names the key `max_connections`; `pool` is an alias and deprecated
# (ActiveRecord::DatabaseConfigurations::HashConfig). Setting both to different
# values raises "Ambiguous configuration" from validate_configuration!.
def analyze_connection_pool(env_config, env_name)
  issues = []
  max_connections = env_config["max_connections"]
  pool = env_config["pool"]

  if max_connections && pool && max_connections != pool
    issues << {
      environment: env_name, setting: "max_connections", severity: "warning",
      message: "Both max_connections (#{max_connections}) and its deprecated alias pool (#{pool}) are set, to different values",
      recommendation: "Keep max_connections and remove pool. Rails raises \"Ambiguous configuration\" when the two disagree"
    }
    return issues
  end

  if pool && max_connections.nil?
    issues << {
      environment: env_name, setting: "pool", severity: "info",
      message: "Pool size is set through the deprecated pool key",
      recommendation: "Rename pool to max_connections, which is the key Rails 8.1 generates and documents"
    }
  end

  size = max_connections || pool

  case size
  when nil
    issues << {
      environment: env_name, setting: "max_connections", severity: "warning",
      message: "Pool size not explicitly set (defaults to 5)",
      recommendation: "Set max_connections to the number of threads in one process. Rails' own generator writes " \
                      "max_connections: <%= ENV.fetch(\"RAILS_MAX_THREADS\") { 5 } %>"
    }
  when ERB_VALUE
    issues << {
      environment: env_name, setting: "max_connections", severity: "info",
      message: "Pool size is computed at boot from an ERB expression, so its value is not visible here",
      recommendation: "Confirm it resolves to one process's thread count (RAILS_MAX_THREADS is the generator's " \
                      "choice). Each forked worker holds its own pool, so compare processes x threads x servers " \
                      "against the server's max_connections setting"
    }
  when Integer
    if size > 20
      issues << {
        environment: env_name, setting: "max_connections", severity: "info",
        message: "Pool size (#{size}) is larger than one process usually needs",
        recommendation: "A pool only serves the threads in its own process. Verify this matches the thread count " \
                        "and check the total across processes against the server's max_connections setting"
      }
    end
  end

  issues
end

def analyze_timeouts(env_config, env_name)
  issues = []
  variables = env_config.fetch("variables", {}) || {}

  unless variables.key?("statement_timeout")
    issues << {
      environment: env_name, setting: "statement_timeout", severity: "warning",
      message: "statement_timeout not configured",
      recommendation: "Add to database.yml:\n  variables:\n    statement_timeout: 30000  # 30 seconds in milliseconds"
    }
  end

  unless env_config.key?("connect_timeout")
    issues << {
      environment: env_name, setting: "connect_timeout", severity: "info",
      message: "connect_timeout not configured",
      recommendation: "Add connect_timeout: 5 to prevent hanging on database connection issues"
    }
  end

  issues
end

def analyze_prepared_statements(env_config, env_name, production)
  issues = []
  prepared = env_config["prepared_statements"]

  if prepared == false
    issues << {
      environment: env_name, setting: "prepared_statements", severity: "info",
      message: "Prepared statements are disabled",
      recommendation: "Prepared statements improve performance. Only disable if using PgBouncer in transaction mode"
    }
  elsif prepared.nil? && production
    issues << {
      environment: env_name, setting: "prepared_statements", severity: "info",
      message: "Prepared statements setting not explicit",
      recommendation: "Add prepared_statements: true for better query performance (enabled by default)"
    }
  end

  issues
end

def check_ssl_configuration(env_config, env_name, production)
  return [] unless production

  sslmode = env_config["sslmode"]
  return [] if sslmode && sslmode != "disable"

  [{
    environment: env_name, setting: "sslmode", severity: "warning",
    message: "SSL/TLS not enforced for production database connections",
    recommendation: "Add sslmode: require or sslmode: verify-full for secure connections"
  }]
end

def suggest_performance_extensions(env_name)
  [{
    environment: env_name, setting: "extensions", severity: "info",
    message: "Consider enabling pg_stat_statements extension",
    recommendation: "Enable in PostgreSQL config:\n  shared_preload_libraries = 'pg_stat_statements'\nThen run: CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
  }]
end

rails_root = find_rails_root
config_file = File.join(rails_root, "config", "database.yml")

unless File.exist?(config_file)
  abort "Error: Could not find config/database.yml"
end

puts "Analyzing database configuration at: #{rails_root}"
puts "=" * 80

begin
  config = load_database_config(config_file)
rescue => e
  abort "Error parsing database.yml: #{e.message}"
end

all_issues = []

%w[development test production].each do |env_name|
  next unless config.is_a?(Hash) && config[env_name].is_a?(Hash)

  production = env_name == "production"

  database_configs(env_name, config[env_name]).each do |label, env_config|
    all_issues.concat(analyze_connection_pool(env_config, label))
    all_issues.concat(analyze_timeouts(env_config, label))
    all_issues.concat(analyze_prepared_statements(env_config, label, production))
    all_issues.concat(check_ssl_configuration(env_config, label, production))
  end
end

all_issues.concat(suggest_performance_extensions("all"))

# Environments and the named databases inside one environment inherit from the
# same `&default` anchor, so one omission surfaces once per database. Report each
# distinct finding once and name every place it applies.
findings = all_issues.group_by { |i| [i[:severity], i[:setting], i[:message], i[:recommendation]] }
                     .map { |key, group| key + [group.map { |i| i[:environment] || "all" }.uniq] }
by_severity = findings.group_by { |finding| finding[0] }

puts "\nFound #{findings.length} configuration recommendations:\n"

%w[warning info].each do |severity|
  group = by_severity.fetch(severity, [])
  next if group.empty?

  puts "\n#{severity.upcase} (#{group.length} items):"
  puts "-" * 80
  group.each do |_severity, setting, message, recommendation, environments|
    puts "  [#{environments.join(", ")}] #{setting || "general"}"
    puts "  -> #{message}"
    puts "  Recommendation: #{recommendation}"
    puts
  end
end

if findings.empty?
  puts "Database configuration looks good!"
else
  puts "=" * 80
  puts "For more information, see the High Performance PostgreSQL for Rails book"
  puts "  Chapters: 2 (Administration Basics), 5 (Optimizing Active Record)"
end
