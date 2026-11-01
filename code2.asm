.MODEL SMALL
.STACK 100H

.DATA
    MSG1 DB 'Unsorted Array: $'
    MSG2 DB 0DH, 0AH, 'Sorted Array (Hybrid): $'
    SPACE DB ' , $'
    
    ; 10-element Array
    ARR DB 95, 12, 2, 34, 177, 8, 42, 250, -1, 100
    LEN DW 10

.CODE
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX

    ; --- 1. Print Unsorted Array ---
    LEA DX, MSG1
    MOV AH, 09H
    INT 21H
    CALL PRINT_ARRAY

    ; =======================================================
    ; HYBRID SORT PHASE 1: MSD RADIX PARTITION (Bucket Sort)
    ; =======================================================
    MOV SI, 0           ; Left Pointer
    MOV DI, LEN
    DEC DI              ; Right Pointer

PARTITION_LOOP:
    CMP SI, DI
    JGE PHASE_2         ; Pointers cross korle Radix part shesh

FIND_LEFT:
    MOV AL, ARR[SI]
    TEST AL, 80H        ; Check Most Significant Bit (MSB = 128)
    JNZ FIND_RIGHT      ; MSB 1 hole eta Right bucket e jabe
    INC SI              
    CMP SI, DI
    JL FIND_LEFT
    JMP PHASE_2

FIND_RIGHT:
    MOV AL, ARR[DI]
    TEST AL, 80H
    JZ DO_SWAP          ; MSB 0 hole eta Left bucket e jabe, Swap koro!
    DEC DI
    CMP SI, DI
    JG FIND_RIGHT
    JMP PHASE_2

DO_SWAP:
    ; Swap ARR[SI] and ARR[DI]
    MOV AL, ARR[SI]
    MOV BL, ARR[DI]
    MOV ARR[SI], BL
    MOV ARR[DI], AL
    INC SI
    DEC DI
    JMP PARTITION_LOOP

    ; =======================================================
    ; HYBRID SORT PHASE 2: INSERTION SORT CUTOFF
    ; =======================================================
PHASE_2:
    MOV CX, 1           ; Loop counter (i = 1)

INSERT_OUTER:
    CMP CX, LEN
    JGE SORT_DONE       ; Sorting complete
    MOV SI, CX          
    MOV AL, ARR[SI]     ; Key to insert

INSERT_INNER:
    CMP SI, 0
    JLE INSERT_PLACE    
    
    MOV DI, SI
    DEC DI              ; Compare with left element
    MOV BL, ARR[DI]     
    
    CMP BL, AL
    JBE INSERT_PLACE    ; Unsigned check (Jump if Below or Equal)
    
    MOV ARR[SI], BL     ; Shift element right
    DEC SI              
    JMP INSERT_INNER

INSERT_PLACE:
    MOV ARR[SI], AL     ; Place key in correct position
    INC CX              
    JMP INSERT_OUTER

    ; --- 3. Print Sorted Array ---
SORT_DONE:
    LEA DX, MSG2
    MOV AH, 09H
    INT 21H
    CALL PRINT_ARRAY

    ; Exit Program
    MOV AH, 4CH
    INT 21H
MAIN ENDP

; =======================================================
; HELPER PROCEDURE: Print Array
; =======================================================
PRINT_ARRAY PROC
    MOV CX, LEN
    MOV SI, 0
PRINT_LOOP:
    MOV AL, ARR[SI]
    CALL PRINT_NUM      ; Number print korar function call
    
    ; Print space and comma
    PUSH AX
    PUSH DX
    LEA DX, SPACE
    MOV AH, 09H
    INT 21H
    POP DX
    POP AX

    INC SI
    LOOP PRINT_LOOP
    RET
PRINT_ARRAY ENDP

; =======================================================
; HELPER PROCEDURE: Print a number in AL (Decimal format)
; =======================================================
PRINT_NUM PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV AH, 0           ; Clear AH to divide AX
    MOV BL, 10          ; Divide by 10 to get digits
    MOV CX, 0           ; Digit counter

DIVIDE_LOOP:
    DIV BL              ; AL = Quotient, AH = Remainder
    PUSH AX             ; Save remainder (digit) on stack
    INC CX
    MOV AH, 0           ; Clear AH for next division
    CMP AL, 0
    JNE DIVIDE_LOOP

PRINT_DIGITS:
    POP AX
    MOV DL, AH          ; Get remainder from AH
    ADD DL, '0'         ; Convert to ASCII
    MOV AH, 02H
    INT 21H             ; Print char
    LOOP PRINT_DIGITS

    POP DX
    POP CX
    POP BX
    POP AX
    RET
PRINT_NUM ENDP

END MAIN