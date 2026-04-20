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
    msg5 13,10,("Number of Correct Color Placement: $")
    msg6 13,10,("Number of Correct Color: $")

    player2_Input label byte
        P2Len db 5
        P2Actual db ?
        P2Store db 5 dup("$")

    attempts db 10
    correct_Placement db 0
    correct_Color db 0

.code
continue:
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

    xor cx,cx
    mov cx, 4
    lea di, P2Store
    mov bl, 0

check_Correct_Color_Outer:
    push cx
    mov al, [di]

    mov cx, 4
    lea si, P1Store

    check_Correct_Color_Inner:
        cmp al, [si]
        je color_Found
        inc si
        loop check_Correct_Color_Inner
        jmp color_NotFound

color_NotFound:
    pop cx
    inc di
    loop check_Correct_Color_Outer        

color_Found:
    inc correct_Color
    pop cx
    inc di
    loop check_Correct_Color_Outer

mov bl, correct_Color
jmp display_result

invalid_Error_P2:
    mov ah, 09h
    lea dx, msg3
    int 21h

    lea dx, newLine
    int 21h

    jmp continue


display_result:


endMain:
    mov ah, 4ch
    int 21h

end