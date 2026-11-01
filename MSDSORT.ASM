;=====================================================================
;  HYBRID SORT: MSD RADIX SORT (bit by bit, most significant bit first)
;               + INSERTION SORT                    8086 / emu8086
;---------------------------------------------------------------------
;  Idea (MSD radix sort by bits = "radix exchange sort": Knuth, TAOCP
;  Vol. 3, Sec 5.2.2; Sedgewick, Algorithms in C, Ch. 10; cutoff to
;  insertion sort: Sedgewick & Wayne, Algorithms 4th ed., Sec 5.1):
;   - Look at the keys one BIT at a time, starting with the most
;     significant bit (bit 7) of the first character.
;   - Items whose bit is 0 go to the left part, items whose bit is 1
;     to the right part (one pointer from each end, then swap).
;   - Both parts go on with the next bit; after bit 0 of a character
;     comes bit 7 of the next character.
;   - A bit on which all items agree splits nothing: just go on.
;   - A part with CUTOFF items or fewer is finished by insertion sort.
;
;  Input : one line of items separated by space, comma or tab.
;          Words, integers, negative and decimal numbers can be mixed,
;          e.g.  banana -7 42 Apple 3.5 0 cat -12.25 100
;  Output: numbers first in numeric order, then words in A-Z order
;          (upper/lower case treated the same).
;          Press Enter on an empty line to exit.
;
;  Every item gets a sort KEY ending with 0:
;    word   : '3' + the word in lower case
;    number : '2' + digit-count tag ('A'+n) + digits
;    negative number: '1' + tag ('Z'-n) + digits with 0<->9, 1<->8 ...
;                     swapped + '~'      (so -100 < -42 < -5)
;  Leading zeros are dropped. Up to 25 digits before the point.
;=====================================================================
.MODEL SMALL
.STACK 1000H

CUTOFF  EQU 3           ; parts with 3 items or fewer -> insertion sort
CUTB    EQU 4           ; same limit in bytes of PTRS: (CUTOFF-1)*2
MAXTOK  EQU 127         ; maximum number of items in one line
MAXFRAC EQU 100         ; maximum digits after the decimal point
KOFS    EQU 4           ; the key starts 4 bytes into a record
CAT_NEG EQU 31H         ; key type tag '1': negative number
CAT_POS EQU 32H         ; key type tag '2': zero or positive number
CAT_WRD EQU 33H         ; key type tag '3': word / anything else

.DATA
MSG_HEAD DB '=== Hybrid Sort: MSD Radix Sort + Insertion Sort ===',0DH,0AH
         DB 'Numbers come first (numeric order), then words (A-Z).',0DH,0AH,'$'
MSG_IN   DB 0DH,0AH,'Enter items (space/comma separated), Enter alone = exit:'
         DB 0DH,0AH,'> $'
MSG_STEP DB 'Show sorting steps? (y/n, then Enter): $'
MSG_NONE DB 'No items found.',0DH,0AH,'$'
MSG_OUT  DB 'Sorted ($'
MSG_OUT2 DB ' items): $'
MSG_ST1  DB 'Bit splits: $'
MSG_ST2  DB '   Insertion sorts: $'
MSG_SPL  DB '  Split on char $'
MSG_BIT  DB ', bit $'
MSG_ZERO DB ': 0[ $'
MSG_ONE  DB '] 1[ $'
MSG_END  DB ']',0DH,0AH,'$'
MSG_INS  DB '  Insertion sort  : $'
NEWL     DB 0DH,0AH,'$'

INBUF    DB 255, 0, 256 DUP(0)  ; DOS line buffer (max, count, text)
YNBUF    DB 3, 0, 4 DUP(0)      ; line buffer for the y/n answer
PTRS     DW 128 DUP(0)          ; record addresses: THIS array is sorted
RECBUF   DB 1100 DUP(0)         ; records: [text ptr][text len][key len][key...0]

