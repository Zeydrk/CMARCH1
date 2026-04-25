.model small
.stack 100h

.data
    ; ── Screen clear / cursor helpers ─────────────────────────────────────
    newLine     db 13,10,"$"

    ; ── Player 1 ──────────────────────────────────────────────────────────
    msg_p1_title  db "=== MASTERMIND: SET YOUR SECRET CODE ===",13,10,"$"
    msg_p1_prompt db "Choose 4 Colors (e.g. RYGB): $"
    msg_p1_legend db "[Y]ellow  [R]ed  [G]reen  [B]lue  [W]hite  [V]iolet",13,10,"$"
    msg_invalid   db "  ! Invalid: use only Y R G B W V, exactly 4 chars.",13,10,"$"
    msg_handoff   db "  >> Secret locked. Pass the device to Player 2. <<",13,10,"$"
    msg_anykey    db "  Press any key to continue...$"

    playerOneInput label byte
        P1Len   db 6        ; buffer size (4 chars + CR + safety)
        P1Actual db ?
        P1Store  db 6 dup("$")

    ; ── Player 2 ──────────────────────────────────────────────────────────
    msg_p2_title    db "=== MASTERMIND: CRACK THE CODE ===",13,10,"$"
    msg_p2_prompt   db "Your guess (4 colors): $"
    msg_p2_legend   db "[Y]ellow  [R]ed  [G]reen  [B]lue  [W]hite  [V]iolet",13,10,"$"
    msg_you_guessed db "  You guessed : $"
    msg_placement   db "  Correct position : $"
    msg_color       db "  Correct color    : $"
    msg_win         db 13,10,"*** YOU WIN! Congratulations! ***",13,10,"$"
    msg_lose        db 13,10,"*** GAME OVER! You ran out of attempts! ***",13,10,"$"
    msg_wrong       db 13,10,"  Wrong! Keep trying.",13,10,"$"
    msg_attempts    db "  Attempts left: $"

    player2Input label byte
        P2Len   db 6
        P2Actual db ?
        P2Store  db 6 dup("$")

    ; ── Scratch / counters ────────────────────────────────────────────────
    P1Temp          db 6 dup(0)   ; copy of P1Store used in color check
    attempts        db 10
    correct_Placement db 0
    correct_Color     db 0

.code

; ══════════════════════════════════════════════════════════════════════════
;  MACRO: clear screen and home cursor (INT 10h)
; ══════════════════════════════════════════════════════════════════════════
cls macro
    mov ah, 06h
    mov al, 00h
    mov bh, 07h
    xor cx, cx
    mov dx, 184Fh
    int 10h
    mov ah, 02h
    mov bh, 00h
    xor dx, dx
    int 10h
endm

; ══════════════════════════════════════════════════════════════════════════
;  MACRO: print $ string at DS:DX
; ══════════════════════════════════════════════════════════════════════════
print macro msg_label
    mov ah, 09h
    lea dx, msg_label
    int 21h
endm

; ══════════════════════════════════════════════════════════════════════════
;  Entry point
; ══════════════════════════════════════════════════════════════════════════
    mov ax, @data
    mov ds, ax

; ──────────────────────────────────────────────────────────────────────────
;  PHASE 1 – Player 1 enters secret code
; ──────────────────────────────────────────────────────────────────────────
player1_input:
    cls

    print msg_p1_title
    print newLine
    print msg_p1_legend
    print newLine
    print msg_p1_prompt

    mov ah, 0Ah
    lea dx, playerOneInput
    int 21h

    print newLine

    ; ── Fix CR terminator left by INT 21h/0Ah ────────────────────────────
    xor bh, bh
    mov bl, P1Actual
    lea si, P1Store
    add si, bx
    mov byte ptr [si], '$'

    ; ── Validate length ───────────────────────────────────────────────────
    cmp P1Actual, 4
    jne p1_invalid

    ; ── Validate each character ───────────────────────────────────────────
    xor cx, cx
    mov cl, 4
    lea si, P1Store

p1_val_loop:
    mov al, [si]
    call is_valid_color     ; sets ZF if valid
    jnz p1_invalid
    inc si
    loop p1_val_loop
    jmp p1_done

p1_invalid:
    print msg_invalid
    print newLine
    jmp player1_input

p1_done:
    ; ── Handoff screen ────────────────────────────────────────────────────
    cls
    print msg_handoff
    print newLine
    print msg_anykey

    mov ah, 00h
    int 16h                 ; wait for keypress (no echo)

