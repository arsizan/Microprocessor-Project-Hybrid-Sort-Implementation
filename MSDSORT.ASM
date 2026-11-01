.MODEL SMALL
.STACK 400H
CUTOFF  EQU 3      

.DATA
FNAME    DB 'C:\Users\sizan\Projects\assembly\DATA.TXT',0
MSG_ASK  DB 'MSD Radix Sort + Insertion Sort',13,10
         DB 'Read from: 1 = keyboard, 2 = file DATA.TXT : $'
MSG_KEY  DB 13,10,'Numbers: $'
MSG_NOF  DB 13,10,'File not found: C:\Users\sizan\Projects\assembly\DATA.TXT$'
MSG_UNS  DB 'Unsorted: $'
MSG_RES  DB 'Sorted  : $'
MSG_TIM  DB 'Time    : $'
MSG_SEC  DB ' sec',13,10,'$'
MSG_BIG  DB 13,10,'(Steps are shown for 30 numbers or fewer.)',13,10,'$'
MSG_STP  DB 13,10,'Steps:',13,10,'$'
MSG_SPL  DB '  Split on bit $'
MSG_ZERO DB ': 0[ $'
MSG_ONE  DB '] 1[ $'
MSG_END  DB ']',13,10,'$'
MSG_INS  DB '  Insertion sort: $'
NEWL     DB 13,10,'$'

CHOICE   DB 2, 0, 2 DUP(0)      
LINE     DB 255, 0, 255 DUP(0) 
BUF      DB 20001 DUP(0)       
ARR      DW 10000 DUP(0)        
N        DW 0                  
BITM     DW 0                 
SHOW     DB 0                  
LOADR    DW 0                 
T_LO     DW 0                   
T_MID    DW 0
T_HI     DW 0
T_MIN    DB 0                 
T_CS     DW 0                   
TIME     DW 0                

.CODE
MAIN PROC
        MOV AX, @DATA
        MOV DS, AX
        MOV ES, AX              
        CLD

        LEA DX, MSG_ASK         
        CALL PUTS
        LEA DX, CHOICE
        MOV AH, 0AH
        INT 21H
        CMP CHOICE+2, '2'
        JE  FROMFILE

        LEA DX, MSG_KEY         
        CALL PUTS
        LEA DX, LINE
        MOV AH, 0AH
        INT 21H
        LEA SI, LINE+2          
        MOV CL, LINE+1          
        XOR CH, CH
        INC CX
        JMP SORTIT

FROMFILE:
        LEA DX, FNAME          
        MOV AX, 3D00H
        INT 21H
        JNC OPENED            
        JMP NOFILE
OPENED:
        MOV BX, AX             
        LEA DX, BUF
        MOV CX, 20000
        MOV AH, 3FH             
        INT 21H
        PUSH AX
        MOV AH, 3EH            
        INT 21H
        POP CX                  
        MOV BX, CX
        MOV BUF[BX], ' '        
        INC CX
        LEA SI, BUF

SORTIT:
        CALL CRLF
        CALL GETNUMS            
        LEA DX, MSG_UNS         
        CALL PUTS
        CALL PRALL
        LEA SI, ARR             
        LEA DI, BUF
        MOV CX, N
        REP MOVSW
        MOV SHOW, 0             
        CALL GETTIME            
        MOV T_MIN, CL
        MOV T_CS, AX
        CALL SORTARR
        CALL GETTIME           
        SUB AX, T_CS            
        SUB CL, T_MIN           
        JNS TM_POS
        ADD CL, 60              
TM_POS:
        MOV BX, AX
        MOV AL, CL
        XOR AH, AH
        MOV DX, 6000
        MUL DX                  
        ADD AX, BX
        MOV TIME, AX
        LEA DX, MSG_RES         
        CALL PUTS
        CALL PRALL
        LEA DX, MSG_TIM
        CALL PUTS
        CALL PRTIME
        CMP N, 30               
        JBE STEPS
        LEA DX, MSG_BIG
        CALL PUTS
        JMP QUIT
STEPS:
        LEA DX, MSG_STP         
        CALL PUTS               
        LEA SI, BUF
        LEA DI, ARR
        MOV CX, N
        REP MOVSW
        MOV SHOW, 1
        CALL SORTARR
        JMP QUIT

NOFILE:
        LEA DX, MSG_NOF
        CALL PUTS
QUIT:
        MOV AX, 4C00H           
        INT 21H
MAIN ENDP

SORTARR PROC
        MOV BITM, 8000H
        LEA SI, ARR             
        MOV DI, N
        DEC DI
        SHL DI, 1
        ADD DI, SI              
        CALL MSD
        RET
SORTARR ENDP


GETNUMS PROC
        MOV N, 0
        LEA DI, ARR
        XOR AX, AX              
        XOR BX, BX              
GN_LOOP:
        MOV DL, [SI]
        INC SI
        CMP DL, '0'
        JB  GN_SEP
        CMP DL, '9'
        JA  GN_SEP
        SUB DL, '0'             
        XOR DH, DH
        PUSH DX
        MOV DX, 10
        MUL DX
        POP DX
        ADD AX, DX
        MOV BL, 1
        JMP GN_NEXT
GN_SEP:
        CMP BL, 1               
        JNE GN_SIGN
        CMP BH, 1
        JNE GN_POS
        NEG AX                  
GN_POS:
        XOR AX, 8000H          
        MOV [DI], AX
        ADD DI, 2
        INC N
        XOR AX, AX
        MOV BL, 0
GN_SIGN:
        MOV BH, 0
        CMP DL, '-'             
        JNE GN_NEXT            
        MOV BH, 1