NTOK     DW 0                   ; number of items
RECPTR   DW 0                   ; next free byte in RECBUF
ENDADR   DW 0                   ; end of the typed line
TSTART   DW 0                   ; current item: start address
TLEN     DW 0                   ; current item: length
CURD     DW 0                   ; character position d being looked at
BITM     DB 80H                 ; bit of that character (80H = bit 7)
SHOWST   DB 0                   ; 1 = print the sorting steps
PARTS    DW 0                   ; number of bit splits
INSC     DW 0                   ; number of insertion sorts
LOADR    DW 0                   ; insertion sort: first pointer
HIADR    DW 0                   ; insertion sort: last pointer
KEYREC   DW 0                   ; insertion sort: item being inserted
T_LO     DW 0                   ; step print: lo, first 1-item, hi
T_MID    DW 0
T_HI     DW 0
NUMF     DB 0                   ; number check: 1 = item is a number
NEGF     DB 0                   ;               1 = negative
DIGF     DB 0                   ;               1 = a digit was seen
INTS     DW 0                   ; first significant integer digit
INTN     DW 0                   ; count of significant integer digits
FRS      DW 0                   ; first digit after the point
FRN      DW 0                   ; count of digits after the point

.CODE
MAIN PROC
        MOV AX, @DATA
        MOV DS, AX
        MOV ES, AX              ; CMPSB compares DS:SI with ES:DI
        CLD                     ; string instructions move forward
        LEA DX, MSG_HEAD
        CALL PUTS
NEXTRUN:
        LEA DX, MSG_IN
        CALL PUTS
        LEA DX, INBUF           ; read one line (INT 21H, AH=0AH)
        MOV AH, 0AH
        INT 21H
        CALL CRLF
        CMP INBUF+1, 0          ; empty line -> exit
        JNE GOTLINE
        JMP QUIT
GOTLINE:
        CALL TOKENIZE           ; split line, build keys
        CMP NTOK, 0
        JNE HAVEITEMS
        LEA DX, MSG_NONE
        CALL PUTS
        JMP NEXTRUN
HAVEITEMS:
        LEA DX, MSG_STEP
        CALL PUTS
        LEA DX, YNBUF           ; read y/n and Enter (INT 21H, AH=0AH)
        MOV AH, 0AH
        INT 21H
        MOV SHOWST, 0
        MOV AL, YNBUF+2         ; the first key typed
        OR AL, 20H              ; 'Y' -> 'y'
        CMP AL, 'y'
        JNE STEPSET
        MOV SHOWST, 1
STEPSET:
        CALL CRLF
        MOV PARTS, 0
        MOV INSC, 0
        MOV CURD, 0             ; start at character 0 (type tag)
        MOV BITM, 80H           ; ... with its most significant bit
        MOV SI, OFFSET PTRS     ; lo = first item
        MOV DI, NTOK
        DEC DI
        SHL DI, 1
        ADD DI, OFFSET PTRS     ; hi = last item
        CALL MSDSORT
        CALL SHOWRES
        JMP NEXTRUN
QUIT:
        MOV AX, 4C00H           ; back to DOS
        INT 21H
MAIN ENDP

;---------------------------------------------------------------------
; MSDSORT: MSD radix sort of PTRS from SI (lo) to DI (hi), looking at
;          bit BITM of character CURD of every key.
;          SI and DI hold addresses of PTRS entries (2 bytes each).
;---------------------------------------------------------------------
MSDSORT PROC
MS_TOP:
        CMP DI, SI
        JB  MS_RET              ; empty part
        CMP BITM, 80H           ; starting a new character?
        JNE MS_SIZE
        CMP CURD, 0
        JE  MS_SIZE
        MOV BX, [SI]            ; all items here have the same previous
        ADD BX, CURD            ; character; if it was the end mark 0
        CMP BYTE PTR [BX+KOFS-1], 0 ; the keys are equal -> done
        JE  MS_RET
MS_SIZE:
        MOV AX, DI
        SUB AX, SI              ; AX = 2*(count-1)
        CMP AX, CUTB
        JG  MS_PART             ; more than CUTOFF items -> split
        CALL INSERTION          ; small part -> insertion sort
