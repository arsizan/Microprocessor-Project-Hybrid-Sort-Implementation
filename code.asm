.MODEL SMALL
.STACK 100H

.DATA
    ; Amader unsorted array (10 ta random hexadecimal number)
    ARR DB 85H, 12H, 9AH, 34H, 77H, 0F1H, 22H, 0E3H, 45H, 66H
    LEN DW 10

.CODE
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX

    ; =======================================================
    ; PHASE 1: MSD RADIX PARTITION (Bucket by Most Significant Bit)
    ; =======================================================
    MOV SI, 0           ; SI = Left Pointer (Shuru theke)
    MOV DI, LEN
    DEC DI              ; DI = Right Pointer (Shesh theke)

PARTITION_LOOP:
    CMP SI, DI
    JGE PHASE_2         ; Left ar Right pointer cross korle Phase 1 shesh

FIND_LEFT:
    MOV AL, ARR[SI]
    TEST AL, 80H        ; Check Most Significant Bit (10000000 in binary)
    JNZ FIND_RIGHT      ; Jodi MSB 1 hoy, tahole eta dan dike jabe, tai wait koro
    INC SI              ; MSB 0 hole thik jaygay ache, porer ta check koro
    CMP SI, DI
    JL FIND_LEFT        ; Jotokhon na cross kore totokhon khujo
    JMP PHASE_2

FIND_RIGHT:
    MOV AL, ARR[DI]
    TEST AL, 80H
    JZ DO_SWAP          ; Jodi MSB 0 hoy, eta bame jabe! Swap koro.
    DEC DI              ; MSB 1 hole thik ache, bamer ta check koro
    CMP SI, DI
    JG FIND_RIGHT
    JMP PHASE_2

DO_SWAP:
    ; ARR[SI] te ache 1 (boro), ARR[DI] te ache 0 (choto). Eder jayga bodol korbo.
    MOV AL, ARR[SI]
    MOV BL, ARR[DI]
    MOV ARR[SI], BL
    MOV ARR[DI], AL
    INC SI
    DEC DI
    JMP PARTITION_LOOP

    ; =======================================================
    ; PHASE 2: INSERTION SORT (The Hybrid Cutoff)
    ; =======================================================
PHASE_2:
    MOV CX, 1           ; i = 1 (Loop counter)

INSERT_OUTER:
    CMP CX, LEN
    JGE DONE            ; i >= LEN hole sorting shesh
    MOV SI, CX          ; SI = current element index
    MOV AL, ARR[SI]     ; AL = key (jeta ke jaygamoto boshabo)

INSERT_INNER:
    CMP SI, 0
    JLE INSERT_PLACE    ; Array er shurute chole ashle loop break
    
    MOV DI, SI
    DEC DI              ; DI = SI - 1 (Bamer element check korbo)
    MOV BL, ARR[DI]     ; BL = bamer data
    
    CMP BL, AL
    JLE INSERT_PLACE    ; Jodi bamer data key er theke choto ba soman hoy, tahole thik ache
    
    MOV ARR[SI], BL     ; Bamer data boro hole setake ek ghor dan dike soriye dibo
    DEC SI              ; SI er man komiye aro bame khujbo
    JMP INSERT_INNER

INSERT_PLACE:
    MOV ARR[SI], AL     ; Key ke tar sothik jaygay bosiye dilam
    INC CX              ; i++
    JMP INSERT_OUTER

DONE:
    ; Program theke ber howar code
    MOV AH, 4CH
    INT 21H

MAIN ENDP
END MAIN