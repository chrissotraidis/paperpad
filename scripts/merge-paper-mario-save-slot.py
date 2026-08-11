#!/usr/bin/env python3
"""Safely merge one logical Paper Mario file into another FlashRAM image.

Paper Mario stores four logical files in six rotating 0x4000-byte physical
sectors.  This tool preserves every currently active logical file except the
requested destination, writes the donor into a non-active sector, advances its
save counter, and verifies the resulting checksums before producing output.
"""

from __future__ import annotations

import argparse
import hashlib
import struct
from dataclasses import dataclass
from pathlib import Path


FLASH_SIZE = 0x20000
PHYSICAL_SECTOR_SIZE = 0x4000
SAVE_DATA_SIZE = 0x1380
PHYSICAL_SAVE_COUNT = 6
LOGICAL_SAVE_COUNT = 4
MAGIC = b"Mario Story 006\0"


@dataclass(frozen=True)
class SaveRecord:
    physical_index: int
    logical_index: int
    save_count: int
    data: bytes


def u32be(data: bytes, offset: int) -> int:
    return struct.unpack_from(">I", data, offset)[0]


def checksum(data: bytes) -> int:
    return sum(struct.unpack(f">{SAVE_DATA_SIZE // 4}I", data)) & 0xFFFFFFFF


def parse_record(image: bytes, physical_index: int) -> SaveRecord | None:
    start = physical_index * PHYSICAL_SECTOR_SIZE
    data = image[start : start + SAVE_DATA_SIZE]
    if data[: len(MAGIC)] != MAGIC:
        return None

    crc1 = u32be(data, 0x30)
    crc2 = u32be(data, 0x34)
    logical_index = u32be(data, 0x38)
    if crc2 != ((~crc1) & 0xFFFFFFFF):
        return None
    if checksum(data) != crc1:
        return None
    if logical_index >= LOGICAL_SAVE_COUNT:
        return None

    return SaveRecord(
        physical_index=physical_index,
        logical_index=logical_index,
        save_count=u32be(data, 0x3C),
        data=data,
    )


def records(image: bytes) -> list[SaveRecord]:
    return [
        record
        for physical_index in range(PHYSICAL_SAVE_COUNT)
        if (record := parse_record(image, physical_index)) is not None
    ]


def active_records(parsed: list[SaveRecord]) -> dict[int, SaveRecord]:
    active: dict[int, SaveRecord] = {}
    for record in parsed:
        previous = active.get(record.logical_index)
        if previous is None or record.save_count > previous.save_count:
            active[record.logical_index] = record
    return active


def load_image(path: Path) -> bytes:
    data = path.read_bytes()
    if len(data) != FLASH_SIZE:
        raise ValueError(f"{path} is {len(data)} bytes; expected {FLASH_SIZE}")
    return data


def rewrite_slot_and_count(data: bytes, logical_index: int, save_count: int) -> bytes:
    rewritten = bytearray(data)
    struct.pack_into(">I", rewritten, 0x30, 0)
    struct.pack_into(">I", rewritten, 0x34, 0xFFFFFFFF)
    struct.pack_into(">I", rewritten, 0x38, logical_index)
    struct.pack_into(">I", rewritten, 0x3C, save_count)
    new_crc = checksum(rewritten)
    struct.pack_into(">I", rewritten, 0x30, new_crc)
    struct.pack_into(">I", rewritten, 0x34, (~new_crc) & 0xFFFFFFFF)
    if checksum(rewritten) != new_crc:
        raise AssertionError("rewritten donor checksum did not validate")
    return bytes(rewritten)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("live", type=Path, help="current 128 KiB PaperPad save")
    parser.add_argument("donor", type=Path, help="validated donor save image")
    parser.add_argument("output", type=Path, help="new path; never overwrites input")
    parser.add_argument(
        "--file",
        type=int,
        default=2,
        choices=range(1, LOGICAL_SAVE_COUNT + 1),
        help="user-visible destination file number (default: 2)",
    )
    args = parser.parse_args()

    if args.output.resolve() in {args.live.resolve(), args.donor.resolve()}:
        parser.error("output must be a new path, not either input")
    if args.output.exists():
        parser.error(f"output already exists: {args.output}")

    target = args.file - 1
    live = load_image(args.live)
    donor = load_image(args.donor)
    live_records = records(live)
    donor_records = records(donor)
    live_active = active_records(live_records)
    donor_active = active_records(donor_records)

    if target not in donor_active:
        raise ValueError(f"donor does not contain a valid File {args.file}")

    protected_indices = {
        record.physical_index
        for logical_index, record in live_active.items()
        if logical_index != target
    }
    candidates = [
        index for index in range(PHYSICAL_SAVE_COUNT) if index not in protected_indices
    ]
    if not candidates:
        raise ValueError("no non-active physical sector is available")

    by_physical = {record.physical_index: record for record in live_records}
    candidates.sort(
        key=lambda index: (
            index in by_physical,
            by_physical[index].save_count if index in by_physical else -1,
            index,
        )
    )
    destination_physical = candidates[0]
    next_count = max(
        [record.save_count for record in live_records]
        + [donor_active[target].save_count]
    ) + 1
    inserted = rewrite_slot_and_count(donor_active[target].data, target, next_count)

    merged = bytearray(live)
    sector_start = destination_physical * PHYSICAL_SECTOR_SIZE
    merged[sector_start : sector_start + PHYSICAL_SECTOR_SIZE] = bytes(
        [0xFF]
    ) * PHYSICAL_SECTOR_SIZE
    merged[sector_start : sector_start + SAVE_DATA_SIZE] = inserted
    merged_bytes = bytes(merged)

    merged_active = active_records(records(merged_bytes))
    if merged_active.get(target) is None:
        raise AssertionError(f"merged File {args.file} is not active")
    if merged_active[target].physical_index != destination_physical:
        raise AssertionError(f"merged File {args.file} did not win save rotation")
    for logical_index, before in live_active.items():
        if logical_index == target:
            continue
        after = merged_active.get(logical_index)
        if after is None or after.data != before.data:
            raise AssertionError(
                f"active File {logical_index + 1} changed during merge"
            )

    args.output.write_bytes(merged_bytes)
    print(f"Live SHA-256:   {sha256(live)}")
    print(f"Donor SHA-256:  {sha256(donor)}")
    print(f"Merged SHA-256: {sha256(merged_bytes)}")
    print(
        f"Inserted donor File {args.file} into physical sector "
        f"{destination_physical} with save count {next_count}."
    )
    for logical_index in sorted(merged_active):
        record = merged_active[logical_index]
        preservation = " (preserved)" if logical_index != target else " (inserted)"
        print(
            f"Active File {logical_index + 1}: physical sector "
            f"{record.physical_index}, count {record.save_count}{preservation}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
