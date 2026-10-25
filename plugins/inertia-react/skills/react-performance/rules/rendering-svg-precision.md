---
title: Optimize SVG Precision
impact: LOW
impactDescription: reduces file size
tags: rendering, svg, optimization, svgo
---

## Optimize SVG Precision

Reduce SVG coordinate precision to decrease file size. The optimal precision depends on the viewBox size, but in general reducing precision should be considered.

**Incorrect (excessive precision):**

```svg
<path d="M 10.293847 20.847362 L 30.938472 40.192837" />
```

**Correct (1 decimal place):**

```svg
<path d="M 10.3 20.8 L 30.9 40.2" />
```

**Automate with SVGO — but name an output file.**

```bash
npx svgo@latest --precision=1 --multipass icon.svg -o icon.min.svg
```

`-o` defaults to the input path, so `svgo --precision=1 icon.svg` **overwrites the source file in
place**, with no backup and no warning. Write to a new file, or be sure the original is committed
first. Both flags exist in svgo 4.0.1.

Where `svgo` is not a dependency of the project, `npx` downloads it for the run. `@latest` resolves
to whatever npm publishes that day; write `svgo@4.0.1` for a repeatable result, or add it as a
devDependency if this becomes routine. Precision is a per-asset judgement — the right number
depends on the `viewBox` — so check the result rather than applying `--precision=1` across a
directory.
