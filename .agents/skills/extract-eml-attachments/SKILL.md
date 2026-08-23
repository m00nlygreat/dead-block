---
name: extract-eml-attachments
description: Extract attachments from RFC 822 / MIME email files and replace the source .eml files with attachment-removed versions by default. Use when Codex needs to separate files attached to one or more .eml messages, preserve decoded attachment filenames, batch-process local .eml files, strip attachments while keeping the remaining email content, or explain/run a Python-based EML attachment workflow.
---

# Extract EML Attachments

## Workflow

Use the bundled Python script instead of hand-parsing MIME boundaries. By default, it extracts attachments and replaces the source `.eml` with a copy that has attachment parts removed. This default assumes the original message remains available in Gmail.

1. Identify the target `.eml` file or directory of `.eml` files.
2. Run `scripts/extract_eml_attachments.py`, passing the input path and attachment output directory when the defaults are not appropriate.
3. Check the summary output for extracted attachments, replaced EML paths, skipped messages, and filename collisions.

## Commands

Extract attachments from one EML file:

```powershell
python .\.codex\skills\extract-eml-attachments\scripts\extract_eml_attachments.py ".\message.eml" --out ".\attachments"
```

Extract attachments from every `.eml` file in a directory:

```powershell
python .\.codex\skills\extract-eml-attachments\scripts\extract_eml_attachments.py "." --out ".\attachments" --recursive
```

Use `--include-inline` only when the user also wants inline images or other inline MIME parts saved.
Use `--keep-eml` only when the user wants extracted attachments but does not want source `.eml` files replaced.

## Output Convention

The script creates one attachment subdirectory per EML message under the chosen attachment output directory. The subdirectory name is based on the EML filename, and duplicate attachment names are suffixed with `-2`, `-3`, and so on.

The script replaces each source `.eml` with an attachment-removed version by default. Do this only when the original email remains available elsewhere, such as Gmail.

Do not record routine extraction runs in `HISTORY.md`. Only update project documents if the user asks to make a project-level decision or scope change.
