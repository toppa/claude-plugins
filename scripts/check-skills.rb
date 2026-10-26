#!/usr/bin/env ruby
# frozen_string_literal: true

# Integrity checker for the plugin marketplace in this repo.
#
# Asserts seven properties that a skill cannot fail loudly at runtime:
#
#   1. paths        every reference/script path in a skill body, a README, or CONTRIBUTING.md resolves
#   2. names        frontmatter `name` equals the containing directory name
#   3. agents       every agent `skills:` entry is scoped, exists, and is model-invocable
#   4. anchors      every in-repo markdown anchor link resolves to a real heading
#   5. estimates    every `(~N lines)` load-cost estimate is within 5% of the truth
#   6. index        every skill has a `description` or a `when_to_use`
#   7. versions     the guide's version line equals its plugin's `plugin.json` version
#
# Usage: ruby scripts/check-skills.rb [--quiet]
# Exits 0 when every check passes, 1 otherwise.

require "json"
require "yaml"
require "date"
require "set"

ROOT = File.expand_path("..", __dir__)
TOLERANCE = 0.05

# ---------------------------------------------------------------------------
# Failure collection
# ---------------------------------------------------------------------------

CHECKS = {
  paths: "reference and script paths resolve",
  names: "frontmatter name matches directory name",
  agents: "agent skills: entries are scoped, present and model-invocable",
  anchors: "markdown anchor links resolve to a real heading",
  estimates: "(~N lines) estimates within #{(TOLERANCE * 100).round}% of actual",
  index: "every skill has a description or a when_to_use",
  versions: "the guide's version line matches its plugin.json version"
}.freeze

$failures = CHECKS.keys.to_h { |k| [k, []] }
$counts = CHECKS.keys.to_h { |k| [k, 0] }

def fail!(check, location, message)
  $failures.fetch(check) << "#{rel(location)}: #{message}"
end

def rel(path)
  path.to_s.start_with?(ROOT) ? path.to_s[(ROOT.length + 1)..] : path.to_s
end

def counted(check)
  $counts[check] += 1
end

# ---------------------------------------------------------------------------
# Markdown and frontmatter helpers
# ---------------------------------------------------------------------------

# Frontmatter is delimited by `---` on the first line and the next bare `---`.
# Returns [yaml_string, metadata_line_range_or_nil].
def split_frontmatter(lines)
  return [nil, nil] unless lines.first&.rstrip == "---"

  close = lines[1..].index { |l| l.rstrip == "---" }
  return [nil, nil] if close.nil?

  fm_lines = lines[1..close]
  [fm_lines.join, metadata_range(fm_lines)]
end

# `metadata:` is a top-level key, so its block runs until the next line that
# starts in column zero. `upstream_path:` holds a path inside an upstream
# repository, and reading it as a live pointer is a guaranteed false positive.
def metadata_range(fm_lines)
  start = fm_lines.index { |l| l.start_with?("metadata:") }
  return nil if start.nil?

  finish = fm_lines[(start + 1)..].index { |l| l.match?(/\A\S/) }
  last = finish.nil? ? fm_lines.length - 1 : start + finish
  # +2 converts the 0-based frontmatter index to a 1-based file line number.
  ((start + 2)..(last + 2))
end

def parse_frontmatter(yaml, _path)
  return nil if yaml.nil?

  # `synced:` holds a bare date, which safe_load rejects without this.
  YAML.safe_load(yaml, permitted_classes: [Date, Time], aliases: true)
rescue Psych::Exception
  nil
end

# Why the frontmatter could not be read, in words a human can act on. A skill
# whose frontmatter does not parse does not load at all, so this is not a
# warning to print and move past.
def frontmatter_problem(lines, yaml)
  return "the file does not open with a `---` frontmatter delimiter" unless lines.first&.rstrip == "---"
  return "the frontmatter block is never closed by a second `---`" if yaml.nil?

  begin
    parsed = YAML.safe_load(yaml, permitted_classes: [Date, Time], aliases: true)
  rescue Psych::Exception => e
    return "the frontmatter is not valid YAML: #{e.class}: #{e.message.lines.first.to_s.strip}"
  end
  return "the frontmatter parses to #{parsed.class}, not a mapping of keys" unless parsed.is_a?(Hash)

  nil
end

