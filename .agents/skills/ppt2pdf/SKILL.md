---
name: ppt2pdf
description: Convert PowerPoint files to PDF in batches on Windows using locally installed Microsoft PowerPoint. Use when Codex needs to convert .ppt, .pptx, or .pptm files, process a folder of slide decks, preserve deck filenames as PDFs, or troubleshoot Python/comtypes PowerPoint automation.
---

# Batch PPT to PDF

## Workflow

Use the bundled Python script for deterministic conversion instead of retyping COM automation. It requires Windows, Microsoft PowerPoint, Python, and the `comtypes` package.

1. Identify the target file or directory.
2. Confirm the environment is Windows with PowerPoint installed.
3. Install `comtypes` if needed: `python -m pip install comtypes`.
4. Run `scripts/ppt2pdf.py` with the desired input and output options.
5. Check the script summary for converted, skipped, and failed files.

## Commands

Convert PowerPoint files in the current folder, writing PDFs beside the decks:

```powershell
python .\.agents\skills\ppt2pdf\scripts\ppt2pdf.py "."
```

Convert one deck:

```powershell
python .\.agents\skills\ppt2pdf\scripts\ppt2pdf.py ".\slides.pptx"
```

Convert a folder recursively into a separate output folder:

```powershell
python .\.agents\skills\ppt2pdf\scripts\ppt2pdf.py ".\decks" --recursive --out ".\pdf"
```

Use `--overwrite` when existing PDFs should be replaced. Use `--with-window` only for troubleshooting PowerPoint automation issues.

## Notes

- The script automates the local PowerPoint application and uses PDF save format `32`.
- PowerPoint may become visible while automation is running; this is normal for the COM application.
- On non-Windows machines or machines without PowerPoint, use another conversion path such as LibreOffice only if the user accepts possible formatting differences.
- Do not silently delete source decks or existing PDFs.
