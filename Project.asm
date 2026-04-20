.model small
.stack 100h
.data
    ;Player 1 message
    msg1 db "Choose 4 Colors to Start the Game: $"
    msg2 db "[Y] Yellow [R] Red [G] Green [B] Blue [W] White  [V] Violet$"
    msg3 db "Invalid input must be Capital/4 Inputs$"
        playerOneInput label byte
            P1Len db 5
            P1Actual db ?
            P1Store db 5 dup("$")
    newLine db 13,10,("$")
.code

    mov ax, @data
    mov ds, ax
player_Input:
    mov ah, 09h 
    lea dx, msg1
    int 21h

    lea dx, newLine
    int 21h

    lea dx, msg2
    int 21h

    lea dx, newLine
    int 21h

    mov ah, 0ah
    lea dx, playerOneInput
    int 21h

    mov ah, 09h 
    lea dx, newLine
    int 21h

    ;check input lenght
    cmp P1Actual, 4
    jne invalid_Error_P1

    ;Start Loop Prep
    xor cx, cx
    mov cl, P1Actual
    lea si, P1Store

value_check:
    mov al, [si]

    cmp al, 'Y'
    je is_Valid

    cmp al, 'R' 
     je is_Valid

    cmp al, 'G'
     je is_Valid

    cmp al, 'B'
     je is_Valid

    cmp al, 'W'
     je is_Valid

    cmp al, 'V'
     je is_Valid

    jmp invalid_Error_P1


is_Valid:
    inc si
    loop value_check

    jmp continue

invalid_Error_P1:
    mov ah, 09h
    lea dx, msg3
    int 21h

    lea dx, newLine
    int 21h

    jmp player_Input

.data
    ;Player 2  
    msg4 db 'Guess the Colors Player 1 Chose: $'
    msgGuess db 13,10,('You Guessed: $')
    chickenDinner db 13,10,('You Win!!$')
    Top100 db 13,10,('Wrong Guess$')
    resetMsg db 13,10,('Press any key to continue.....$')
    attempts_Left db 13,10,('Attempts Left: $')
    msgPlacement db 13,10,("Number of Correct Color Placement: $")
    msgColor db 13,10,("Number of Correct Color: $")

    ;Make a temporary storage for P! inputes
    P1Temp db 5 dup('$')

    player2_Input label byte
        P2Len db 5
        P2Actual db ?
        P2Store db 5 dup("$")

    attempts db 10
    correct_Placement db 0
    correct_Color db 0

.code
continue:
    ;;Clear Scores
    mov correct_Placement, 0
    mov correct_Color, 0

    ;Clear the screen
    mov ah, 06h
    mov al, 00h
    mov bh, 07h
    mov cx, 0000h
    mov dx, 184Fh
    int 10h
    ;move the cursor
    mov ah, 02h
    mov bh, 00h
    mov dx, 0000h
    int 10h

    mov ah, 09h
    lea dx, msg4
    int 21h

    lea dx, newLine
    int 21h

    mov ah, 0ah
    lea dx, player2_Input
    int 21h

    ; After INT 21h / 0Ah for player2_Input
    xor bh, bh
    mov bl, P2Actual        ; get actual length (e.g. 4)
    lea si, P2Store
    add si, bx              ; point to byte after last char
    mov byte ptr [si], '$'  ; overwrite the 0Dh with proper terminator

    mov ah, 09h 
    lea dx, newLine
    int 21h

    ;;check the lenght
    cmp P2Actual, 4
    jne invalid_Error_P2

    xor cx, cx
    mov cx, 4
    lea si, P1Store
    lea di, P2Store
    mov bl, 0

check_Correct_Placement:
    mov al, [si]
    cmp al, [di]
    jne next_p

    inc bl


next_p:
    inc si
    inc di
    loop check_Correct_Placement

    mov correct_Placement, bl

    xor cx, cx
    mov cx, 4
    lea si, P1Store
    lea di, P1Temp

copy_Loop:
    mov al, [si]
    mov [di], al
    inc si 
    inc di
    loop copy_Loop
    ;Nest Loop
    mov cx, 4
    lea di, P2Store
    mov bl, 0

check_Correct_Color_Outer:
    push cx
    mov al, [di] ;;Get the Input of P2

    mov cx, 4
    lea si, P1Temp ;;User Buffer

check_Correct_Color_Inner:
    cmp al, [si]
    je color_Match_Found
    inc si
    loop check_Correct_Color_Inner
    jmp next_Color_Char 

color_Match_Found:
    inc bl
    mov byte ptr [si], 0

next_Color_Char:
    pop cx
    inc di
    loop check_Correct_Color_Outer

mov correct_Color, bl
jmp display_result

invalid_Error_P2:
    mov ah, 09h
    lea dx, msg3
    int 21h

    lea dx, newLine
    int 21h

    jmp continue

display_result:
    ;Clear the screen
    mov ah, 06h
    mov al, 00h
    mov bh, 07h
    mov cx, 0000h
    mov dx, 184Fh
    int 10h
    ;move the cursor
    mov ah, 02h
    mov bh, 00h
    mov dx, 0000h
    int 10h

      ; Display "You Guessed: "
    mov ah, 09h
    lea dx, msgGuess
    int 21h

    ; Print the actual characters guessed (P2Store)
    lea dx, P2Store  
    int 21h

    ; Print the "Correct Color" label and number
    mov ah, 09h       
    lea dx, msgColor
    int 21h
    mov dl, correct_Color
    add dl, 48         ; Convert number to ASCII
    mov ah, 02h        ; Function to print a single character
    int 21h

    ; Print the "Placement" label and number
    mov ah, 09h       
    lea dx, msgPlacement
    int 21h
    mov dl, correct_Placement
    add dl, 48
    mov ah, 02h
    int 21h

    cmp correct_Placement, 4
    je player2_Wins
    jmp wrong_Guess

player2_Wins:
    mov ah, 09h
    lea dx, chickenDinner
    int 21h

    jmp endMain

wrong_Guess:
    mov ah, 09h
    lea dx, Top100
    int 21h

    dec attempts
    ;End game after 10 tries
    cmp attempts, 0
    je reaatempt

    ;Number of Attempts Left
    mov ah, 09h
    lea dx, attempts_Left
    int 21h
    ;Convert Tries to Actual Number
    mov dl, attempts
    add dl, 48
    mov ah, 02h
    int 21h
    ;simple instructions
    mov ah, 09h
    lea dx, resetMsg
    int 21h

    ;Pause so that user can view results
    mov ah, 01h
    int 21h

    jmp continue

reaatempt:
    jmp continue
endMain:
    mov ah, 4ch
    int 21h

end