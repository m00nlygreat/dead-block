# ssaju API Reference

Source package: `ssaju` by `golbin/ssaju`.
Current npm version checked during skill creation: `0.2.0`.
Runtime: Node.js `>=18`, ESM package.

## Install

```bash
npm install ssaju
```

## Exports

```ts
import { calculateSaju, lunarToSolar, solarToLunar } from "ssaju";
import type { SajuInput, SajuResult } from "ssaju";
```

## `calculateSaju(input)`

Required input:

```ts
{
  year: number;
  month: number;
  day: number;
}
```

Optional input:

```ts
{
  hour?: number;                  // default: 12
  minute?: number;                // default: 0
  gender?: "남" | "여";
  calendar?: "solar" | "lunar";
  leap?: boolean;                 // lunar leap month flag
  timezone?: string;              // e.g. "Asia/Seoul"
  longitude?: number;             // used when applyLocalMeanTime is true
  applyLocalMeanTime?: boolean;
  now?: Date;                     // deterministic daeun/seyun/wolun reference date
}
```

Typical result fields:

```ts
{
  input;
  normalized;
  solar;
  pillars;        // { year, month, day, hour }
  pillarDetails;
  dayStem;
  dayBranch;
  gongmang;
  fiveElements;
  tenGods;
  stages12;
  stemRelations;
  branchRelations;
  sals;
  currentAge;
  currentYear;
  daeun;
  seyun;
  wolun;
  advanced;
  reference;
  toCompact(): string;
  toMarkdown(): string;
}
```

Use `now` for deterministic tests, examples, or reports tied to a specific 기준일.

## Output Choice

- `result.toCompact()`: concise LLM-ready text, usually the best context to feed into a separate interpretation prompt.
- `result.toMarkdown()`: readable Markdown tables for direct user-facing reports.
- Structured fields: best for UI, JSON APIs, filtering, tests, or custom reports.

## Calendar Conversion

```ts
const solar = lunarToSolar(1992, 9, 29, false);
const lunar = solarToLunar(1992, 10, 24);
```

Use these functions instead of implementing Korean lunar/solar conversion manually.

## Input Notes

- Validate user-provided dates before or around `calculateSaju`; invalid solar dates, invalid lunar leap flags, invalid time zones, and invalid enum-like values throw.
- `calendar: "lunar"` requires `leap` when the month could be a leap month.
- `applyLocalMeanTime: true` should include `longitude`. The library adjusts the calculation timestamp and may change the hour pillar.
- For Korean user prompts, map 성별 to `"남"` or `"여"` and 양력/음력 to `"solar"`/`"lunar"`.