MS_RET:
        RET
MS_PART:
        PUSH SI                 ; save lo
        PUSH DI                 ; save hi
        MOV DL, BITM            ; DL = the bit to look at
        MOV CX, CURD            ; CX = the character to look at
MS_LEFT:                        ; from the left: find an item with bit 1
        CMP SI, DI
        JA  MS_DONE
        MOV BX, [SI]
        ADD BX, CX
        TEST BYTE PTR [BX+KOFS], DL
        JNZ MS_RIGHT
        ADD SI, 2
        JMP MS_LEFT
MS_RIGHT:                       ; from the right: find an item with bit 0
        CMP SI, DI
        JA  MS_DONE
        MOV BX, [DI]
        ADD BX, CX
        TEST BYTE PTR [BX+KOFS], DL
        JZ  MS_SWAP
        SUB DI, 2
        JMP MS_RIGHT
MS_SWAP:                        ; swap them: the 0 goes left, the 1 right
        MOV AX, [SI]
        XCHG AX, [DI]
        MOV [SI], AX
        ADD SI, 2
        SUB DI, 2
        JMP MS_LEFT
MS_DONE:                        ; 0 part = lo..SI-2, 1 part = SI..hi
        POP DI                  ; DI = hi
        POP BX                  ; BX = lo
        CMP SI, BX
        JE  MS_SAME             ; every bit was 1: nothing was split
        CMP SI, DI
        JA  MS_SAME             ; every bit was 0: nothing was split
        INC PARTS
        CMP SHOWST, 1
        JNE MS_REC
        MOV T_LO, BX
        MOV T_MID, SI
        MOV T_HI, DI
        CALL SHOWSPLIT
MS_REC:
        CALL NEXTBIT            ; both parts go on with the next bit
        MOV AL, BITM            ; keep that position for the 1 part
        PUSH AX
        MOV AX, CURD
        PUSH AX
        PUSH SI                 ; keep the 1 part: SI..DI
        PUSH DI
        MOV DI, SI              ; 1) 0 part: lo..SI-2
        SUB DI, 2
        MOV SI, BX
        CALL MSDSORT
        POP DI
        POP SI
        POP AX
        MOV CURD, AX
        POP AX
        MOV BITM, AL
        JMP MS_TOP              ; 2) 1 part (loop instead of a call)
MS_SAME:
        MOV SI, BX              ; same items, next bit
        CALL NEXTBIT
        JMP MS_TOP
MSDSORT ENDP

; NEXTBIT: go to the next bit (after bit 0 comes bit 7 of the next char)
NEXTBIT PROC
        SHR BITM, 1
        JNZ NB_EXIT
        MOV BITM, 80H
        INC CURD
NB_EXIT:
        RET
NEXTBIT ENDP

;---------------------------------------------------------------------
; INSERTION: insertion sort of PTRS from SI (lo) to DI (hi),
;            comparing keys from character position CURD.
;---------------------------------------------------------------------
INSERTION PROC
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX
        PUSH SI
        PUSH DI
        PUSH BP
        CMP DI, SI
        JBE IS_EXIT             ; 0 or 1 item: already sorted
        INC INSC
        MOV LOADR, SI
        MOV HIADR, DI
        MOV BP, SI              ; BP = address of item i
IS_NEXT:
        ADD BP, 2
        CMP BP, HIADR
        JA  IS_DONE
        MOV BX, BP
        MOV AX, [BX]
        MOV KEYREC, AX          ; item to insert
        MOV DX, BP              ; DX = empty slot
IS_SHIFT:
        CMP DX, LOADR
        JBE IS_PUT              ; reached the left end
        MOV BX, DX
        MOV SI, KEYREC
        MOV DI, [BX-2]
        CALL KEYLESS            ; CF=1 if item < left neighbour
        JNC IS_PUT
        MOV BX, DX
        MOV AX, [BX-2]
        MOV [BX], AX            ; move the neighbour one place right
        SUB DX, 2
        JMP IS_SHIFT
