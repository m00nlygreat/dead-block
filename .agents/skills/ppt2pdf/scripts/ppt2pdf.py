"""Batch convert PowerPoint files to PDF using Microsoft PowerPoint COM automation."""

from __future__ import annotations

import argparse
import platform
import sys
from pathlib import Path


POWERPOINT_EXTENSIONS = {".ppt", ".pptx", ".pptm"}
PDF_FORMAT = 32


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="ppt2pdf.py",
        description="Convert .ppt, .pptx, and .pptm files to PDF with Microsoft PowerPoint."
    )
    parser.add_argument(
        "input",
        type=Path,
        help="PowerPoint file or directory containing PowerPoint files.",
    )
    parser.add_argument(
        "--out",
        type=Path,
        help="Directory where PDFs should be written. Defaults to beside each source deck.",
    )
    parser.add_argument(
        "--recursive",
        action="store_true",
        help="Search directories recursively.",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Replace existing PDF files.",
    )
    parser.add_argument(
        "--with-window",
        action="store_true",
        help="Open each presentation with a visible window while converting.",
    )
    return parser.parse_args()


def iter_decks(input_path: Path, recursive: bool) -> list[Path]:
    if input_path.is_file():
        if input_path.suffix.lower() not in POWERPOINT_EXTENSIONS:
            raise ValueError(f"Input file is not a PowerPoint deck: {input_path}")
        return [input_path]

    if not input_path.is_dir():
        raise FileNotFoundError(f"Input path does not exist: {input_path}")

    pattern = "**/*" if recursive else "*"
    return sorted(
        path
        for path in input_path.glob(pattern)
        if path.is_file() and path.suffix.lower() in POWERPOINT_EXTENSIONS
    )


def output_path_for(deck: Path, input_root: Path, output_dir: Path | None) -> Path:
    if output_dir is None:
        return deck.with_suffix(".pdf")

    if input_root.is_dir():
        try:
            relative_parent = deck.parent.relative_to(input_root)
        except ValueError:
            relative_parent = Path()
        return output_dir / relative_parent / f"{deck.stem}.pdf"

    return output_dir / f"{deck.stem}.pdf"


def create_powerpoint():
    try:
        import comtypes.client
    except ImportError as exc:
        raise RuntimeError(
            "Missing dependency: install comtypes with 'python -m pip install comtypes'."
        ) from exc

    powerpoint = comtypes.client.CreateObject("PowerPoint.Application")
    powerpoint.Visible = 1
    try:
        powerpoint.DisplayAlerts = 0
    except Exception:
        pass
    return powerpoint


def convert_deck(powerpoint, source: Path, destination: Path, with_window: bool) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    deck = None
    try:
        deck = powerpoint.Presentations.Open(str(source), True, False, bool(with_window))
        deck.SaveAs(str(destination), PDF_FORMAT)
    finally:
        if deck is not None:
            deck.Close()


def main() -> int:
    args = parse_args()

    if platform.system() != "Windows":
        print("This script requires Windows and locally installed Microsoft PowerPoint.", file=sys.stderr)
        return 2

    input_path = args.input.resolve()
    output_dir = args.out.resolve() if args.out else None

    try:
        decks = iter_decks(input_path, args.recursive)
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 2

    if not decks:
        print("No PowerPoint files found.")
        return 0

    powerpoint = None
    converted = 0
    skipped = 0
    failed = 0

    try:
        powerpoint = create_powerpoint()
        for deck in decks:
            destination = output_path_for(deck.resolve(), input_path, output_dir)
            if destination.exists() and not args.overwrite:
                print(f"SKIP exists: {destination}")
                skipped += 1
                continue

            try:
                convert_deck(powerpoint, deck.resolve(), destination, args.with_window)
                print(f"OK {deck} -> {destination}")
                converted += 1
            except Exception as exc:
                print(f"FAIL {deck}: {exc}", file=sys.stderr)
                failed += 1
    finally:
        if powerpoint is not None:
            powerpoint.Quit()

    print(f"Summary: converted={converted}, skipped={skipped}, failed={failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