# Lines inside a fenced code block are not markdown. `# config/foo.rb` in a
# bash fence is a comment, not an h1, and counting it as a heading is how a
# file with zero headings looks like it has eight.
def fence_flags(lines)
  in_fence = false
  fence = nil
  lines.map do |line|
    marker = line[/\A\s{0,3}(`{3,}|~{3,})/, 1]
    if in_fence
      if marker && fence && marker[0] == fence[0] && marker.length >= fence.length
        in_fence = false
        fence = nil
      end
      true
    elsif marker
      in_fence = true
      fence = marker
      true
    else
      false
    end
  end
end

def slugify(text)
  s = text.dup
  s = s.gsub(/\[([^\]]*)\]\([^)]*\)/, '\1') # link text only
  s = s.gsub(/<[^>]*>/, "")                 # inline html
  s = s.strip.downcase
  # GitHub keeps `_`, so `generator_spec` slugs as `generator_spec`. Stripping
  # it as an emphasis marker breaks every heading with a snake_case identifier.
  s = s.gsub(/[^\p{L}\p{M}\p{N}\p{Pc} -]/, "")
  s.tr(" ", "-")
end

# Anchor slugs for one file, with GitHub's -1/-2 disambiguation for repeats.
def heading_slugs(path)
  $slug_cache ||= {}
  $slug_cache[path] ||= begin
    lines = File.readlines(path)
    fenced = fence_flags(lines)
    seen = {}
    slugs = Set.new
    lines.each_with_index do |line, i|
      next if fenced[i]
      m = line.match(/\A\s{0,3}(\#{1,6})\s+(.*?)\s*\#*\s*\z/)
      next if m.nil?

      base = slugify(m[2])
      next if base.empty?

      n = seen[base].to_i
      seen[base] = n + 1
      slugs << (n.zero? ? base : "#{base}-#{n}")
    end
    slugs
  end
end

# ---------------------------------------------------------------------------
# Inventory
# ---------------------------------------------------------------------------

marketplace = JSON.parse(File.read(File.join(ROOT, ".claude-plugin", "marketplace.json")))
MARKETPLACE_PLUGINS = marketplace.fetch("plugins").map { |p| p.fetch("name") }.to_set

PLUGIN_DIRS = Dir.glob(File.join(ROOT, "plugins", "*")).select { |d| File.directory?(d) }.sort
SKILL_FILES = Dir.glob(File.join(ROOT, "plugins", "*", "skills", "*", "SKILL.md")).sort
AGENT_FILES = Dir.glob(File.join(ROOT, "plugins", "*", "agents", "*.md")).sort

# Every markdown file that ships as skill content, plus the agent definitions,
# the READMEs, and CONTRIBUTING.md.
CONTENT_FILES = (Dir.glob(File.join(ROOT, "plugins", "*", "skills", "**", "*.md")) + AGENT_FILES +
                 Dir.glob(File.join(ROOT, "{README,CONTRIBUTING}.md")) +
                 Dir.glob(File.join(ROOT, "plugins", "*", "README.md"))).sort

def plugin_dir_for(path)
  PLUGIN_DIRS.find { |d| path.start_with?("#{d}/") }
end

def skill_dir_for(path)
  m = path.match(%r{\A(.*/plugins/[^/]+/skills/[^/]+)/})
  m && m[1]
end

# skill name => { path:, dir:, frontmatter: }
SKILLS = SKILL_FILES.to_h do |path|
  lines = File.readlines(path)
  yaml, = split_frontmatter(lines)
  fm = parse_frontmatter(yaml, path)
  dir = File.dirname(path)
  plugin = File.basename(File.expand_path("../..", dir))
  [[plugin, File.basename(dir)],
   { path: path, dir: dir, frontmatter: fm || {}, problem: fm.is_a?(Hash) ? nil : frontmatter_problem(lines, yaml) }]
end

# ---------------------------------------------------------------------------
# Check 1 — reference and script paths resolve
# ---------------------------------------------------------------------------

LINK_RE = /\[[^\]\n]*\]\(\s*([^)\s]+?)\s*(?:\s+"[^"]*")?\)/
PLUGIN_ROOT_RE = /\$\{CLAUDE_PLUGIN_ROOT\}\/([A-Za-z0-9_.\-\/]*[A-Za-z0-9_-]\.[A-Za-z0-9]{1,5})/
# Prose and inline-code mentions such as `references/bottlenecks.md`. The
# negative lookbehind keeps `/scripts/utils.js` (a web-root URL in an example)
# and `app/scripts/x.js` out of the repo-path space.
BARE_RE = %r{(?<![\w/.$-])((?:references|scripts|rules|trackers)/[A-Za-z0-9_.\-/]*[A-Za-z0-9_-]\.[A-Za-z0-9]{1,5})}

def skippable_target?(target)
  target.empty? ||
    target.start_with?("#", "/", "mailto:", "tel:") ||
    target.match?(%r{\A[a-z][a-z0-9+.-]*://}i) ||
    # A `[...](...)` shape that is not a path: a shell character class such as
    # `gem ["'](rubycritic|simplecov)["']`, or a `<name>` placeholder.
    target.match?(/[|<>*?$"']/) ||
    # A target with neither a separator nor an extension is a placeholder, not a
    # path — `vscode-links.md` writes `[here](…)` to contrast link text.
    (!target.include?("/") && !target.match?(/\.[A-Za-z0-9]{1,5}\z/))
end

def check_paths(path, lines, fenced, metadata)
  dir = File.dirname(path)
  skill_root = skill_dir_for(path)
  plugin_root = plugin_dir_for(path)
  seen = Set.new

  lines.each_with_index do |line, i|
    lineno = i + 1
    next if metadata&.cover?(lineno)

    candidates = []

    # A `[a](b)` inside a code fence is sample text, not a link, and a path in a
    # fence usually belongs to the user's app rather than to this repo. The one
    # exception is a ${CLAUDE_PLUGIN_ROOT} path: those live in bash fences
    # precisely because they are commands the model is told to run.
    unless fenced[i]
      line.scan(LINK_RE) do
        target = Regexp.last_match(1).sub(/#.*\z/, "")
        next if skippable_target?(target)

        candidates << [target, [File.expand_path(target, dir)]]
      end

      line.scan(BARE_RE) do
        sub = Regexp.last_match(1)
        roots = [skill_root, dir].compact.uniq
        candidates << [sub, roots.map { |r| File.expand_path(sub, r) }]
      end
    end

    line.scan(PLUGIN_ROOT_RE) do
      sub = Regexp.last_match(1)
      next if plugin_root.nil?

      candidates << ["${CLAUDE_PLUGIN_ROOT}/#{sub}", [File.expand_path(sub, plugin_root)]]
    end

    candidates.each do |shown, resolutions|
      next unless seen.add?([lineno, shown])

      counted(:paths)
      next if resolutions.any? { |r| File.exist?(r) }

      fail!(:paths, "#{path}:#{lineno}",
            "`#{shown}` does not resolve; expected a file at #{resolutions.map { |r| rel(r) }.join(' or ')}")
    end
  end
end

# ---------------------------------------------------------------------------
# Check 4 — anchors
# ---------------------------------------------------------------------------

ANCHOR_RE = /\[[^\]\n]*\]\(\s*([^)\s]*#[^)\s]+?)\s*\)/

def check_anchors(path, lines, fenced, metadata)
  dir = File.dirname(path)

  lines.each_with_index do |line, i|
    lineno = i + 1
    next if metadata&.cover?(lineno) || fenced[i]

    line.scan(ANCHOR_RE) do
      target = Regexp.last_match(1)
      file_part, anchor = target.split("#", 2)
      next if anchor.nil? || anchor.empty?
      next if file_part.start_with?("http", "/") || file_part.match?(%r{\A[a-z][a-z0-9+.-]*://}i)

      target_path = file_part.empty? ? path : File.expand_path(file_part, dir)
      counted(:anchors)

      unless File.file?(target_path)
        # Check 1 already reports the missing file; do not double-charge it.
        next
      end

      slugs = heading_slugs(target_path)
      next if slugs.include?(anchor.downcase)

      where = file_part.empty? ? "this file" : rel(target_path)
      if slugs.empty?
        fail!(:anchors, "#{path}:#{lineno}",
              "`##{anchor}` cannot resolve — #{where} has no Markdown headings at all " \
              "(any `#` lines in it are inside code fences)")
      else
        near = slugs.select { |s| s.include?(anchor.downcase) || anchor.downcase.include?(s) }
        hint = near.empty? ? "" : "; closest headings: #{near.sort.map { |s| "##{s}" }.join(', ')}"
        fail!(:anchors, "#{path}:#{lineno}",
              "`##{anchor}` has no matching heading in #{where}#{hint}")
      end
    end
  end
end

# ---------------------------------------------------------------------------
# Check 5 — (~N lines) load-cost estimates
# ---------------------------------------------------------------------------

ESTIMATE_RE = /\(~\s*([\d,]+)\s*lines?\)/

def estimate_target(lines, index, path)
  dir = File.dirname(path)
  skill_root = skill_dir_for(path)
  plugin_root = plugin_dir_for(path)

  # Walk back from the estimate's own line: the pointer it prices is the last
  # path named at or before it.
  index.downto([index - 2, 0].max) do |i|
    line = lines[i]
    found = []
    line.scan(LINK_RE) do
      t = Regexp.last_match(1).sub(/#.*\z/, "")
      found << [t, File.expand_path(t, dir)] unless skippable_target?(t)
    end
    line.scan(PLUGIN_ROOT_RE) do
      found << ["${CLAUDE_PLUGIN_ROOT}/#{Regexp.last_match(1)}", File.expand_path(Regexp.last_match(1), plugin_root)] if plugin_root
    end
    line.scan(BARE_RE) do
      sub = Regexp.last_match(1)
      resolved = [skill_root, dir].compact.map { |r| File.expand_path(sub, r) }.find { |c| File.exist?(c) }
      found << [sub, resolved || File.expand_path(sub, skill_root || dir)]
    end
    return found.last unless found.empty?
  end
  nil
end

def check_estimates(path, lines, fenced, metadata)
  lines.each_with_index do |line, i|
    lineno = i + 1
    next if metadata&.cover?(lineno) || fenced[i]
    next unless line.match?(ESTIMATE_RE)

    line.scan(ESTIMATE_RE) do
      budget = Regexp.last_match(1).delete(",").to_i
      counted(:estimates)

      target = estimate_target(lines, i, path)
      if target.nil?
        fail!(:estimates, "#{path}:#{lineno}",
              "`(~#{budget} lines)` names no file; a load-cost estimate must sit next to the pointer it prices")
        next
      end

      shown, resolved = target
      unless File.file?(resolved)
        fail!(:estimates, "#{path}:#{lineno}",
              "`(~#{budget} lines)` prices `#{shown}`, which does not resolve to a file")
        next
      end

      actual = File.readlines(resolved).length
      drift = (budget - actual).abs / actual.to_f
      next if drift <= TOLERANCE

      direction = budget < actual ? "understates by" : "overstates by"
      fail!(:estimates, "#{path}:#{lineno}",
            "`#{shown}` is budgeted at ~#{budget} lines but is #{actual} lines — " \
            "#{direction} #{(budget - actual).abs} lines (#{(drift * 100).round(1)}%); " \
            "expected a budget between #{(actual * (1 - TOLERANCE)).ceil} and #{(actual * (1 + TOLERANCE)).floor}")
    end
  end
end

# ---------------------------------------------------------------------------
# Checks 2 and 6 — skill frontmatter
# ---------------------------------------------------------------------------

SKILLS.each do |(plugin, dirname), skill|
  path = skill[:path]
  fm = skill[:frontmatter]

  counted(:index)
  if skill[:problem]
    fail!(:index, path, "#{skill[:problem]}; a skill whose frontmatter does not parse never loads")
    next
  end

  counted(:names)
  name = fm["name"]
  if name.nil? || name.to_s.strip.empty?
    fail!(:names, path, "frontmatter has no `name`; expected `name: #{dirname}`")
  elsif name.to_s.strip != dirname
    fail!(:names, path,
          "frontmatter `name: #{name}` does not match its directory `#{dirname}` " \
          "(plugin #{plugin}); the directory name is what the loader keys on")
  end

  has_description = !fm["description"].to_s.strip.empty?
  has_when = !fm["when_to_use"].to_s.strip.empty?
  next if has_description || has_when

  fail!(:index, path,
        "has neither a `description` nor a `when_to_use`; a plugin skill with neither never loads")
end

# ---------------------------------------------------------------------------
# Check 3 — agent skills: entries
# ---------------------------------------------------------------------------

AGENT_FILES.each do |path|
  lines = File.readlines(path)
  yaml, = split_frontmatter(lines)
  fm = parse_frontmatter(yaml, path)

  if fm.nil?
    counted(:agents)
    fail!(:agents, path, "#{frontmatter_problem(lines, yaml)}; its `skills:` list cannot be read")
    next
  end

  entries = fm["skills"]
  # An agent with no `skills:` key preloads nothing, which is legitimate.
  next if entries.nil?

  unless entries.is_a?(Array)
    counted(:agents)
    fail!(:agents, path, "`skills:` is a #{entries.class}; expected a list of `plugin:skill` strings")
    next
  end

  entries.each do |entry|
    counted(:agents)
    text = entry.to_s.strip
    # Line number so a human can go straight to the offending list item.
    idx = lines.index { |l| l.include?(text) }
    where = idx ? "#{path}:#{idx + 1}" : path

    unless text.count(":") == 1 && text.match?(/\A[A-Za-z0-9_-]+:[A-Za-z0-9_-]+\z/)
      fail!(:agents, where,
            "`#{text}` is not `plugin:skill`-scoped; an unscoped or malformed entry does not resolve at spawn")
      next
    end

    plugin, skill_name = text.split(":")

    unless MARKETPLACE_PLUGINS.include?(plugin)
      fail!(:agents, where,
            "`#{text}` names plugin `#{plugin}`, which is absent from .claude-plugin/marketplace.json " \
            "(known: #{MARKETPLACE_PLUGINS.to_a.sort.join(', ')})")
      next
    end

    skill = SKILLS[[plugin, skill_name]]
    if skill.nil?
      fail!(:agents, where,
            "`#{text}` names skill `#{skill_name}`, but plugins/#{plugin}/skills/#{skill_name}/SKILL.md does not exist")
      next
    end

    next unless skill[:frontmatter]["disable-model-invocation"] == true

    fail!(:agents, where,
          "`#{text}` is preloaded but the skill sets `disable-model-invocation: true` " \
          "(#{rel(skill[:path])}); a user-only skill fails silently at spawn")
  end
end

# ---------------------------------------------------------------------------
# Checks 1, 4 and 5 — walk every content file
# ---------------------------------------------------------------------------

CONTENT_FILES.each do |path|
  lines = File.readlines(path)
  _yaml, metadata = split_frontmatter(lines)
  fenced = fence_flags(lines)

  check_paths(path, lines, fenced, metadata)
  check_anchors(path, lines, fenced, metadata)
  check_estimates(path, lines, fenced, metadata)
end

# ---------------------------------------------------------------------------
# Check 7 — the guide's version line matches its plugin's version
# ---------------------------------------------------------------------------

GUIDE_PLUGIN = File.join(ROOT, "plugins", "standing-documents")
GUIDE = File.join(GUIDE_PLUGIN, "skills", "adopt", "references", "adopt-standing-documents.md")
GUIDE_MANIFEST = File.join(GUIDE_PLUGIN, ".claude-plugin", "plugin.json")
GUIDE_VERSION_RE = /\AVersion (\d+\.\d+\.\d+)\b/

counted(:versions)
if !File.file?(GUIDE)
  fail!(:versions, GUIDE, "the guide is missing, so its version cannot be compared with #{rel(GUIDE_MANIFEST)}")
elsif !File.file?(GUIDE_MANIFEST)
  fail!(:versions, GUIDE_MANIFEST, "the plugin manifest is missing, so the guide's version cannot be compared with it")
else
  guide_version = File.readlines(GUIDE).lazy.filter_map { |l| l[GUIDE_VERSION_RE, 1] }.first
  plugin_version = JSON.parse(File.read(GUIDE_MANIFEST))["version"]
  if guide_version.nil?
    fail!(:versions, GUIDE, "has no `Version X.Y.Z` line; expected one under the title, equal to #{plugin_version.inspect}")
  elsif guide_version != plugin_version
    fail!(:versions, GUIDE,
          "says version #{guide_version}, but #{rel(GUIDE_MANIFEST)} says #{plugin_version.inspect}; " \
          "a project records the guide's version, and `/plugin update` ships the plugin's")
  end
end

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

quiet = ARGV.include?("--quiet")
total = $failures.values.sum(&:length)

unless quiet
  CHECKS.each do |key, title|
    next if $failures[key].empty?

    puts
    puts "#{key.to_s.upcase} — #{title}"
    puts "-" * 72
    $failures[key].sort.each { |line| puts "  #{line}" }
  end
end

puts
puts "Summary (#{SKILL_FILES.length} skills, #{AGENT_FILES.length} agents, #{CONTENT_FILES.length} markdown files)"
puts "-" * 72
CHECKS.each do |key, title|
  bad = $failures[key].length
  status = bad.zero? ? "ok  " : "FAIL"
  printf("  %-4s %-10s %4d checked, %2d failed   %s\n", status, key, $counts[key], bad, title)
end
puts
puts(total.zero? ? "All checks passed." : "#{total} failure#{'s' unless total == 1} across #{$failures.count { |_, v| v.any? }} check(s).")

exit(total.zero? ? 0 : 1)