IS_PUT:
        MOV BX, DX
        MOV AX, KEYREC
        MOV [BX], AX
        JMP IS_NEXT
IS_DONE:
        CMP SHOWST, 1
        JNE IS_EXIT
        LEA DX, MSG_INS
        CALL PUTS
        MOV SI, LOADR
        MOV DI, HIADR
        CALL PRRANGE
        CALL CRLF
IS_EXIT:
        POP BP
        POP DI
        POP SI
        POP DX
        POP CX
        POP BX
        POP AX
        RET
INSERTION ENDP

;---------------------------------------------------------------------
; KEYLESS: CF=1 if key of record SI < key of record DI, comparing
;          from character position CURD with REPE CMPSB.
;---------------------------------------------------------------------
KEYLESS PROC
        PUSH CX
        PUSH SI
        PUSH DI
        MOV CL, [SI+3]          ; key length of the first item
        XOR CH, CH
        SUB CX, CURD
        INC CX                  ; compare up to and including the 0
        ADD SI, KOFS
        ADD SI, CURD
        ADD DI, KOFS
        ADD DI, CURD
        REPE CMPSB              ; stops at the first different char
        POP DI
        POP SI
        POP CX
        RET
KEYLESS ENDP

;---------------------------------------------------------------------
; TOKENIZE: split the typed line into items and build their records.
;---------------------------------------------------------------------
TOKENIZE PROC
        MOV NTOK, 0
        MOV RECPTR, OFFSET RECBUF
        MOV SI, OFFSET INBUF+2
        MOV AL, INBUF+1
        XOR AH, AH
        ADD AX, SI
        MOV ENDADR, AX
TK_SKIP:
        CMP SI, ENDADR          ; skip separators
        JAE TK_EXIT
        MOV AL, [SI]
        CALL ISSEP
        JNE TK_START
        INC SI
        JMP TK_SKIP
TK_START:
        CMP NTOK, MAXTOK
        JAE TK_EXIT
        MOV TSTART, SI
TK_SCAN:
        INC SI                  ; find the end of the item
        CMP SI, ENDADR
        JAE TK_ITEM
        MOV AL, [SI]
        CALL ISSEP
        JNE TK_SCAN
TK_ITEM:
        MOV AX, SI
        SUB AX, TSTART
        MOV TLEN, AX
        CALL MAKEREC
        JMP TK_SKIP
TK_EXIT:
        RET
TOKENIZE ENDP

; ISSEP: ZF=1 if AL is a separator (space, comma or tab)
ISSEP PROC
        CMP AL, ' '
        JE  SEP_YES
        CMP AL, ','
        JE  SEP_YES
        CMP AL, 9
SEP_YES:
        RET
ISSEP ENDP

;---------------------------------------------------------------------
; MAKEREC: build the record of the item at TSTART (TLEN chars)
;          and store its address in PTRS.
;---------------------------------------------------------------------
MAKEREC PROC
        PUSH SI
        MOV DI, RECPTR
        MOV BX, NTOK
        SHL BX, 1
        MOV PTRS[BX], DI        ; remember this record
        INC NTOK
        MOV AX, TSTART
        MOV [DI], AX            ; where the original text is
        MOV AX, TLEN
        MOV [DI+2], AL          ; its length
        CALL CHKNUM
        LEA BX, [DI+KOFS]       ; BX = where the key is written
        CMP NUMF, 1
        JE  MR_NUM
        MOV BYTE PTR [BX], CAT_WRD
        INC BX
        MOV SI, TSTART
        MOV CX, TLEN
MR_WORD:
        MOV AL, [SI]
        CMP AL, 'A'
        JB  MR_WPUT
        CMP AL, 'Z'
        JA  MR_WPUT
        ADD AL, 20H             ; upper case -> lower case
MR_WPUT:
        MOV [BX], AL
        INC BX
        INC SI
        LOOP MR_WORD
        JMP MR_END
