#!/usr/bin/env python3
"""Reference solution for AOC 2025 Day 1 - Secret Entrance

Usage:
    python3 ref_01.py <input_file> <output_dir>
Output:
    Writes CSV to {output_dir}/ref_01.csv
"""

import sys
import os


def solve(text: str) -> tuple[int, int]:
    dial = 50
    sol_a = 0  # times the dial ends at 0
    sol_b = 0  # total times the dial points at 0 (ends + passes)

    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        direction = line[0]
        steps = int(line[1:])
        old = dial

        if direction == 'R':
            total = old + steps
            dial = total % 100
            zero_passes = (total - 1) // 100
        else:  # 'L'
            dial = (old - steps) % 100
            if old > 0 and steps > old:
                zero_passes = 1 + (steps - old - 1) // 100
            else:
                zero_passes = max(0, (steps - old - 1) // 100)

        ends_at_zero = 1 if dial == 0 else 0
        sol_a += ends_at_zero
        sol_b += ends_at_zero + zero_passes

    return sol_a, sol_b


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: ref_01.py <input_file> <output_dir>", file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1]) as f:
        text = f.read()

    a, b = solve(text)

    out_path = os.path.join(sys.argv[2], "ref_01.csv")
    with open(out_path, "w") as f:
        f.write("SOLUTION_A,SOLUTION_B\n")
        f.write(f"{a},{b}\n")
