#!/usr/bin/env python3
"""Extract attachments from .eml files using Python's standard email package."""

from __future__ import annotations

import argparse
import re
from email.generator import BytesGenerator
from email import policy
from email.parser import BytesParser
from pathlib import Path
import tempfile


WINDOWS_RESERVED_NAMES = {
    "CON",
    "PRN",
    "AUX",
    "NUL",
    *(f"COM{i}" for i in range(1, 10)),
    *(f"LPT{i}" for i in range(1, 10)),
}


def safe_name(name: str, fallback: str) -> str:
    """Return a filesystem-safe filename while preserving readable Unicode."""
    value = name.strip() or fallback
    value = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", value)
    value = value.rstrip(" .")
    if not value:
        value = fallback
    stem = value.split(".", 1)[0].upper()
    if stem in WINDOWS_RESERVED_NAMES:
        value = f"_{value}"
    return value


def unique_path(directory: Path, filename: str) -> Path:
    candidate = directory / filename
    if not candidate.exists():
        return candidate

    stem = candidate.stem
    suffix = candidate.suffix
    counter = 2
    while True:
        next_candidate = directory / f"{stem}-{counter}{suffix}"
        if not next_candidate.exists():
            return next_candidate
        counter += 1


def save_payload(directory: Path, filename: str, payload: bytes) -> Path:
    preferred = directory / filename
    if preferred.exists() and preferred.read_bytes() == payload:
        print(f"exists: {preferred}")
        return preferred

    target = unique_path(directory, filename)
    target.write_bytes(payload)
    print(f"saved: {target}")
    return target


def iter_eml_paths(input_path: Path, recursive: bool) -> list[Path]:
    if input_path.is_file():
        return [input_path]
    pattern = "**/*.eml" if recursive else "*.eml"
    return sorted(path for path in input_path.glob(pattern) if path.is_file())


def part_is_attachment(part, include_inline: bool) -> bool:
    disposition = part.get_content_disposition()
    if disposition == "attachment":
        return True
    if include_inline and disposition == "inline" and part.get_filename():
        return True
    return False


def strip_matching_parts(part, include_inline: bool) -> int:
    if not part.is_multipart():
        return 0

    kept_parts = []
    removed = 0
    for child in part.get_payload():
        if part_is_attachment(child, include_inline):
            removed += 1
            continue
        removed += strip_matching_parts(child, include_inline)
        kept_parts.append(child)

    part.set_payload(kept_parts)
    return removed


def replace_with_stripped_eml(message, eml_path: Path, include_inline: bool) -> Path:
    strip_matching_parts(message, include_inline)
    with tempfile.NamedTemporaryFile("wb", delete=False, dir=eml_path.parent, suffix=".tmp") as handle:
        generator = BytesGenerator(handle, policy=policy.default)
        generator.flatten(message)
        temp_path = Path(handle.name)
    temp_path.replace(eml_path)
    return eml_path


def extract_from_eml(
    eml_path: Path,
    out_root: Path,
    include_inline: bool,
    replace_original: bool,
) -> int:
    with eml_path.open("rb") as handle:
        message = BytesParser(policy=policy.default).parse(handle)

    message_dir = out_root / safe_name(eml_path.stem, "message")
    message_dir.mkdir(parents=True, exist_ok=True)

    count = 0
    unnamed_counter = 1
    for part in message.walk():
        if part.is_multipart() or not part_is_attachment(part, include_inline):
            continue

        payload = part.get_payload(decode=True)
        if payload is None:
            continue

        filename = part.get_filename()
        if not filename:
            filename = f"attachment-{unnamed_counter}"
            unnamed_counter += 1

        save_payload(message_dir, safe_name(filename, f"attachment-{unnamed_counter}"), payload)
        count += 1

    if count == 0:
        print(f"no attachments: {eml_path}")
    if replace_original:
        stripped_path = replace_with_stripped_eml(message, eml_path, include_inline)
        print(f"replaced: {stripped_path}")
    return count


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract attachments from .eml files.")
    parser.add_argument("input", type=Path, help="An .eml file or a directory containing .eml files.")
    parser.add_argument("--out", type=Path, default=Path("attachments"), help="Output directory.")
    parser.add_argument("--keep-eml", action="store_true", help="Do not replace source .eml files with attachment-removed copies.")
    parser.add_argument("--recursive", action="store_true", help="Search directories recursively for .eml files.")
    parser.add_argument("--include-inline", action="store_true", help="Also save inline MIME parts that have filenames.")
    args = parser.parse_args()

    input_path = args.input.resolve()
    out_root = args.out.resolve()
    if not input_path.exists():
        parser.error(f"input does not exist: {input_path}")

    eml_paths = iter_eml_paths(input_path, args.recursive)
    if not eml_paths:
        print(f"no .eml files found: {input_path}")
        return 1

    out_root.mkdir(parents=True, exist_ok=True)
    total = 0
    for eml_path in eml_paths:
        total += extract_from_eml(
            eml_path,
            out_root,
            args.include_inline,
            not args.keep_eml,
        )

    print(f"processed {len(eml_paths)} message(s), extracted {total} attachment(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