GN_NEXT:
        LOOP GN_LOOP
        RET
GETNUMS ENDP

MSD PROC
MS_TOP:
        CMP DI, SI
        JB  MS_RET             
        CMP BITM, 0
        JE  MS_RET             
        MOV AX, DI
        SUB AX, SI              
        CMP AX, (CUTOFF-1)*2
        JG  MS_SPLIT            
        CALL INSERT             
MS_RET:
        RET
MS_SPLIT:
        PUSH SI                
        PUSH DI
        MOV DX, BITM            
MS_LEFT:                        
        CMP SI, DI
        JA  MS_DONE
        TEST [SI], DX
        JNZ MS_RIGHT
        ADD SI, 2
        JMP MS_LEFT
MS_RIGHT:                       
        CMP SI, DI
        JA  MS_DONE
        TEST [DI], DX
        JZ  MS_SWAP
        SUB DI, 2
        JMP MS_RIGHT
MS_SWAP:                        
        MOV AX, [SI]
        XCHG AX, [DI]
        MOV [SI], AX
        ADD SI, 2
        SUB DI, 2
        JMP MS_LEFT
MS_DONE:                        
        POP DI                  
        POP BX                  
        CMP SI, BX
        JE  MS_SAME             
        CMP SI, DI
        JA  MS_SAME            
        CMP SHOW, 1
        JNE MS_NEXT
        MOV T_LO, BX
        MOV T_MID, SI
        MOV T_HI, DI
        CALL SHOWSPLIT
MS_NEXT:
        SHR BITM, 1             
        MOV AX, BITM
        PUSH AX                 
        PUSH SI
        PUSH DI
        MOV DI, SI              
        SUB DI, 2
        MOV SI, BX
        CALL MSD
        POP DI
        POP SI
        POP AX
        MOV BITM, AX
        JMP MS_TOP              
MS_SAME:
        MOV SI, BX             
        SHR BITM, 1
        JMP MS_TOP
MSD ENDP

INSERT PROC
        CMP DI, SI
        JBE IN_RET             
        MOV LOADR, SI
        MOV BX, SI              
IN_NEXT:
        ADD BX, 2
        CMP BX, DI
        JA  IN_DONE
        MOV AX, [BX]            
        MOV SI, BX              
IN_SHIFT:
        CMP SI, LOADR
        JBE IN_PUT             
        CMP [SI-2], AX
        JBE IN_PUT             
        MOV CX, [SI-2]          
        MOV [SI], CX
        SUB SI, 2
        JMP IN_SHIFT
IN_PUT:
        MOV [SI], AX
        JMP IN_NEXT
IN_DONE:
        CMP SHOW, 1
        JNE IN_RET
        LEA DX, MSG_INS         
        CALL PUTS
        MOV SI, LOADR
        CALL PRRANGE
        CALL CRLF
IN_RET:
        RET
INSERT ENDP
SHOWSPLIT PROC
        LEA DX, MSG_SPL
        CALL PUTS
        MOV AX, BITM            
        XOR CX, CX
SS_BIT:
        SHR AX, 1
        JZ  SS_NUM
        INC CX
        JMP SS_BIT
SS_NUM:
        MOV AX, CX
        CALL PUTDEC
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
        MOV BX, T_LO           
        MOV SI, T_MID
        MOV DI, T_HI
        RET
SHOWSPLIT ENDP

GETTIME PROC
        MOV AH, 2CH            
        INT 21H                
        MOV AL, DH
        MOV AH, 100
        MUL AH                  
        XOR DH, DH
        ADD AX, DX            
        RET
GETTIME ENDP


PRTIME PROC
        MOV AX, TIME
        XOR DX, DX
        MOV BX, 100
        DIV BX                  
        PUSH DX
        CALL PUTDEC             
        MOV DL, '.'
        MOV AH, 2
        INT 21H
        POP AX
        MOV BL, 10
        DIV BL                 
        MOV BX, AX
        MOV DL, BL
        ADD DL, '0'
        MOV AH, 2
        INT 21H
        MOV DL, BH
        ADD DL, '0'
        MOV AH, 2
        INT 21H
        LEA DX, MSG_SEC
        CALL PUTS
        RET
PRTIME ENDP

PRALL PROC
        LEA SI, ARR
        MOV DI, N
        DEC DI
        SHL DI, 1
        ADD DI, SI
        CALL PRRANGE
        CALL CRLF
        RET
PRALL ENDP

PRRANGE PROC
        PUSH SI
PR_LOOP:
        CMP SI, DI
        JA  PR_EXIT
        MOV AX, [SI]
        XOR AX, 8000H          
        TEST AX, AX
        JNS PR_POS
        PUSH AX                 
        MOV DL, '-'
        MOV AH, 2
        INT 21H
        POP AX
        NEG AX
PR_POS:
        CALL PUTDEC
        MOV DL, ' '
        MOV AH, 2
        INT 21H
        ADD SI, 2
        JMP PR_LOOP
PR_EXIT:
        POP SI
        RET
PRRANGE ENDP

PUTDEC PROC
        MOV BX, 10
        XOR CX, CX
PD_DIV:
        XOR DX, DX
        DIV BX
        PUSH DX                 
        INC CX
        TEST AX, AX
        JNZ PD_DIV
PD_OUT:
        POP DX
        ADD DL, '0'
        MOV AH, 2
        INT 21H
        LOOP PD_OUT
        RET
PUTDEC ENDP
PUTS PROC
        MOV AH, 9
        INT 21H
        RET
PUTS ENDP

CRLF PROC
        LEA DX, NEWL
        MOV AH, 9
        INT 21H
        RET
CRLF ENDP
END MAIN