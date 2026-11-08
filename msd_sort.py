# MSD Radix Sort (bit by bit) + Insertion Sort -- same steps as MSDSORT.ASM
import re
import time

FNAME = r"C:\Users\sizan\Projects\assembly\DATA.TXT"
CUTOFF = 3                       # parts this small -> insertion sort
show = False                     # SHOW: print the steps or not


def to_key(x):                   # GETNUMS: XOR AX, 8000H
    return (x & 0xFFFF) ^ 0x8000


def from_key(v):                 # PRRANGE: XOR AX, 8000H, then read as signed
    x = v ^ 0x8000
    return x - 0x10000 if x & 0x8000 else x


def text(a, lo, hi):             # PRRANGE: numbers a[lo..hi]
    return " ".join(str(from_key(v)) for v in a[lo:hi + 1])


def insertion(a, lo, hi):        # INSERT
    for i in range(lo + 1, hi + 1):          # IN_NEXT
        key = a[i]
        j = i
        while j > lo and a[j - 1] > key:     # IN_SHIFT
            a[j] = a[j - 1]
            j -= 1
        a[j] = key                           # IN_PUT
    if show and hi > lo:
        print("  Insertion sort:", text(a, lo, hi))


def msd(a, lo, hi, bit):         # MSD
    while lo <= hi and bit:                  # MS_TOP
        if hi - lo + 1 <= CUTOFF:
            insertion(a, lo, hi)
            return
        i, j = lo, hi
        while True:
            while i <= j and not a[i] & bit:     # MS_LEFT: bit 0, go on
                i += 1
            while i <= j and a[j] & bit:         # MS_RIGHT: bit 1, go on
                j -= 1
            if i > j:                            # MS_DONE
                break
            a[i], a[j] = a[j], a[i]              # MS_SWAP
            i += 1
            j -= 1
        if i == lo or i > hi:                    # MS_SAME: nothing split
            bit >>= 1
            continue
        if show:
            print(f"  Split on bit {bit.bit_length() - 1}: "
                  f"0[ {text(a, lo, i - 1)} ] 1[ {text(a, i, hi)} ]")
        bit >>= 1
        msd(a, lo, i - 1, bit)               # CALL MSD: the 0-part
        lo = i                               # JMP MS_TOP: the 1-part


def sort_all(a):                 # SORTARR
    msd(a, 0, len(a) - 1, 0x8000)


def main():
    global show
    print("MSD Radix Sort + Insertion Sort")
    choice = input("Read from: 1 = keyboard, 2 = file DATA.TXT : ").strip()
    if choice == "2":
        try:
            with open(FNAME) as f:
                data = f.read()
        except OSError:
            print("File not found:", FNAME)
            return
    else:
        data = input("Numbers: ")

    a = [to_key(int(s)) for s in re.findall(r"-?\d+", data)]   # GETNUMS
    print("Unsorted:", text(a, 0, len(a) - 1))
    backup = a[:]                                            # REP MOVSW

    show = False
    start = time.perf_counter()
    sort_all(a)
    elapsed = time.perf_counter() - start

    print("Sorted  :", text(a, 0, len(a) - 1))
    print(f"Time    : {elapsed:.6f} sec")
    if len(a) > 30:
        print("(Steps are shown for 30 numbers or fewer.)")
        return
    print("Steps:")
    a = backup[:]
    show = True
    sort_all(a)


main()
