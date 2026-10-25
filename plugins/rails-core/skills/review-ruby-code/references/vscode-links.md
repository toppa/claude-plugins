# Clickable Code References

Every code reference in a review should be clickable, so the reader lands on the line instead of
hunting for it.

## The format

```markdown
[UserService#create exceeds 5 lines](file:///Users/dev/myapp/app/services/user_service.rb#L23)
```

Two details carry the whole mechanism, and both are easy to get wrong:

- **Three slashes after `file:`.** `file:///Users/…`, not `file://Users/…` — the third slash is the
  root of the path, and without it the host portion swallows the first path segment.
- **A capital `L` in the anchor.** `#L42`, not `#l42` or `#42`.

Everything else follows from those: use an absolute path, use forward slashes, and percent-encode
spaces (`"/Users/dev/my app"` → `/Users/dev/my%20app`).

The `#L` fragment on a non-markdown file works in VS Code 1.62 and later; the bug that used to
swallow it (microsoft/vscode#125320) was fixed in the October 2021 release.

**On relative paths**: workspace-relative markdown links are documented and supported by VS Code, and
they also render as links on GitHub, so they are the better choice when the review lives inside the
repository. The absolute `file:///` form is here because a review reported into a chat transcript or
written outside the workspace has no relative root to resolve against. Whether VS Code resolves `#L`
on an absolute `file:///` URI is not something the documentation states; if the target opens at line
1, fall back to the workspace-relative form.

## Building a link in Ruby

```ruby
def code_link(description, file_path, line_number)
  "[#{description}](file://#{File.expand_path(file_path)}#L#{line_number})"
end
```

`File.expand_path` supplies the leading slash, so the literal `file://` plus an absolute path gives
the three slashes the format needs.

To find the line a symbol is on, prefer `rg -n "def create" app/services/user_service.rb`. In Ruby,
guard the miss — `find_index` returns `nil`, and a miss is the ordinary case when you are searching
for something that may not be there:

```ruby
def line_of(file_path, needle)
  index = File.readlines(file_path).find_index { |line| line.include?(needle) }
  index && index + 1
end
```

## Checking the links you produced

The point of a checker is to report *every* broken link, so each failure has to continue rather than
fall through into the next call on the same path:

```ruby
def broken_links(markdown)
  markdown.scan(%r{file://(/[^)#]*)\#L(\d+)}).filter_map do |path, line_number|
    next "missing file: #{path}" unless File.exist?(path)

    line_count = File.readlines(path).count
    next "line #{line_number} exceeds #{line_count} lines: #{path}" if line_number.to_i > line_count

    nil
  end
end
```

## Link text

Say what the finding is, not where to click. `[UserService#create exceeds 5 lines](…)` tells the
reader whether to follow the link; `[here](…)` does not.
