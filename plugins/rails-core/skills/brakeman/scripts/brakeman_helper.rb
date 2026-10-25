#!/usr/bin/env ruby
# frozen_string_literal: true

# Brakeman workflow helper.
#
# Wraps the invocations a review actually repeats, resolving the Brakeman the
# project pins rather than whatever is on PATH, passing arguments as an array so
# no value reaches a shell, and reporting the scan's real exit status.
#
# Verified against brakeman 8.0.5.

require 'optparse'
require 'json'
require 'fileutils'
require 'shellwords'

class BrakemanHelper
  WORKFLOWS = {
    'initial-audit' => 'Full scan: HTML plus JSON plus the controller listing',
    'quick-check' => 'High confidence only, quiet',
    'ci-check' => 'JSON plus a per-warning-type summary',
    'compare' => 'Diff against a saved JSON scan',
    'interactive' => 'Walk the warnings and write the ignore file (needs a TTY)',
    'report-only' => 'Write the reports; succeed whenever the scan itself ran',
    'all-warnings' => 'Every confidence level, every optional check'
  }.freeze

  # brakeman.rb defines these; SKILL.md carries the full table.
  EXIT_MEANINGS = {
    0 => 'no warnings',
    3 => 'warnings found',
    4 => 'no Rails application at that path',
    5 => 'Brakeman is not the latest version, so the scan did not run',
    6 => 'a named check does not exist',
    7 => 'the scan raised errors',
    8 => 'an ignore entry has no note',
    9 => 'an ignore entry is obsolete'
  }.freeze

  def initialize
    @options = {
      workflow: nil,
      app_path: '.',
      output_dir: 'tmp/brakeman',
      baseline_file: nil,
      confidence: 2
    }
  end

  def run(args)
    parse_options(args)

    unless @options[:workflow]
      warn 'Give a workflow name.'
      print_workflows($stderr)
      exit 1
    end

    unless WORKFLOWS.key?(@options[:workflow])
      warn "No such workflow: #{@options[:workflow]}"
      print_workflows($stderr)
      exit 1
    end

    FileUtils.mkdir_p(@options[:output_dir])

    case @options[:workflow]
    when 'initial-audit' then run_initial_audit
    when 'quick-check' then run_quick_check
    when 'ci-check' then run_ci_check
    when 'compare' then run_compare
    when 'interactive' then run_interactive
    when 'report-only' then run_report_only
    when 'all-warnings' then run_all_warnings
    end
  end

  private

  def parse_options(args)
    parser = OptionParser.new do |opts|
      opts.banner = 'Usage: brakeman_helper.rb WORKFLOW [options]'

      opts.on('-p', '--path PATH', 'Rails application path (default: .)') do |p|
        @options[:app_path] = p
      end

      opts.on('-o', '--output-dir DIR', 'Report directory (default: tmp/brakeman)') do |d|
        @options[:output_dir] = d
      end

      opts.on('-b', '--baseline FILE', 'Baseline JSON report, for the compare workflow') do |b|
        @options[:baseline_file] = b
      end

      opts.on('--confidence LEVEL', Integer,
              'Brakeman confidence level: 1 all, 2 high and medium, 3 high (default: 2)') do |c|
        @options[:confidence] = c
      end

      opts.on('-h', '--help', 'Show this message') do
        puts opts
        print_workflows($stdout)
        exit 0
      end
    end

    parser.parse!(args)
    @options[:workflow] = args.shift
  end

  def print_workflows(io)
    io.puts "\nWorkflows:"
    WORKFLOWS.each { |name, desc| io.puts "  #{name.ljust(15)} #{desc}" }
    io.puts "\nThe workflow is a positional argument, so brakeman's own flag letters"
    io.puts "keep their meanings: --confidence takes brakeman's -w value."
  end

  # Resolve the Brakeman the application pins, in this order:
  #
  #   1. the project's binstub, which is what CI runs
  #   2. `bundle exec brakeman` against the project's Gemfile
  #   3. `brakeman` from PATH
  #
  # A bare `brakeman` resolves to whichever gem version happens to be installed
  # globally, which is a different scan from the one CI runs.
  def brakeman_command
    @brakeman_command ||= begin
      binstub = File.join(@options[:app_path], 'bin', 'brakeman')
      gemfile = File.join(@options[:app_path], 'Gemfile')

      if File.executable?(binstub)
        { env: { 'BUNDLE_GEMFILE' => File.expand_path(gemfile) },
          argv: [File.expand_path(binstub)],
          note: "#{binstub} (the binstub CI uses; it adds --ensure-latest, so exit 5 is possible)" }
      elsif File.exist?(gemfile) && File.read(gemfile).include?('brakeman')
        { env: { 'BUNDLE_GEMFILE' => File.expand_path(gemfile) },
          argv: ['bundle', 'exec', 'brakeman'],
          note: "bundle exec brakeman, pinned by #{gemfile}" }
      else
        { env: {}, argv: ['brakeman'],
          note: 'brakeman from PATH (no binstub and no Gemfile entry found)' }
      end
    end
  end

  # Runs brakeman with the arguments as separate array elements, so no value is
  # interpreted by a shell. Returns the exit status.
  def run_brakeman(*args)
    command = brakeman_command
    argv = command[:argv] + args

    puts "Brakeman: #{command[:note]}"
    puts "Command:  #{Shellwords.join(argv)}"
    puts

    system(command[:env], *argv)
    $?.exitstatus
  end

  def describe(status)
    meaning = EXIT_MEANINGS[status] || 'see SKILL.md for the exit-code table'
    "exit #{status} — #{meaning}"
  end

  def report_outcome(status, files, summary: nil)
    written = files.select { |f| File.exist?(f) }
    missing = files - written

    puts
    if missing.empty?
      puts "Scan finished: #{summary || describe(status)}"
      written.each { |f| puts "  wrote #{f}" }
    else
      puts "Scan FAILED: #{describe(status)}"
      puts 'These reports were not written:'
      missing.each { |f| puts "  #{f}" }
      puts 'Read the Brakeman output above; the numbers below it, if any, describe nothing.'
    end
  end

  def timestamped(prefix, extension)
    File.join(@options[:output_dir], "#{prefix}_#{Time.now.strftime('%Y%m%d_%H%M%S')}.#{extension}")
  end

  def confidence_flag
    "-w#{@options[:confidence]}"
  end

  def run_initial_audit
    html = timestamped('audit', 'html')
    json = timestamped('audit', 'json')

    # -m/--routes reports controller information. There is no --report-routes.
    status = run_brakeman('-p', @options[:app_path], '-o', html, '-o', json, '-m')
    report_outcome(status, [html, json])

    if File.exist?(html) && File.exist?(json)
      puts
      puts 'Next: read the HTML report, then'
      puts "  ruby #{$PROGRAM_NAME} interactive -p #{@options[:app_path]}"
    end

    exit status
  end

  def run_quick_check
    status = run_brakeman('-p', @options[:app_path], '-w3', '-q', '--no-pager')
    puts
    puts "High-confidence check: #{describe(status)}"
    exit status
  end

  def run_ci_check
    json = File.join(@options[:output_dir], 'ci_results.json')

    status = run_brakeman('-p', @options[:app_path], confidence_flag,
                          '-o', json, '-f', 'json', '-q', '--no-pager')
    report_outcome(status, [json])
    exit status unless File.exist?(json)

    results = JSON.parse(File.read(json))
    warnings = results['warnings'] || []
    errors = results['errors'] || []

    puts
    puts "Warnings: #{warnings.length}   Scan errors: #{errors.length}"
    warnings.group_by { |w| w['warning_type'] }.sort.each do |type, group|
      puts "  #{type}: #{group.length}"
    end
    errors.each { |e| puts "  error: #{e['error']}" }

    exit status
  end

  def run_compare
    baseline = @options[:baseline_file]

    unless baseline
      warn 'The compare workflow needs a baseline: --baseline FILE'
      warn "Create one with:  ruby #{$PROGRAM_NAME} ci-check -p #{@options[:app_path]}"
      exit 1
    end

    unless File.exist?(baseline)
      warn "No such baseline file: #{baseline}"
      exit 1
    end

    status = run_brakeman('-p', @options[:app_path], '--compare', baseline, '--no-pager')
    puts
    puts "Comparison against #{baseline}: #{describe(status)}"
    exit status
  end

  def run_interactive
    puts 'Interactive ignore. Keys, from brakeman 8.0.5:'
    puts '  i  add to the ignore list'
    puts '  n  add to the ignore list with a note (use this one)'
    puts '  s  skip this warning'
    puts '  u  remove this warning from the ignore list'
    puts '  a  ignore this and all remaining warnings'
    puts '  k  skip this and all remaining warnings'
    puts '  q  quit without updating the ignore file'
    puts '  ?  help'
    puts
    puts 'The opening menu has four choices, and the third one PRUNES obsolete'
    puts 'entries. Saving after choosing it writes those deletions.'
    puts

    status = run_brakeman('-p', @options[:app_path], '-I')
    exit status
  end

  def run_report_only
    html = timestamped('report', 'html')
    json = timestamped('report', 'json')

    status = run_brakeman('-p', @options[:app_path], confidence_flag,
                          '-o', html, '-o', json, '--no-exit-on-warn', '--no-pager')

    # --no-exit-on-warn means exit 0 no longer implies a clean application, so
    # count the findings from the report rather than from the exit code.
    summary =
      if File.exist?(json)
        count = (JSON.parse(File.read(json))['warnings'] || []).length
        "the scan ran (exit #{status}); #{count} warning#{'s' unless count == 1} at #{confidence_flag}"
      end

    report_outcome(status, [html, json], summary: summary)

    # This workflow deliberately does not fail on findings, but it does fail when
    # the scan itself did not produce the reports.
    exit(File.exist?(html) && File.exist?(json) ? 0 : status.nonzero? || 1)
  end

  def run_all_warnings
    html = timestamped('comprehensive', 'html')
    json = timestamped('comprehensive', 'json')

    # -A adds the seven optional checks; -w1 keeps Weak warnings, where Redirect
    # and Unscoped Find land. The HTML and JSON reports always carry
    # ignored_warnings, so --show-ignored would add nothing here.
    status = run_brakeman('-p', @options[:app_path], '-A', '-w1', '-o', html, '-o', json, '--no-pager')
    report_outcome(status, [html, json])
    exit status
  end
end

if __FILE__ == $PROGRAM_NAME
  BrakemanHelper.new.run(ARGV)
end
