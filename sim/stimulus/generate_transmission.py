#!/usr/bin/env python3

import glob
import re
import argparse
from pathlib import Path

STX = b'\x02'  # ASCII 0x02
ETX = b'\x03'  # ASCII 0x03
EOT = b'\x04'  # ASCII 0x04


def parse_range(rng):
    """Parse m-n into a list of ints"""
    start, end = map(int, rng.split("-"))
    return list(range(start, end + 1))


def parse_list(lst):
    """Parse comma-separated list into ints"""
    return [int(x.strip()) for x in lst.split(",")]


def find_input_file(day):
    """
    Find */input_*.txt for a given day number (01..12).
    Returns None if not found.
    """
    pattern = f"{day:02d}/input_*.txt"
    matches = glob.glob(pattern)
    return matches[0] if matches else None


def main():
    parser = argparse.ArgumentParser(
        description="Concatenate AoC input files with ETX and EOT markers"
    )
    group = parser.add_mutually_exclusive_group(required=False)
    group.add_argument("--range", help="Range of days, e.g. 1-12")
    group.add_argument("--list", help="Comma-separated days, e.g. 1,3,7,12")
    parser.add_argument("-o", "--output", default="transmission.bin")

    args = parser.parse_args()

    if args.range:
        days = parse_range(args.range)
    elif args.list:
        days = parse_list(args.list)
    else:
        days = list(range(1, 13)) # 1 to 12 inclusive

    output = bytearray()
    output.extend(STX)
    found = 0

    for day in days:
        fname = find_input_file(day)
        if not fname:
            print(f"Warning: input file for day {day:02d} not found, skipping")
            continue

        with open(fname, "rb") as f:
            output.extend(f.read())
        output.extend(ETX)
        found += 1

    output.extend(EOT)

    with open(args.output, "wb") as out:
        out.write(output)

    print(f"Wrote {args.output} ({found} files, {len(output)} bytes)")


if __name__ == "__main__":
    main()
