def count_zero_hits(lines):
    pos = 50              # starting position
    zero_hits = 0

    for line in lines:
        line = line.strip()
        if not line:
            continue
        
        direction = line[0]
        amount = int(line[1:])

        if direction == 'L':
            pos = (pos - amount) % 100
        else:  # 'R'
            pos = (pos + amount) % 100

        if pos == 0:
            zero_hits += 1

    return zero_hits


# If reading from a file called "input.txt":
if __name__ == "__main__":
    with open("../../input/input_01.txt") as f:
        lines = f.readlines()
    print(count_zero_hits(lines))
