---
name: deck-author
description: Create, structure, refactor, and polish Markdown slide decks for md2ppt. Use when Codex needs to organize a deck or module flow, produce or edit a root deck Markdown file, embedded child Markdown modules, slide-ready assets, slide copy, language editing rules, layout or note directives, tables, code blocks, image references, or md2ppt-ready presentation source.
---

# Deck Author

## Overview

Use this skill to author Markdown that converts cleanly through [md2ppt](https://github.com/m00nlygreat/md2ppt) into PowerPoint. The converter flattens embedded Markdown, parses slides/placeholders, and renders them into a reference `.pptx` template.

This skill defines authoring rules only. Use `$deck-reviewer` when an existing deck needs a quality review or fast correction pass.

## Workflow

1. Identify the deck root, target audience, duration, and source material.
2. Before writing slide content, perform Slide Intent & Composition Planning at the detail appropriate to the requested mode: section-level planning for 흐름, slide-level planning for 초안 and 전개.
3. Choose the requested authoring mode: **흐름 (Flow)**, **초안 (Draft)**, or **전개 (Development)**. 흐름 is the stage before 초안, and both 흐름 and 초안 are optional; a general request to write or build a deck may proceed directly to 전개.
4. When the user explicitly requests 흐름 or asks to 정리 the 흐름, create or update the requested deck/lesson/module Markdown template. Start it with YAML frontmatter, then create exactly one level-2 heading for the single flow slide and place a flat, one-level list beneath it. Each list item should name one rough topic, stage, or activity in presentation order. Do not divide the flow into individual slide headings or write slide-level claims, body copy, evidence, visuals, layout directives, or speaker notes.
5. When the user explicitly requests 초안, start every draft Markdown file with YAML frontmatter. Set `type: text` for a root deck or lesson file and `type: module` for an embedded child module. Include `title` and `materials` in the draft frontmatter, then create only consecutive level-2 headings and one single-line list item under each heading. Use the heading as the slide title and the list item as a brief summary of the slide's claim and content. Do not add developed slide content in the same response or artifact unless the user also requests it.
6. When the user requests 전개 or a presentation-ready deck, write the necessary slide copy, evidence, visuals, tables, code, activities, and speaker notes. If an approved 초안 exists, preserve its claims and sequence unless a change is surfaced to the user; if only an approved 흐름 exists, preserve its sequence and refine each entry into slide claims before developing the content.
7. Create a root Markdown file with deck-level YAML frontmatter that includes `type: text`, `title`, and `materials`. Apply the same `type: text` frontmatter rule when authoring a lesson `text.md` directly.
8. Put lesson content in child Markdown modules under a stable module folder; put generated or collected visual assets under `attachments/`.
9. Before adding embedded child Markdown references to the root deck, show the proposed embed list and get user confirmation.
10. Use md2ppt grammar deliberately: `#` or `##` starts a slide, `***` splits placeholders inside the current slide, and `---` or `___` forces a new slide only when there is no new slide heading. Do not place `---` between consecutive slide headings.
11. Start every child module with YAML frontmatter containing `type: module`, `title`, and `materials`. Use `materials: []` when the module has no learner-facing materials. `flatten.py` ignores child frontmatter during embedding, but the metadata is required for project indexing, document classification, and standalone module review.
12. Save slide image assets as transparent PNG project files and reference them with relative Markdown image paths. If a new raster visual is needed for a slide, first try to find a relevant source or reference image through internet search when that would produce a more accurate or recognizable visual; otherwise use `$imagegen`. Move the final project-bound `.png` into `attachments/` before referencing it.
   - For newly generated slide visuals, use `$imagegen` with the default `gpt-image-2` image-generation path and request a bitmap/raster result. Do not substitute SVGs, hand-authored vector drawings, or flat vector-style placeholder art when the slide calls for an image. Use vector/flat SVG style only when the user explicitly requests that medium.
   - When prompting generated slide visuals, require all important subjects and objects to sit fully inside the image frame with clear safe margins on all four sides. Explicitly ask for generous top, bottom, left, and right padding, with no cropped heads, hands, devices, documents, UI panels, labels, props, or other key elements touching or nearly touching the image edge. Prefer a transparent or easily removable plain background so the asset sits naturally on the slide.
   - Do not reuse the same image across multiple slides merely to fill space. Repeat an image only when its instructional role changes across the sequence. If a slide feels visually empty, create or find a slide-specific visual instead of repeating a generic asset.
   - Do not rely on programmatic drawing libraries, canvas scripts, or hand-authored shape code to create slide images when the task calls for image generation. Use them only for deterministic markup and mechanical post-processing.
13. Before running `md2ppt`, choose and state the working directory explicitly. Default to the directory that contains the Markdown file passed to `-i`; do not run from the repository root merely because that is the current shell directory.

## Slide Intent & Composition Planning

Before writing slide content, first plan the intended role and composition of each slide. Do not start filling in body copy, bullets, charts, images, tables, or speaker notes until this planning step is complete.

For each slide, define:

1. Slide intent: what is the one thing this slide should make the audience understand, believe, decide, or feel? Express this as a single clear sentence, not a topic label.
2. Audience transition: what does the audience likely think before seeing this slide, and what should they think after seeing it? The slide should move the audience across that gap.
3. Narrative role: why does this slide exist at this point in the deck? Decide whether it sets context, makes a claim, proves a point, compares options, resolves tension, drives a decision, or performs another specific job.
4. Composition strategy: decide the necessary headline, primary explanatory format, supporting evidence, annotations, and minimal explanatory text before writing. Assign each element a job and remove any element that does not support the slide intent.
5. Content boundary: decide what this slide should not cover. If a point belongs in another slide, move it there instead of overloading the current slide.

Before drafting body content, choose the lightest format that carries the intent.

Only after this planning step should the slide be drafted. A slide is not a place to pour in available information; it is a deliberately designed step in the audience's reasoning.

## Authoring Modes: 흐름, 초안, and 전개

Treat **흐름 (Flow)** as a rough whole-module plan shown on one slide, **초안 (Draft)** as the multi-slide claim outline stage, and **전개 (Development)** as the presentation-ready writing mode. Do not require 흐름 or 초안 before 전개. Select the mode from the user's wording and return only the requested stage unless the user explicitly requests multiple stages together.

### 1. 흐름 (Flow)

Define 흐름 as a rough plan of the entire lesson or module, not as an outline with one heading per future slide. Treat requests to write, organize, or compose a flow as instructions to create or update the relevant deck, lesson, or module Markdown template itself.

- Start the flow Markdown file with YAML frontmatter containing `type`, `title`, and `materials`; use `type: text` for a root deck or lesson, `type: module` for a child module, and `materials: []` when no learner-facing materials are known yet.
- Create exactly one level-2 heading (`##`) representing the single flow slide. Use a short heading that identifies the flow.
- Under that heading, write a flat, one-level list in presentation order. Each item represents one rough topic, stage, or activity that may later become one slide, several slides, or part of another slide.
- Keep each list item short and provisional. It may name a concept, comparison, demonstration, practice, or transition without deciding the final slide title or central claim.
- Do not create multiple `##` headings, nested lists, slide-by-slide claims, body paragraphs, tables, code blocks, images, `---`, `***`, layout directives, or speaker notes.
- Do not silently interpret a 흐름 request as a request for 초안 or 전개.

### 2. 초안 (Draft)

Define 초안 as a slide-level outline, not abbreviated full content. For every planned slide:

- Start the draft Markdown file with YAML frontmatter containing `type`, `title`, and `materials`; use `type: text` for a root deck or lesson, `type: module` for a child module, and `materials: []` when no learner-facing materials are known yet.
- Write the page title as a level-2 heading (`##`).
- Write exactly one single-line list item immediately below it.
- Summarize the slide's central claim and intended content in that one line.
- List consecutive slides directly without `---`, `***`, body paragraphs, nested lists, tables, code blocks, images, layout directives, or speaker notes.
- Do not add developed slide body content to a 초안 unless the user explicitly requests both modes together.

### 3. 전개 (Development)

Proceed directly to 전개 when the user asks to write, build, complete, or make a presentation-ready deck without specifically requesting 흐름 or 초안. Select the lightest effective composition for each claim. Add only the body copy, evidence, visuals, tables, code, activities, and speaker notes needed to teach the slide's intended message. When an approved 초안 exists, preserve its slide order and claims unless a change is surfaced to the user; when only an approved 흐름 exists, preserve its sequence while refining each entry into a concrete slide claim.

## Slide Image Types

When planning or creating visuals, explicitly classify requested slide images using these six default types. These are defaults, not hard boundaries: if the user asks for an image that crosses categories, create the hybrid image that best serves the slide instead of forcing it into only one type.

1. Concept diagram: a simple relationship map of the core idea, usually 3-5 named elements connected by lines. Keep in-image text to element names, not explanatory sentences.
2. Process image: a workflow, flowchart, sequence, or timeline that shows the slide's steps. Prefer four or fewer steps with short labels and clear directional flow.
3. System/technical structure image: an architecture, data-flow, or component diagram. Show the main actors, interface, processing layer, storage, model, or external services as named blocks.
4. Case image: a representative case, result mockup, or compact comparison. Use real provided material when available; otherwise create a clearly illustrative case.
5. Metaphor image: a visual analogy for the deck's message. Prefer little or no text.
6. Markup image: annotations on a provided screenshot or image, using boxes, arrows, numbers, highlights, and short labels to point out key UI areas, issues, or comparison points. If no source screenshot or image is available, ask the user to provide one before making the markup image.

## Slide Image Patterns

Before creating a generated slide image, choose one of these common visual patterns and make that choice explicit in the prompt. If the user asks for a different style, follow the user's style instead.

1. Screenshot-like UI: a realistic but illustrative product or app screen mockup that shows a concrete interface state. Use this when the slide teaches screen recognition, tool operation, or a workflow. Keep it clearly illustrative, avoid official logos or exact product screenshots unless a real screenshot is provided, and use short, legible labels.
2. Abstract concept visual: a simplified conceptual image that shows structure, relationship, flow, hierarchy, transformation, or cause and effect without detailed UI. Use this when the slide teaches a mental model or would become cluttered with interface details. Prefer few labels and strong spatial organization.
3. Before / After comparison: a side-by-side or directional transformation image that makes a change visible. Use this when the slide contrasts two states. Label both states briefly and keep them visually comparable.
4. Process flow: a 3-5 step sequence that shows actions, phases, or data movement with directional arrows. Use this when the slide teaches a repeatable procedure, workflow, pipeline, checklist, or decision path. Keep each step label short, make the direction unambiguous, and avoid adding decorative branches that do not affect the action.
5. Annotated zoom / markup: a screenshot, UI mockup, or document detail with callouts, boxes, highlights, zoom bubbles, arrows, or numbered labels. Use this when the slide needs to point out where to click, which area matters, what changed, or what error to notice. Use real screenshots when available; if generating a mockup, keep it clearly illustrative and focus annotations on 1-4 key areas.

Nudge toward screenshot-like UI and annotated markup for hands-on tool operation slides; toward abstract concept visuals for principles, architecture, data modeling, and transitions; toward before-and-after comparison for change claims; and toward process flow for procedures. When uncertain, prefer the pattern that best supports the slide intent rather than filling space with decorative imagery.

All final deck-referenced images must be transparent PNG files. Source screenshots or references may arrive in other formats, but the asset saved under `attachments/` should be a `.png` with an alpha channel; preserve opaque screenshot/photo content when needed and keep any canvas, padding, or non-image background transparent. For generated raster assets, keep the full subject comfortably inside the canvas with visible safe margins on all four sides, preferably about 10-15% of the image width/height when composition allows. Reject or regenerate images where the main subject, text, device, document, character, hand, prop, or UI panel is cropped, cut off, flush against the edge, or too close to the edge to scale cleanly on a slide.

When a slide needs a concrete object, product, place, person, UI, case, or other reality-based visual, try internet image search before generating a new image. Prefer authoritative, relevant, inspectable sources over generic stock-like images. Use `$imagegen` when search does not provide a suitable source, when the slide needs a conceptual or synthetic visual, or when licensing/source constraints make direct reuse inappropriate. Save only the final deck-ready asset under `attachments/` and keep any source attribution or usage caveat in speaker notes when needed.

When using `$imagegen` for slide imagery, explicitly prompt for a generated bitmap/raster image and avoid vector-style language unless the user specifically requests vector art, SVG, or diagram-style drawing. Do not satisfy an image-generation request with native SVG shapes.

Do not use code-drawn graphics as a substitute for requested generated slide imagery. Use deterministic drawing only for limited mechanical markup and finishing tasks.

Within a single deck, avoid using the same image file on more than one slide unless the repetition is intentional and pedagogically useful. Acceptable repetitions include stepwise markup of the same screenshot, a before/after pair, or a final recap that explicitly refers back to an earlier visual. Unacceptable repetitions include using the same decorative workflow, icon set, or generic illustration to make unrelated slides look less empty.

## Language And Editing

Treat language editing as part of slide design, not as a separate proofreading pass. Make slide copy concise, consistent, and presentation-ready while preserving the original meaning, evidence level, and speaker intent.

### Default Tone

Use a clear, professional, instructional tone unless the user specifies otherwise. Avoid overly casual phrasing, exaggerated marketing copy, vague motivational language, and unsupported strengthening of claims.

For Korean decks, default to compact business Korean. Use outline-style Korean and noun-ending phrases by default for slide bullets, labels, and short supporting copy. Avoid excessive honorific endings on slides unless the deck's audience or brand voice requires them.

### Slide Copy Rules

- Keep each slide centered on one message.
- Prefer short phrases over full paragraphs.
- Use parallel structure within bullet lists.
- Use bullets when they are the clearest slide format. Keep simple parallel items as one-level lists.
- Use multi-level lists only when the content itself has genuine hierarchy.
- Do not turn every list into a multi-level list. If the items are equal-weight choices, features, materials, or steps, a flat list is usually clearer.
- Do not repeat the same composition mechanically across consecutive slides. Repetition includes identical placeholder counts, layout balance, content hierarchy, bullet depth, and text-to-visual arrangement.
- Vary composition according to slide intent. Use repeated composition only for a deliberate series, direct comparison, progressive reveal, or procedure where consistency carries meaning.
- Review every run of three consecutive slides and revise any accidental structural repetition before completion.
- Use Markdown inline emphasis deliberately: apply `**bold**` to the key term, number, decision, contrast, or takeaway that should catch the audience's eye; use `*italic*` sparingly for nuance, labels, cited wording, or secondary emphasis.
- Use Markdown inline code for literal technical tokens and exact interface values.
- Keep emphasis selective. Do not bold entire bullets, stack multiple emphasis styles on the same phrase without a clear reason, or emphasize so many words that the slide loses hierarchy.
- Do not mix noun-phrase bullets and sentence-style bullets in the same list unless there is a clear reason.
- Move nuance, transitions, and caveats into speaker notes instead of crowding the slide.
- Replace abstract wording with concrete nouns, verbs, and numbers.
- Keep image labels, diagram labels, and chart annotations short; use element names rather than explanatory sentences.

### Korean Editing Rules

For Korean slide decks:

- Keep spacing, punctuation, and terminology consistent.
- Prefer concise business Korean over translated-English phrasing.
- Write slide-visible text as phrase-based copy by default. Use sentence-style Korean only in limited practice-step instructions where prose is necessary for clear execution, or in quoted text.
- Avoid unnecessary English loanwords when a natural Korean term is clearer.
- Preserve domain terms, product names, model names, API names, and quoted source wording.
- Normalize repeated concepts to one canonical term within the deck.
- Use Arabic numerals for quantities, steps, dates, and measurable values unless the deck style requires otherwise.

### Titles And Headings

Use slide titles to keep each slide centered on one clear subject or role.
Choose topic-style, phrase-style, or message-style titles according to the deck's existing heading style and instructional context.
A stronger title is one that narrows the slide's scope and makes the content boundary clear.
When a slide primarily introduces or explains a clearly named concept, technology, tool, feature, function, method, or file format, use only its canonical name or the shortest unambiguous noun phrase as the title.
Do not replace a canonical concept name with a rhetorical question, metaphor, teaser, interpretation, benefit statement, or sentence-style summary.
Use interpretive, question, contrast, action, or message-style titles only when the slide's actual purpose is interpretation, comparison, decision, transition, or action rather than concept introduction.
The canonical-name rule takes priority over stylistic title variation. Never distort or embellish a concept name merely to avoid repetition.
Do not repeat the same grammatical frame, sentence ending, rhetorical device, or title length mechanically across consecutive slides.
Mix title styles only when each style matches the slide's role; do not create superficial variation that weakens accuracy.
Review every run of three consecutive titles and rewrite repeated subject-predicate frames, repeated questions, repeated contrasts, and repeated noun endings.
Treat title rhythm and slide composition as separate repetition checks; passing one does not excuse repetition in the other.

### Editing Scope

When asked to polish, proofread, or refine a deck:

1. Fix obvious grammar, spelling, spacing, and punctuation issues.
2. Tighten long sentences into slide-ready copy.
3. Make headings and bullets structurally consistent.
4. Preserve the original meaning, evidence level, and speaker intent.
5. Flag ambiguous claims instead of silently inventing details.
6. If the target audience or tone is unclear, use the default professional instructional tone and mention the assumption.

## Authoring Rules

- Any Markdown file passed directly to `md2ppt` must start with YAML frontmatter containing `type: text` and `title`; otherwise project indexing may misclassify the file and the generated PPTX may have an empty or broken title slide.
- Start every embedded child Markdown module with YAML frontmatter containing `type: module`, `title`, and `materials`. Use `materials: []` when no learner-facing materials are needed. Keep this metadata even though `flatten.py` ignores child frontmatter during embedding.
- Compile from the directory that makes the deck's relative paths resolve. Usually this is the input Markdown file's folder. Put debug output outside the content folder when needed.
- Before compiling a deck with embedded Markdown modules or images outside the deck folder, verify at least the referenced module paths and representative image paths with `Test-Path` from the intended working directory. If `md2ppt` reports missing images or invalid paths, treat the PPTX as not validated, fix the working directory or paths, and regenerate before reporting completion.
- Add `materials` to the root YAML frontmatter as a YAML list. Include only hands-on materials learners directly use during the lesson.
- Exclude deck-authoring artifacts and presentation-only assets from `materials`, including child Markdown modules, slide images, diagrams, generated visual assets, reference screenshots shown only by the instructor, and files used only to compose or render the PPTX.
- Exclude environment prerequisites from `materials`, including account creation, permissions, API keys, software installation, package installation, device/browser requirements, network access, and login status. If the lesson has no direct hands-on materials, use `materials: []`.
- Before inserting standalone child Markdown embeds into the root deck, present the intended embed paths and order to the user and wait for confirmation.
- Use standalone `![](child.md)` lines for embeds. `flatten.py` only expands Markdown embeds that occupy the full line.
- Use standalone image lines. Local image files are monopoly/block-level picture elements that occupy an image placeholder; inline images are not a reliable slide content pattern.
- Do not add `***` solely because a standalone image, pipe table, chart, diagram, or code block appears. These placeholder-occupying elements can create/occupy their own placeholder without `***`; use `***` only when you intentionally need to force separate text/media regions.
- In the default Content with Caption layout, put placeholder-occupying elements in the right/back placeholder by ordering content deliberately: write the caption, bullets, or explanatory text first, then place the block element. Add `***` only when the inferred split is ambiguous or you need an explicit boundary.
- Do not put a table and an image on the same slide. Treat tables and images as conceptually equivalent explanatory formats; choose one, or split them into separate slides when both are needed.
- Treat pipe tables as monopoly/block-level elements that occupy their entire placeholder. Do not continue with body text, headings, lists, or code after a table in the same visual area; put explanatory text before the table, force a separate region with `***`, or move the additional content to another slide.
- Do not add `[layout]: # (...)` by default. md2ppt infers the layout from headings, slide breaks, and placeholder count.
- Use `[layout]: # (layout_name)` only when intentionally forcing a layout that exists in the target template and cannot be inferred automatically. Do not add a layout name unless the target template actually contains it.
- Use `[note]: # (speaker note text)` on its own line for slide notes.
- Prefer `##` for normal content slides inside modules. Use `#` when a section divider or table-of-contents chapter is intentional.
- When the user requests 흐름 or asks to 정리 the 흐름, use the exact format defined in **Authoring Modes: 흐름, 초안, and 전개**: YAML frontmatter with `type`, `title`, and `materials`, followed by exactly one `##` heading and a flat, one-level list of rough topics, stages, or activities in presentation order. Do not create one heading per future slide, and do not include slide-level claims or expanded slide elements.
- When the user requests 초안, use the exact format defined in **Authoring Modes: 흐름, 초안, and 전개**: YAML frontmatter with `type`, `title`, and `materials`, followed by consecutive `##` slide titles with exactly one single-line list item under each title. Use `type: text` for a root deck or lesson and `type: module` for a child module. After the frontmatter, do not add `---` between slides; the heading already starts the next slide. Do not include expanded slide elements unless the user explicitly requests both 초안 and 전개 together.
- Use `---` or `___` only to force a new slide without a slide heading, or to separate two slides where the next slide intentionally starts with non-heading content.
- Keep each slide to one main message. If a slide intentionally needs separate text and media regions that md2ppt cannot infer safely from monopoly elements, split those areas with `***`.
- Use pipe tables only for small tables that can fit in one slide placeholder by themselves.
- Use fenced code blocks for code; include the language tag for syntax highlighting.

Read `references/md2ppt-format.md` when you need the full syntax, conversion pipeline, or layout details.
