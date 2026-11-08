// MSD Radix Sort (bit by bit) + Insertion Sort -- same steps as MSDSORT.ASM
#include <chrono>
#include <cstdio>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>
using namespace std;

const char *FNAME = "C:\\Users\\sizan\\Projects\\assembly\\DATA.TXT";
const int CUTOFF = 3;            // parts this small -> insertion sort
bool show = false;               // SHOW: print the steps or not
vector<unsigned> a;              // ARR: each number stored as x XOR 8000H

int fromKey(unsigned v) {        // PRRANGE: XOR 8000H, then read as signed
    return (short)(v ^ 0x8000);
}

void printRange(int lo, int hi) {                 // PRRANGE
    for (int k = lo; k <= hi; k++) printf("%d ", fromKey(a[k]));
}

void getNums(const string &s) {                   // GETNUMS
    unsigned num = 0;                             // AX
    bool inNum = false, neg = false;              // BL, BH
    for (char c : s + " ") {                      // " " ends the last number
        if (c >= '0' && c <= '9') {
            num = (num * 10 + (c - '0')) & 0xFFFF;    // AX = AX*10 + digit
            inNum = true;
        } else {                                  // GN_SEP
            if (inNum) {
                if (neg) num = (0x10000 - num) & 0xFFFF;  // NEG AX
                a.push_back(num ^ 0x8000);        // XOR AX, 8000H
                num = 0;
                inNum = false;
            }
            neg = (c == '-');                     // GN_SIGN
        }
    }
}

void insertion(int lo, int hi) {                  // INSERT
    for (int i = lo + 1; i <= hi; i++) {          // IN_NEXT
        unsigned key = a[i];
        int j = i;
        while (j > lo && a[j - 1] > key) {        // IN_SHIFT
            a[j] = a[j - 1];
            j--;
        }
        a[j] = key;                               // IN_PUT
    }
    if (show && hi > lo) {
        printf("  Insertion sort: ");
        printRange(lo, hi);
        printf("\n");
    }
}

void msd(int lo, int hi, unsigned bit) {          // MSD
    while (lo <= hi && bit) {                     // MS_TOP
        if (hi - lo + 1 <= CUTOFF) {
            insertion(lo, hi);
            return;
        }
        int i = lo, j = hi;
        while (true) {
            while (i <= j && !(a[i] & bit)) i++;  // MS_LEFT: bit 0, go on
            while (i <= j && (a[j] & bit)) j--;   // MS_RIGHT: bit 1, go on
            if (i > j) break;                     // MS_DONE
            swap(a[i], a[j]);                     // MS_SWAP
            i++;
            j--;
        }
        if (i == lo || i > hi) {                  // MS_SAME: nothing split
            bit >>= 1;
            continue;
        }
        if (show) {
            int b = 0;
            for (unsigned m = bit; m >>= 1; ) b++;    // SHOWSPLIT: bit number
            printf("  Split on bit %d: 0[ ", b);
            printRange(lo, i - 1);
            printf("] 1[ ");
            printRange(i, hi);
            printf("]\n");
        }
        bit >>= 1;
        msd(lo, i - 1, bit);                      // CALL MSD: the 0-part
        lo = i;                                   // JMP MS_TOP: the 1-part
    }
}

int main() {
    printf("MSD Radix Sort + Insertion Sort\n");
    printf("Read from: 1 = keyboard, 2 = file DATA.TXT : ");
    fflush(stdout);
    string choice, data;
    getline(cin, choice);
    if (!choice.empty() && choice[0] == '2') {
        ifstream f(FNAME);
        if (!f) {
            printf("File not found: %s\n", FNAME);
            return 0;
        }
        stringstream ss;
        ss << f.rdbuf();
        data = ss.str();
    } else {
        printf("Numbers: ");
        fflush(stdout);
        getline(cin, data);
    }

    getNums(data);
    int n = a.size();
    printf("Unsorted: "); printRange(0, n - 1); printf("\n");
    vector<unsigned> backup = a;                  // REP MOVSW

    show = false;
    auto t0 = chrono::steady_clock::now();
    msd(0, n - 1, 0x8000);                        // SORTARR
    auto t1 = chrono::steady_clock::now();
    double sec = chrono::duration<double>(t1 - t0).count();

    printf("Sorted  : "); printRange(0, n - 1); printf("\n");
    printf("Time    : %.6f sec\n", sec);
    if (n > 30) {
        printf("(Steps are shown for 30 numbers or fewer.)\n");
        return 0;
    }
    printf("Steps:\n");
    a = backup;
    show = true;
    msd(0, n - 1, 0x8000);
    return 0;
}