MR_NUM:
        MOV AL, CAT_POS
        MOV AH, 'A'
        ADD AH, BYTE PTR INTN   ; tag = 'A' + digit count
        CMP NEGF, 1
        JNE MR_TAG
        MOV AL, CAT_NEG
        MOV AH, 'Z'
        SUB AH, BYTE PTR INTN   ; tag = 'Z' - digit count
MR_TAG:
        MOV [BX], AL
        MOV [BX+1], AH
        ADD BX, 2
        MOV SI, INTS            ; digits before the point
        MOV CX, INTN
        CALL PUTDIGS
        MOV SI, FRS             ; digits after the point
        MOV CX, FRN
        CALL PUTDIGS
        CMP NEGF, 1
        JNE MR_END
        MOV BYTE PTR [BX], '~'  ; end mark of a negative number
        INC BX
MR_END:
        MOV BYTE PTR [BX], 0    ; every key ends with 0
        MOV AX, BX
        SUB AX, DI
        SUB AX, KOFS
        MOV [DI+3], AL          ; key length
        INC BX
        MOV RECPTR, BX
        POP SI
        RET
MAKEREC ENDP

; PUTDIGS: copy CX digits from SI to the key at BX
;          (for a negative number 0<->9, 1<->8, ... are swapped)
PUTDIGS PROC
        JCXZ PD_EXIT
PD_LOOP:
        MOV AL, [SI]
        CMP NEGF, 1
        JNE PD_PUT
        MOV AH, 69H             ; 69H = '0' + '9'
        SUB AH, AL
        MOV AL, AH
PD_PUT:
        MOV [BX], AL
        INC BX
        INC SI
        LOOP PD_LOOP
PD_EXIT:
        RET
PUTDIGS ENDP

;---------------------------------------------------------------------
; CHKNUM: is the item a number?   [+|-] digits [. digits]
;   NUMF=1 if yes; NEGF, INTS/INTN, FRS/FRN describe the number.
;---------------------------------------------------------------------
CHKNUM PROC
        MOV NUMF, 0
        MOV NEGF, 0
        MOV DIGF, 0
        MOV INTN, 0
        MOV FRN, 0
        MOV SI, TSTART
        MOV CX, TLEN
        MOV AL, [SI]
        CMP AL, '-'
        JNE CK_PLUS
        MOV NEGF, 1
        JMP CK_SIGN
CK_PLUS:
        CMP AL, '+'
        JNE CK_ZERO
CK_SIGN:
        INC SI
        DEC CX
        JZ  CK_NO               ; a sign alone is not a number
CK_ZERO:
        CMP BYTE PTR [SI], '0'  ; drop leading zeros
        JNE CK_INT
        MOV DIGF, 1
        INC SI
        DEC CX
        JNZ CK_ZERO
        JMP CK_YES              ; only zeros: the value is 0
CK_INT:
        MOV INTS, SI
CK_IDIG:
        MOV AL, [SI]
        CMP AL, '0'
        JB  CK_POINT
        CMP AL, '9'
        JA  CK_POINT
        MOV DIGF, 1
        INC INTN
        INC SI
        DEC CX
        JNZ CK_IDIG
        JMP CK_TEST
CK_POINT:
        CMP AL, '.'
        JNE CK_NO
        INC SI
        DEC CX
        MOV FRS, SI
        JZ  CK_TEST             ; nothing after the point
CK_FDIG:
        MOV AL, [SI]
        CMP AL, '0'
        JB  CK_NO
        CMP AL, '9'
        JA  CK_NO
        MOV DIGF, 1
        INC FRN
        INC SI
        DEC CX
        JNZ CK_FDIG
CK_TEST:
        CMP DIGF, 1             ; at least one digit
        JNE CK_NO
        CMP INTN, 25            ; the tag has room for 25 digits
        JA  CK_NO
        CMP FRN, MAXFRAC
        JA  CK_NO
CK_YES:
        MOV NUMF, 1
        RET
CK_NO:
        MOV NUMF, 0             ; not a number -> sorted as a word
        MOV NEGF, 0
        RET
CHKNUM ENDP

