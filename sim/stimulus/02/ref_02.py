#!/usr/bin/env python3
"""Reference solution for AOC 2025 Day 2 - Gift Shop

Usage:
    python3 ref_02.py <input_file> <output_dir>
Output:
    Writes CSV to {output_dir}/ref_02.csv
"""

import sys
import os


def is_double_number(n: int) -> bool:
    """True if n is a sequence of digits repeated exactly twice.
    e.g. 1212 is '12' twice. 1111 is '11' twice (but also '1' 4 times)."""
    s = str(n)
    if len(s) % 2 != 0:
        return False
    half = len(s) // 2
    return s[:half] == s[half:]


def is_repeated_number(n: int) -> bool:
    """True if n is a sequence of digits repeated two or more times.
    e.g. 111 is '1' three times, 1212 is '12' twice, 123123123 is '123' three times."""
    s = str(n)
    L = len(s)
    for plen in range(1, L // 2 + 1):
        if L % plen == 0:
            pattern = s[:plen]
            repeats = L // plen
            if repeats >= 2 and pattern * repeats == s:
                return True
    return False


def solve(text: str) -> tuple[int, int]:
    line = text.strip().splitlines()[0]
    ranges = line.split(",")
    total_a = 0
    total_b = 0
    for r in ranges:
        start, end = (int(x) for x in r.split("-"))
        for n in range(start, end + 1):
            if is_double_number(n):
                total_a += n
            if is_repeated_number(n):
                total_b += n
    return total_a, total_b


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: ref_02.py <input_file> <output_dir>", file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1]) as f:
        text = f.read()

    a, b = solve(text)

    out_path = os.path.join(sys.argv[2], "ref_02.csv")
    with open(out_path, "w") as f:
        f.write("SOLUTION_A,SOLUTION_B\n")
        f.write(f"{a},{b}\n")
