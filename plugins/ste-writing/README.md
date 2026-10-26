# ste-writing

> An output style that makes each English sentence from Claude short, direct, and readable in
> one way only.

## Highlights

- **Countable rules.** For example, a sentence has a maximum of 20 words for an instruction and
  25 words for a description. A modifier has a maximum of 3 stacked nouns.
- **One word, one meaning.** Claude uses one term for one concept, and repeats it.
- **The point comes first.** Each paragraph opens with the action, the change, or the finding.
- **It covers all the English that Claude writes:** replies, documents, commit messages, pull
  request text, and code comments.
- **It leaves code and quotations alone**, and a more specific instruction takes precedence
  over it.

## Overview

`ste-writing` holds no skill. It holds one output style, which sets the shape of each English
sentence that Claude writes. An output style is a Claude Code setting that changes how Claude
writes its responses. It is for a developer who wants text from Claude that a reader can follow
with no follow-up question.

The style draws on ASD-STE100, the Simplified Technical English standard of the aerospace
industry. The industry built that standard so that a reader who cannot ask a question still
reads the text one way only. The style is a house style, and not a copy of the standard. Its
section "Rules" marks with † each rule that differs from the standard, and says why.

The style applies to every English sentence that Claude writes, in five places:

1. Replies in the terminal.
2. A document, such as a `README.md`, a plan, a skill, or a `CLAUDE.md`.
3. Text that Claude writes into an external system, such as an issue tracker or an email draft.
4. A git commit message, a pull request description, and a pull request comment.
5. A code comment.

The style does not cover these subjects:

- **Text that a customer reads**, such as a UI string, marketing copy, or a help page. That
  text belongs to the voice of the product.
- **Code, quoted material, and text where the exact wording carries the meaning**, such as a
  command, an API name, or an exact error string.

A more specific instruction takes precedence over the style on what it addresses. That
instruction can come from you, from the instructions of a project, from a skill, or from the
convention of the file that Claude edits.

## Output style

| File | Style name in `/config` | What it sets |
|---|---|---|
| [`output-styles/asd-ste100.md`](output-styles/asd-ste100.md) | `ste-writing:ASD-STE100` | The shape of each English sentence that Claude writes. The style keeps the coding instructions of Claude Code (`keep-coding-instructions: true`). |

## Installation

```bash
/plugin marketplace add toppa/claude-plugins
/plugin install ste-writing       # then select the style in /config
```

The install alone does not turn on the style.

Any programming language.

## Usage

1. Type `/config`.
2. Select the output style `ste-writing:ASD-STE100`.

To turn the style off, select another output style in `/config`, such as Default.

This is an example of the change. The sentence "The failure may have been caused by the missing
index" chains modal verbs. Under the style, Claude writes "The missing index is one possible
cause of the failure. The cause is not confirmed."

## Feedback and Contributing

Issues are welcome. Before you open a pull request, read
[`CONTRIBUTING.md`](../../CONTRIBUTING.md).