;---------------------------------------------------------------------
; Output routines
;---------------------------------------------------------------------
; SHOWRES: print the sorted items and the step counts
SHOWRES PROC
        LEA DX, MSG_OUT
        CALL PUTS
        MOV AX, NTOK
        CALL PUTNUM
        LEA DX, MSG_OUT2
        CALL PUTS
        MOV SI, OFFSET PTRS
        MOV DI, NTOK
        DEC DI
        SHL DI, 1
        ADD DI, SI
        CALL PRRANGE
        CALL CRLF
        LEA DX, MSG_ST1
        CALL PUTS
        MOV AX, PARTS
        CALL PUTNUM
        LEA DX, MSG_ST2
        CALL PUTS
        MOV AX, INSC
        CALL PUTNUM
        CALL CRLF
        RET
SHOWRES ENDP

; SHOWSPLIT: print one split step (items with bit 0 / with bit 1)
SHOWSPLIT PROC
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX
        PUSH SI
        PUSH DI
        LEA DX, MSG_SPL
        CALL PUTS
        MOV AX, CURD
        INC AX                  ; characters are numbered from 1
        CALL PUTNUM
        LEA DX, MSG_BIT
        CALL PUTS
        MOV AL, BITM            ; bit number 7..0 from the mask
        XOR CX, CX
SS_BIT:
        SHR AL, 1
        JZ  SS_NUM
        INC CX
        JMP SS_BIT
SS_NUM:
        MOV AX, CX
        CALL PUTNUM
        LEA DX, MSG_ZERO
        CALL PUTS
        MOV SI, T_LO
        MOV DI, T_MID
        SUB DI, 2
        CALL PRRANGE
        LEA DX, MSG_ONE
        CALL PUTS
        MOV SI, T_MID
        MOV DI, T_HI
        CALL PRRANGE
        LEA DX, MSG_END
        CALL PUTS
        POP DI
        POP SI
        POP DX
        POP CX
        POP BX
        POP AX
        RET
SHOWSPLIT ENDP

; PRRANGE: print the items of PTRS from SI to DI (nothing if DI < SI)
PRRANGE PROC
        PUSH BX
        PUSH SI
PR_LOOP:
        CMP SI, DI
        JA  PR_EXIT
        MOV BX, [SI]
        CALL PRITEM
        CALL PSPACE
        ADD SI, 2
        JMP PR_LOOP
PR_EXIT:
        POP SI
        POP BX
        RET
PRRANGE ENDP

; PRITEM: print the original text of the record at BX
PRITEM PROC
        PUSH AX
        PUSH CX
        PUSH DX
        PUSH SI
        MOV SI, [BX]
        MOV CL, [BX+2]
        XOR CH, CH
PI_LOOP:
        MOV DL, [SI]
        MOV AH, 2
        INT 21H
        INC SI
        LOOP PI_LOOP
        POP SI
        POP DX
        POP CX
        POP AX
        RET
PRITEM ENDP

; PUTS: print the '$'-terminated string at DX
PUTS PROC
        PUSH AX
        MOV AH, 9
        INT 21H
        POP AX
        RET
PUTS ENDP

; CRLF: go to a new line
CRLF PROC
        PUSH DX
        LEA DX, NEWL
        CALL PUTS
        POP DX
        RET
CRLF ENDP

; PSPACE: print one space
PSPACE PROC
        PUSH AX
        PUSH DX
        MOV DL, ' '
        MOV AH, 2
        INT 21H
        POP DX
        POP AX
        RET
PSPACE ENDP

; PUTNUM: print AX as an unsigned decimal number
PUTNUM PROC
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX
        MOV BX, 10
        XOR CX, CX
PN_DIV:
        XOR DX, DX
        DIV BX
        PUSH DX                 ; remainder = next digit (right to left)
        INC CX
        TEST AX, AX
        JNZ PN_DIV
PN_OUT:
        POP DX
        ADD DL, '0'
        MOV AH, 2
        INT 21H
        LOOP PN_OUT
        POP DX
        POP CX
        POP BX
        POP AX
        RET
PUTNUM ENDP

END MAIN
