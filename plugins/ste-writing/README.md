# ste-writing

## Overview

My ASD-STE100 [output style](https://code.claude.com/docs/en/output-styles) changes how Claude
communicates. It makes each sentence from Claude short, direct, and unambiguous. No more bizarre
sentences like "The suggestions are the product; the acknowledgment is garnish, and garnish
shouldn't be able to take the meal down."

The output style has 17 rules for Claude's writing. Some key aspects:

- **One word, one meaning.** Claude uses one term for one concept, and repeats it.
- **Simple sentences.** For example, a sentence has a maximum of 20 words for an instruction and
  25 words for a description. A sentence puts the subject and the verb up front.
    - Before: "The behavior I deleted the comment about still holds, and the spec keeps it honest."
    - After: "The behavior still holds, and the spec keeps it honest. I only deleted the comment."
- **It covers Claude's replies, documents, commit messages, PR text, and code comments.** It
  leaves code, quotations, and customer-facing content alone.
- **The point comes first.** Each paragraph opens with the action, the change, or the finding.

It's based on
[ASD-STE100 (Simplified Technical English)](https://en.wikipedia.org/wiki/Simplified_Technical_English).
Wikipedia describes the standard like this:

> It was originally developed in the 1980s by the European Association of Aerospace Industries
> (AECMA) at the request of the European airline industry, which wanted a standardized form of
> English for aircraft maintenance documentation that could be easily understood by non-native
> English-speakers. It has since been adopted in many other fields outside the aerospace, defense,
> and maintenance domains for its clear, consistent, and comprehensive nature.

A misunderstanding of intent in an airplane repair manual could prove fatal, so having a standard
for very clear technical writing was critical. As it turns out, it's great for AI-assisted coding
too.

My output style is not an exact copy of the standard. In the style's
[Rules](output-styles/asd-ste100.md#rules) section, a † marks each of the four rules that differ
from it.

A more specific instruction can take precedence as needed. That instruction can come from you,
from the instructions of a project, from a skill, or from the convention of the file that Claude
edits.

## Installation

```bash
/plugin marketplace add toppa/claude-plugins
/plugin install ste-writing       # then select the style in /config
```