; ──────────────────────────────────────────────────────────────────────────
;  PHASE 2 – Player 2 guesses
; ──────────────────────────────────────────────────────────────────────────
player2_turn:
    ; Reset per-turn scores
    mov correct_Placement, 0
    mov correct_Color, 0

    cls

    print msg_p2_title
    print newLine
    print msg_p2_legend
    print newLine

    ; ── Show attempts remaining ───────────────────────────────────────────
    print msg_attempts
    mov dl, attempts
    add dl, '0'
    mov ah, 02h
    int 21h
    print newLine
    print newLine

    ; ── Get guess ─────────────────────────────────────────────────────────
    print msg_p2_prompt
    mov ah, 0Ah
    lea dx, player2Input
    int 21h
    print newLine

    ; Fix CR terminator
    xor bh, bh
    mov bl, P2Actual
    lea si, P2Store
    add si, bx
    mov byte ptr [si], '$'

    ; Validate length
    cmp P2Actual, 4
    jne p2_invalid

    ; Validate each character
    xor cx, cx
    mov cl, 4
    lea si, P2Store

p2_val_loop:
    mov al, [si]
    call is_valid_color
    jnz p2_invalid
    inc si
    loop p2_val_loop
    jmp check_placement

p2_invalid:
    print msg_invalid
    print newLine
    jmp player2_turn        ; re-prompt, don't consume an attempt

; ──────────────────────────────────────────────────────────────────────────
;  CHECK PLACEMENT  (exact position matches)
; ──────────────────────────────────────────────────────────────────────────
check_placement:
    mov cx, 4
    lea si, P1Store
    lea di, P2Store
    mov bl, 0

cp_loop:
    mov al, [si]
    cmp al, [di]
    jne cp_next
    inc bl
cp_next:
    inc si
    inc di
    loop cp_loop
    mov correct_Placement, bl

; ──────────────────────────────────────────────────────────────────────────
;  CHECK COLOR  (exists anywhere, deduplicated via temp copy)
; ──────────────────────────────────────────────────────────────────────────
    ; Copy P1Store → P1Temp
    mov cx, 4
    lea si, P1Store
    lea di, P1Temp
copy_loop:
    mov al, [si]
    mov [di], al
    inc si
    inc di
    loop copy_loop

    mov cx, 4
    lea di, P2Store
    mov bl, 0

cc_outer:
    push cx
    mov al, [di]            ; current guess char

    mov cx, 4
    lea si, P1Temp

cc_inner:
    cmp al, [si]
    je  cc_found
    inc si
    loop cc_inner
    jmp cc_next_outer

cc_found:
    inc bl
    mov byte ptr [si], 0    ; mark used so duplicates don't double-count

cc_next_outer:
    pop cx
    inc di
    loop cc_outer
    mov correct_Color, bl

; ──────────────────────────────────────────────────────────────────────────
;  DISPLAY RESULT
; ──────────────────────────────────────────────────────────────────────────
display_result:
    cls

    ; "You guessed: XXXX"
    print msg_you_guessed
    mov ah, 09h
    lea dx, P2Store
    int 21h
    print newLine

    ; "Correct position: N"
    print msg_placement
    mov dl, correct_Placement
    add dl, '0'
    mov ah, 02h
    int 21h
    print newLine

    ; "Correct color: N"
    print msg_color
    mov dl, correct_Color
    add dl, '0'
    mov ah, 02h
    int 21h
    print newLine

    ; ── Win check ─────────────────────────────────────────────────────────
    cmp correct_Placement, 4
    je  player2_wins

    ; ── Consume attempt ───────────────────────────────────────────────────
    dec attempts
    cmp attempts, 0
    je  game_over

    print msg_wrong
    print msg_anykey
    mov ah, 00h
    int 16h
    jmp player2_turn

player2_wins:
    print msg_win
    jmp endMain

game_over:
    print msg_lose
    jmp endMain

; ──────────────────────────────────────────────────────────────────────────
;  SUBROUTINE: is_valid_color
;    Input : AL = character to test
;    Output: ZF set (jz = valid), ZF clear (jnz = invalid)
; ──────────────────────────────────────────────────────────────────────────
is_valid_color proc near
    cmp al, 'Y'
    je  ivc_ok
    cmp al, 'R'
    je  ivc_ok
    cmp al, 'G'
    je  ivc_ok
    cmp al, 'B'
    je  ivc_ok
    cmp al, 'W'
    je  ivc_ok
    cmp al, 'V'
    je  ivc_ok
    ; Invalid – set flags so jnz fires
    or  al, al              ; clears ZF (AL cannot be 0 here)
    ret
ivc_ok:
    ; Valid – set ZF
    xor al, al              ; sets ZF
    ret
is_valid_color endp

; ──────────────────────────────────────────────────────────────────────────
endMain:
    print msg_anykey
    mov ah, 00h
    int 16h

    mov ah, 4Ch
    int 21h

end