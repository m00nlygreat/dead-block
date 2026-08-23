---
name: ssaju
description: Use golbin/ssaju for Korean saju, four-pillars, manselyeok, lunar/solar calendar conversion, daeun, seyun, wolun, ten-gods, 12-stage, sinsal, gongmang, and LLM-ready saju output. Use when Codex needs to calculate or explain saju data from birth date/time/gender/calendar inputs, integrate the npm package `ssaju`, produce compact or Markdown chart output, or call `lunarToSolar`/`solarToLunar`.
---

# ssaju

## Quick Start

Use the npm package `ssaju` for deterministic chart calculation before writing an interpretation. Do not hand-calculate pillars or calendar conversion when the package can run.

For a JavaScript/TypeScript project:

```bash
npm install ssaju
```

```ts
import { calculateSaju } from "ssaju";

const result = calculateSaju({
  year: 2001,
  month: 11,
  day: 3,
  hour: 14,
  minute: 20,
  gender: "여",
  calendar: "solar",
  timezone: "Asia/Seoul",
});

console.log(result.toCompact());
console.log(result.toMarkdown());
```

## Workflow

1. Normalize the user's birth data into a `SajuInput`.
2. Ask for missing required fields only when they cannot be reasonably inferred: `year`, `month`, and `day`.
3. Use defaults intentionally: omitted `hour` becomes noon, omitted `minute` becomes `0`, omitted `gender` follows the library default, and omitted `calendar` follows the library default. State when a meaningful input is assumed.
4. Run `calculateSaju` and use the structured result for programmatic work.
5. Use `toCompact()` when passing chart facts to an LLM or writing a concise analysis. Use `toMarkdown()` when the user wants readable tables or a report-style output.
6. Keep fortune-telling language scoped and non-deterministic. Present `ssaju` output as a traditional/interpretive framework, not as certainty.

## Script

Use `scripts/calculate-ssaju.mjs` when a task benefits from a repeatable command-line wrapper. The script resolves `ssaju` from the current project, so install the package in the project where the command is run.

```bash
node /path/to/ssaju/scripts/calculate-ssaju.mjs --input birth.json --format compact
node /path/to/ssaju/scripts/calculate-ssaju.mjs --input birth.json --format markdown
node /path/to/ssaju/scripts/calculate-ssaju.mjs --input birth.json --format json
```

`birth.json` must contain the same fields as `SajuInput`. If `now` is present, use an ISO date string.

## API Reference

Read `references/api.md` when integrating `ssaju` into application code, validating accepted inputs, or selecting fields from the result object.
