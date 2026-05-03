; ============================================================================
;  MASTERMIND  -  Two-Player Code-Breaker  (TASM / DOSBox)
; ============================================================================
.model small
.stack 200h

.data

colorFgAttrs db 0Eh, 0Ch, 0Ah, 09h, 0Fh, 0Dh
colorBgAttrs db 6Eh, 4Ch, 2Ah, 19h, 7Fh, 5Dh

CODE_LEN    equ 4
MAX_GUESSES equ 10

p1Code   db CODE_LEN    dup(0FFh)
p2Code   db CODE_LEN    dup(0FFh)
p2Hist   db 40          dup(0FFh)
p2HPos   db MAX_GUESSES dup(0)
p2HCol   db MAX_GUESSES dup(0)
P1Temp   db CODE_LEN    dup(0FFh)
attempts db MAX_GUESSES
guessCnt db 0
selColor db 0FFh
corPos   db 0
corCol   db 0
curPhase db 0

ROW_TITLE   equ 1
ROW_SEP1    equ 2
ROW_ATT     equ 3
ROW_PICK    equ 4
ROW_PICK2   equ 5
ROW_PICK3   equ 6
ROW_PICK4   equ 7
ROW_SELN    equ 8
ROW_SEP2    equ 9
ROW_SLBL    equ 10
ROW_SLOTS   equ 11
ROW_ERR     equ 12
ROW_RESULT  equ 13
ROW_SEP3    equ 14
ROW_HISTHDR equ 15
ROW_HIST0   equ 16
; Rows 16-22 = 7 history entries max (rows 23-24 = legend)
MAX_HIST_DISP equ 7
ROW_LEGEND  equ 24

PEG_Q  equ 15
PEG_W  equ 31
PEG_E  equ 47
PEG_R  equ 63

; FIX: non-overlapping header columns. "Pos" at 67, digit at 71, "Col" at 73, digit at 77.
HCOL_POS_LBL equ 67
HCOL_POS_DIG equ 71
HCOL_COL_LBL equ 73
HCOL_COL_DIG equ 77

ATTR_PANEL equ 0Eh
ATTR_BDR   equ 0Fh
ATTR_TITL  equ 0Fh
ATTR_LBL   equ 0Eh
ATTR_HINT  equ 07h
ATTR_SEL   equ 70h
ATTR_POS   equ 0Ah
ATTR_COL   equ 0Bh
ATTR_EMPTY equ 08h
ATTR_WIN   equ 0Ah
ATTR_LOSE  equ 0Ch
ATTR_ERR   equ 0Ch

BOX_TL equ 0C9h
BOX_TR equ 0BBh
BOX_BL equ 0C8h
BOX_BR equ 0BCh
BOX_H  equ 0CDh
BOX_V  equ 0BAh
BOX_LT equ 0CCh
BOX_RT equ 0B9h
BLOCK  equ 0DBh
SHADE  equ 0B0h
DOT    equ 0FEh

s_p1_title  db '  MASTERMIND  //  P1: Set Your Secret Code',0
s_p2_title  db '  MASTERMIND  //  P2: Crack the Code',0
s_ho_title  db '  MASTERMIND  //  Code Locked!',0
s_win_title db '  MASTERMIND  //  YOU WIN!',0
s_los_title db '  MASTERMIND  //  GAME OVER',0

s_att_lbl   db 'Tries left: ',0

s_slbl_hdr  db 'Slots:',0

s_sel_pre   db 'Selected: ',0
s_sel_none  db '< press 1-6 to choose a color >',0

; FIX: s_res_pre is 25 chars. Pos digit must be written at col 1+25=26 explicitly.
s_res_pre   db '  Last result:  Position=',0   ; 25 chars
s_res_col   db '   Color=',0                    ; 9 chars

s_hdr_num   db '#',0
s_hdr_q     db '[Q]',0
s_hdr_w     db '[W]',0
s_hdr_e     db '[E]',0
s_hdr_r     db '[R]',0
; FIX: abbreviated header labels so they don't overlap at cols 67/73
s_hdr_pos   db 'Pos',0
s_hdr_col   db 'Col',0

s_p1_efill  db '  ! Fill all 4 slots then press ENTER.',0
s_p2_efill  db '  ! Fill all 4 slots then press ENTER.',0

s_p1_leg1   db '  1-6: pick color',0
s_p1_leg2   db '  Q/W/E/R: place into slot',0
s_p1_leg3   db '  ENTER: confirm code',0
s_p1_leg4   db '  ESC: clear all   F10: quit',0

s_p2_leg1   db '  1-6: pick color',0
s_p2_leg2   db '  Q/W/E/R: place into slot',0
s_p2_leg3   db '  ENTER: submit guess',0
s_p2_leg4   db '  ESC: clear guess   F10: quit',0

s_ho_msg1   db '  *** SECRET CODE IS LOCKED ***',0
s_ho_msg2   db '  Hand the device to Player 2.',0
s_ho_codelb db '  The locked code:',0
s_ho_hint   db '  Player 1 look away -- press any key when Player 2 is ready...',0

s_win_msg   db '  Congratulations!  The secret code was:',0
s_win_hint  db '  Press any key to play again...',0
s_los_msg   db '  Out of attempts!  The secret code was:',0
s_los_hint  db '  Press any key to play again...',0

s_win1 db '    \  /   / _ \  | | | |',0
s_win2 db '     \/   | | | | | | | |',0
s_win3 db '     /\   | |_| | | |_| |',0
s_win4 db '    /  \   \___/   \___/ ',0

s_los1 db '  GAME  OVER',0
s_los2 db '  ---- ----',0

.code

; ============================================================================
;  PRIMITIVES
; ============================================================================

write_char_at proc near
    push ax
    push bx
    push cx
    push dx
    mov  ah, 02h
    mov  bh, 00h
    int  10h
    mov  ah, 09h
    mov  bh, 00h
    mov  cx, 1
    int  10h
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret
write_char_at endp

write_hline proc near
    push cx
    push dx
whl_lp:
    call write_char_at
    inc  dl
    loop whl_lp
    pop  dx
    pop  cx
    ret
write_hline endp

; write_str — does NOT restore DX; DL advances past the string on return.
write_str proc near
    push ax
    push bx
    push si
ws_lp:
    mov  al, [si]
    or   al, al
    jz   ws_done
    call write_char_at
    inc  dl
    inc  si
    jmp  ws_lp
ws_done:
    pop  si
    pop  bx
    pop  ax
    ret
write_str endp

blank_row proc near
    push ax
    push bx
    push cx
    push dx
    mov  dl, 1
    mov  al, ' '
    mov  bl, ATTR_PANEL
    mov  cx, 78
    call write_hline
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret
blank_row endp

cls proc near
    push ax
    push bx
    push cx
    push dx
    mov  ah, 06h
    mov  al, 00h
    mov  bh, ATTR_PANEL
    xor  cx, cx
    mov  dx, 184Fh
    int  10h
    mov  ah, 02h
    mov  bh, 00h
    xor  dx, dx
    int  10h
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret
cls endp

wait_key proc near
    mov  ah, 00h
    int  16h
    ret
wait_key endp

; ============================================================================
;  BORDER & SEPARATORS
; ============================================================================

draw_border proc near
    push ax
    push bx
    push cx
    push dx
    mov  dh, 0
    mov  dl, 0
    mov  al, BOX_TL
    mov  bl, ATTR_BDR
    call write_char_at
    mov  dl, 1
    mov  al, BOX_H
    mov  cx, 78
    call write_hline
    mov  dl, 79
    mov  al, BOX_TR
    call write_char_at
    mov  dh, 1
    mov  cx, 23
dbr_lp:
    push cx
    mov  dl, 0
    mov  al, BOX_V
    call write_char_at
    mov  dl, 79
    call write_char_at
    pop  cx
    inc  dh
    loop dbr_lp
    mov  dh, 24
    mov  dl, 0
    mov  al, BOX_BL
    call write_char_at
    mov  dl, 1
    mov  al, BOX_H
    mov  cx, 78
    call write_hline
    mov  dl, 79
    mov  al, BOX_BR
    call write_char_at
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret
draw_border endp

draw_sep proc near
    push ax
    push bx
    push cx
    push dx
    mov  dl, 0
    mov  al, BOX_LT
    mov  bl, ATTR_BDR
    call write_char_at
    mov  dl, 1
    mov  al, BOX_H
    mov  cx, 78
    call write_hline
    mov  dl, 79
    mov  al, BOX_RT
    call write_char_at
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret
draw_sep endp

; ============================================================================
;  PEG DRAWING
; ============================================================================

draw_peg proc near
    push ax
    push bx
    push dx
    push si
    cmp  al, 0FFh
    jne  dpg_fill
    mov  al, '['
    mov  bl, ATTR_EMPTY
    call write_char_at
    inc  dl
    mov  al, '?'
    call write_char_at
    inc  dl
    mov  al, ']'
    call write_char_at
    jmp  dpg_ret
dpg_fill:
    xor  ah, ah
    lea  si, colorBgAttrs
    add  si, ax
    mov  bl, [si]
    mov  al, BLOCK
    call write_char_at
    inc  dl
    call write_char_at
    inc  dl
    call write_char_at
dpg_ret:
    pop  si
    pop  dx
    pop  bx
    pop  ax
    ret
draw_peg endp

draw_code_row proc near
    push ax
    push dx
    mov  al, byte ptr [si+0]
    mov  dl, PEG_Q
    call draw_peg
    mov  al, byte ptr [si+1]
    mov  dl, PEG_W
    call draw_peg
    mov  al, byte ptr [si+2]
    mov  dl, PEG_E
    call draw_peg
    mov  al, byte ptr [si+3]
    mov  dl, PEG_R
    call draw_peg
    pop  dx
    pop  ax
    ret
draw_code_row endp

; ============================================================================
;  COLOR PICKER  -  4 rows tall, 6 cols wide
;  Row 1: [NL  ]  Row 2-4: [████]  stride=8, base col=16
; ============================================================================
draw_color_picker proc near
    push ax
    push bx
    push cx
    push dx
    push si

    mov  dh, ROW_PICK
    call blank_row
    mov  dh, ROW_PICK2
    call blank_row
    mov  dh, ROW_PICK3
    call blank_row
    mov  dh, ROW_PICK4
    call blank_row

    xor  cx, cx

dcp_lp:
    cmp  cl, 6
    jb   dcp_body
    jmp  dcp_done
dcp_body:
    ; base col = 16 + cl*8
    push cx
    xor  ah, ah
    mov  al, cl
    mov  bl, 8
    mul  bl
    add  al, 16
    mov  dl, al
    pop  cx

    ; bracket attr
    mov  al, cl
    cmp  byte ptr selColor, 0FFh
    je   dcp_dim
    cmp  al, byte ptr selColor
    je   dcp_sel
dcp_dim:
    mov  bl, ATTR_HINT
    jmp  dcp_battr
dcp_sel:
    mov  bl, ATTR_SEL
dcp_battr:

    ; ROW 1: [NL  ]
    push bx
    mov  dh, ROW_PICK
    mov  al, '['
    call write_char_at
    inc  dl
    push bx
    mov  al, cl
    add  al, '1'
    mov  bl, ATTR_LBL
    call write_char_at
    pop  bx
    inc  dl
    push bx
    push cx
    push dx
    xor  ah, ah
    mov  al, cl
    lea  si, colorFgAttrs
    add  si, ax
    mov  bl, [si]
    mov  al, cl
    cmp  al, 0
    jne  dlt_r
    mov  al, 'Y'
    jmp  dlt_draw
dlt_r:
    cmp  al, 1
    jne  dlt_g
    mov  al, 'R'
    jmp  dlt_draw
dlt_g:
    cmp  al, 2
    jne  dlt_b
    mov  al, 'G'
    jmp  dlt_draw
dlt_b:
    cmp  al, 3
    jne  dlt_w
    mov  al, 'B'
    jmp  dlt_draw
dlt_w:
    cmp  al, 4
    jne  dlt_v
    mov  al, 'W'
    jmp  dlt_draw
dlt_v:
    mov  al, 'V'
dlt_draw:
    call write_char_at
    pop  dx
    pop  cx
    pop  bx
    inc  dl
    push bx
    mov  bl, ATTR_PANEL
    mov  al, ' '
    call write_char_at
    inc  dl
    call write_char_at
    inc  dl
    pop  bx
    pop  bx
    mov  al, ']'
    call write_char_at

    ; Rows 2-4: [████]  -- helper: compute col into dl, draw blocks
    ; Use a macro-style repeat for rows 2, 3, 4
    push cx
    xor  ah, ah
    mov  al, cl
    mov  bl, 8
    mul  bl
    add  al, 16
    mov  dl, al
    pop  cx
    mov  al, cl
    cmp  byte ptr selColor, 0FFh
    je   r2_dim
    cmp  al, byte ptr selColor
    je   r2_sel
r2_dim: mov  bl, ATTR_HINT
    jmp  r2_go
r2_sel: mov  bl, ATTR_SEL
r2_go:
    push bx
    mov  dh, ROW_PICK2
    mov  al, '['
    call write_char_at
    inc  dl
    push cx
    push dx
    xor  ah, ah
    mov  al, cl
    lea  si, colorBgAttrs
    add  si, ax
    mov  bl, [si]
    pop  dx
    mov  al, BLOCK
    mov  cx, 4
r2_blk: call write_char_at
    inc  dl
    loop r2_blk
    pop  cx
    pop  bx
    mov  al, ']'
    call write_char_at

    push cx
    xor  ah, ah
    mov  al, cl
    mov  bl, 8
    mul  bl
    add  al, 16
    mov  dl, al
    pop  cx
    mov  al, cl
    cmp  byte ptr selColor, 0FFh
    je   r3_dim
    cmp  al, byte ptr selColor
    je   r3_sel
r3_dim: mov  bl, ATTR_HINT
    jmp  r3_go
r3_sel: mov  bl, ATTR_SEL
r3_go:
    push bx
    mov  dh, ROW_PICK3
    mov  al, '['
    call write_char_at
    inc  dl
    push cx
    push dx
    xor  ah, ah
    mov  al, cl
    lea  si, colorBgAttrs
    add  si, ax
    mov  bl, [si]
    pop  dx
    mov  al, BLOCK
    mov  cx, 4
r3_blk: call write_char_at
    inc  dl
    loop r3_blk
    pop  cx
    pop  bx
    mov  al, ']'
    call write_char_at

    push cx
    xor  ah, ah
    mov  al, cl
    mov  bl, 8
    mul  bl
    add  al, 16
    mov  dl, al
    pop  cx
    mov  al, cl
    cmp  byte ptr selColor, 0FFh
    je   r4_dim
    cmp  al, byte ptr selColor
    je   r4_sel
r4_dim: mov  bl, ATTR_HINT
    jmp  r4_go
r4_sel: mov  bl, ATTR_SEL
r4_go:
    push bx
    mov  dh, ROW_PICK4
    mov  al, '['
    call write_char_at
    inc  dl
    push cx
    push dx
    xor  ah, ah
    mov  al, cl
    lea  si, colorBgAttrs
    add  si, ax
    mov  bl, [si]
    pop  dx
    mov  al, BLOCK
    mov  cx, 4
r4_blk: call write_char_at
    inc  dl
    loop r4_blk
    pop  cx
    pop  bx
    mov  al, ']'
    call write_char_at

    inc  cl
    jmp  dcp_lp

dcp_done:
    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret
draw_color_picker endp

; ============================================================================
;  SELECTED COLOR NAME
; ============================================================================
draw_sel_name proc near
    push ax
    push bx
    push cx
    push dx
    push si

    mov  dh, ROW_SELN
    call blank_row

    cmp  byte ptr selColor, 0FFh
    jne  dsn_has

    mov  dh, ROW_SELN
    mov  dl, 16
    lea  si, s_sel_none
    mov  bl, ATTR_HINT
    call write_str
    jmp  dsn_done

dsn_has:
    mov  dh, ROW_SELN
    mov  dl, 16
    lea  si, s_sel_pre
    mov  bl, ATTR_LBL
    call write_str
    ; DL now points right after "Selected: " (write_str advances DL)

    push dx
    xor  ah, ah
    mov  al, byte ptr selColor
    lea  si, colorFgAttrs
    add  si, ax
    mov  bl, [si]

    mov  al, byte ptr selColor
    cmp  al, 0
    jne  dsn_r
    mov  al, 'Y'
    jmp  dsn_wletter
dsn_r:
    cmp  al, 1
    jne  dsn_g
    mov  al, 'R'
    jmp  dsn_wletter
dsn_g:
    cmp  al, 2
    jne  dsn_b
    mov  al, 'G'
    jmp  dsn_wletter
dsn_b:
    cmp  al, 3
    jne  dsn_w
    mov  al, 'B'
    jmp  dsn_wletter
dsn_w:
    cmp  al, 4
    jne  dsn_v
    mov  al, 'W'
    jmp  dsn_wletter
dsn_v:
    mov  al, 'V'
dsn_wletter:
    pop  dx
    call write_char_at
    inc  dl

    mov  al, ' '
    mov  bl, ATTR_PANEL
    call write_char_at
    inc  dl

    push dx
    xor  ah, ah
    mov  al, byte ptr selColor
    lea  si, colorBgAttrs
    add  si, ax
    mov  bl, [si]
    pop  dx
    mov  al, BLOCK
    call write_char_at
    inc  dl
    call write_char_at
    inc  dl
    call write_char_at

dsn_done:
    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret
draw_sel_name endp

; ============================================================================
;  ATTEMPTS BAR
; ============================================================================
draw_att_bar proc near
    push ax
    push bx
    push cx
    push dx
    push si

    mov  dh, ROW_ATT
    call blank_row

    mov  dh, ROW_ATT
    mov  dl, 16
    lea  si, s_att_lbl
    mov  bl, ATTR_LBL
    call write_str

    xor  cx, cx
dab_lp:
    cmp  cl, MAX_GUESSES
    jae  dab_done
    push cx
    xor  ah, ah
    mov  al, cl
    shl  al, 1
    add  al, 29
    mov  dl, al
    mov  dh, ROW_ATT

    mov  al, byte ptr attempts
    cmp  cl, al
    jb   dab_rem
    mov  al, SHADE
    mov  bl, ATTR_HINT
    call write_char_at
    jmp  dab_next
dab_rem:
    mov  al, DOT
    mov  bl, ATTR_POS
    call write_char_at
dab_next:
    pop  cx
    inc  cl
    jmp  dab_lp
dab_done:
    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret
draw_att_bar endp

; ============================================================================
;  SLOT LABELS
; ============================================================================
draw_slot_labels proc near
    push ax
    push bx
    push dx
    push si

    mov  dh, ROW_SLBL
    call blank_row

    mov  dh, ROW_SLBL
    mov  dl, 1
    lea  si, s_slbl_hdr
    mov  bl, ATTR_LBL
    call write_str

    mov  dh, ROW_SLBL
    mov  dl, PEG_Q
    mov  al, '['
    mov  bl, ATTR_HINT
    call write_char_at
    inc  dl
    mov  al, 'Q'
    mov  bl, ATTR_LBL
    call write_char_at
    inc  dl
    mov  al, ']'
    mov  bl, ATTR_HINT
    call write_char_at

    mov  dl, PEG_W
    mov  al, '['
    call write_char_at
    inc  dl
    mov  al, 'W'
    mov  bl, ATTR_LBL
    call write_char_at
    inc  dl
    mov  al, ']'
    mov  bl, ATTR_HINT
    call write_char_at

    mov  dl, PEG_E
    mov  al, '['
    call write_char_at
    inc  dl
    mov  al, 'E'
    mov  bl, ATTR_LBL
    call write_char_at
    inc  dl
    mov  al, ']'
    mov  bl, ATTR_HINT
    call write_char_at

    mov  dl, PEG_R
    mov  al, '['
    call write_char_at
    inc  dl
    mov  al, 'R'
    mov  bl, ATTR_LBL
    call write_char_at
    inc  dl
    mov  al, ']'
    mov  bl, ATTR_HINT
    call write_char_at

    pop  si
    pop  dx
    pop  bx
    pop  ax
    ret
draw_slot_labels endp

; ============================================================================
;  ERROR LINE
; ============================================================================
draw_err_line proc near
    push ax
    push bx
    push dx
    mov  dh, ROW_ERR
    call blank_row
    mov  dh, ROW_ERR
    mov  dl, 1
    mov  bl, ATTR_ERR
    call write_str
    pop  dx
    pop  bx
    pop  ax
    ret
draw_err_line endp

clear_err_line proc near
    push ax
    push bx
    push dx
    mov  dh, ROW_ERR
    call blank_row
    pop  dx
    pop  bx
    pop  ax
    ret
clear_err_line endp

; ============================================================================
;  LAST RESULT
;  FIX: write_str advances DL, so after s_res_pre DL is already past the label.
;       Set DL explicitly based on known string lengths to be safe.
; ============================================================================
draw_last_result proc near
    push ax
    push bx
    push dx
    push si

    cmp  byte ptr guessCnt, 0
    je   dlr_done

    mov  dh, ROW_RESULT
    call blank_row

    ; "  Last result:  Position=" = 25 chars starting at col 1
    mov  dh, ROW_RESULT
    mov  dl, 1
    lea  si, s_res_pre
    mov  bl, ATTR_HINT
    call write_str
    ; write_str advances DL, so DL is now at col 26 (1+25)

    mov  al, byte ptr corPos
    add  al, '0'
    mov  bl, ATTR_POS
    call write_char_at
    inc  dl

    ; "   Color=" = 9 chars — write_str will advance DL past them
    lea  si, s_res_col
    mov  bl, ATTR_HINT
    call write_str
    ; DL now at col 26+1+9 = 36

    mov  al, byte ptr corCol
    add  al, '0'
    mov  bl, ATTR_COL
    call write_char_at

dlr_done:
    pop  si
    pop  dx
    pop  bx
    pop  ax
    ret
draw_last_result endp

; ============================================================================
;  HISTORY
;  FIX 1: cap display at MAX_HIST_DISP (7) rows — show most recent guesses.
;  FIX 2: header labels "Pos"/"Col" at non-overlapping columns 67 and 73.
;  FIX 3: index into p2HPos/p2HCol uses byte offset from cl directly —
;         no mul needed since arrays are 1 byte per entry.
; ============================================================================
draw_history proc near
    push ax
    push bx
    push cx
    push dx
    push si

    ; Header row
    mov  dh, ROW_HISTHDR
    call blank_row
    mov  dh, ROW_HISTHDR
    mov  dl, 2
    mov  al, '#'
    mov  bl, ATTR_HINT
    call write_char_at

    mov  dh, ROW_HISTHDR
    mov  dl, PEG_Q
    lea  si, s_hdr_q
    mov  bl, ATTR_LBL
    call write_str

    mov  dh, ROW_HISTHDR
    mov  dl, PEG_W
    lea  si, s_hdr_w
    call write_str

    mov  dh, ROW_HISTHDR
    mov  dl, PEG_E
    lea  si, s_hdr_e
    call write_str

    mov  dh, ROW_HISTHDR
    mov  dl, PEG_R
    lea  si, s_hdr_r
    call write_str

    ; "Pos" at col 67, "Col" at col 73 — no overlap
    mov  dh, ROW_HISTHDR
    mov  dl, HCOL_POS_LBL
    lea  si, s_hdr_pos
    mov  bl, ATTR_POS
    call write_str

    mov  dh, ROW_HISTHDR
    mov  dl, HCOL_COL_LBL
    lea  si, s_hdr_col
    mov  bl, ATTR_COL
    call write_str

    ; Determine first entry to show:
    ; If guessCnt <= MAX_HIST_DISP, start from 0.
    ; Otherwise start from guessCnt - MAX_HIST_DISP (scroll to show latest).
    xor  ah, ah
    mov  al, byte ptr guessCnt
    cmp  al, MAX_HIST_DISP
    jbe  dhi_no_scroll
    sub  al, MAX_HIST_DISP    ; first visible entry index
    jmp  dhi_set_start
dhi_no_scroll:
    xor  al, al
dhi_set_start:
    mov  ch, al               ; CH = first entry index

    ; CL = display row offset (0..6)
    xor  cl, cl

dhi_lp:
    ; Stop if we've shown MAX_HIST_DISP rows or consumed all guesses
    cmp  cl, MAX_HIST_DISP
    jae  dhi_done
    mov  al, ch
    add  al, cl               ; al = actual guess index
    cmp  al, byte ptr guessCnt
    jae  dhi_done

    push cx                   ; save cl (display row) and ch (start index)

    ; Actual guess index = ch + cl (in al already, stash in bh)
    xor  ah, ah
    mov  bh, al               ; BH = actual guess index

    ; Blank and draw row number
    mov  dh, ROW_HIST0
    add  dh, cl
    call blank_row

    mov  dh, ROW_HIST0
    add  dh, cl
    mov  dl, 2
    mov  al, '#'
    mov  bl, ATTR_HINT
    call write_char_at
    mov  dl, 3
    mov  al, bh
    add  al, '1'
    call write_char_at

    ; Draw guess pegs: offset into p2Hist = bh * CODE_LEN
    xor  ah, ah
    mov  al, bh
    mov  bl, CODE_LEN
    mul  bl               ; ax = bh * 4
    lea  si, p2Hist
    add  si, ax
    mov  dh, ROW_HIST0
    add  dh, cl
    call draw_code_row

    ; Pos score: p2HPos[bh]
    mov  dh, ROW_HIST0
    add  dh, cl
    mov  dl, HCOL_POS_DIG
    xor  ah, ah
    mov  al, bh
    lea  si, p2HPos
    add  si, ax
    mov  al, [si]
    add  al, '0'
    mov  bl, ATTR_POS
    call write_char_at

    ; Col score: p2HCol[bh]
    mov  dh, ROW_HIST0
    add  dh, cl
    mov  dl, HCOL_COL_DIG
    xor  ah, ah
    mov  al, bh
    lea  si, p2HCol
    add  si, ax
    mov  al, [si]
    add  al, '0'
    mov  bl, ATTR_COL
    call write_char_at

    pop  cx
    inc  cl
    jmp  dhi_lp

dhi_done:
    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret
draw_history endp

; ============================================================================
;  LEGEND
; ============================================================================
draw_legend_p1 proc near
    push ax
    push bx
    push dx
    push si

    mov  dh, ROW_LEGEND-1
    call blank_row
    mov  dh, ROW_LEGEND-1
    mov  dl, 1
    lea  si, s_p1_leg1
    mov  bl, ATTR_HINT
    call write_str
    mov  dh, ROW_LEGEND-1
    mov  dl, 22
    lea  si, s_p1_leg2
    call write_str

    mov  dh, ROW_LEGEND
    call blank_row
    mov  dh, ROW_LEGEND
    mov  dl, 1
    lea  si, s_p1_leg3
    call write_str
    mov  dh, ROW_LEGEND
    mov  dl, 22
    lea  si, s_p1_leg4
    call write_str

    pop  si
    pop  dx
    pop  bx
    pop  ax
    ret
draw_legend_p1 endp

draw_legend_p2 proc near
    push ax
    push bx
    push dx
    push si

    mov  dh, ROW_LEGEND-1
    call blank_row
    mov  dh, ROW_LEGEND-1
    mov  dl, 1
    lea  si, s_p2_leg1
    mov  bl, ATTR_HINT
    call write_str
    mov  dh, ROW_LEGEND-1
    mov  dl, 22
    lea  si, s_p2_leg2
    call write_str

    mov  dh, ROW_LEGEND
    call blank_row
    mov  dh, ROW_LEGEND
    mov  dl, 1
    lea  si, s_p2_leg3
    call write_str
    mov  dh, ROW_LEGEND
    mov  dl, 22
    lea  si, s_p2_leg4
    call write_str

    pop  si
    pop  dx
    pop  bx
    pop  ax
    ret
draw_legend_p2 endp

; ============================================================================
;  SCREEN COMPOSERS
; ============================================================================

draw_base proc near
    call cls
    call draw_border
    ret
draw_base endp

draw_p1_screen proc near
    call draw_base

    mov  dh, ROW_TITLE
    mov  dl, 1
    lea  si, s_p1_title
    mov  bl, ATTR_TITL
    call write_str

    mov  dh, ROW_SEP1
    call draw_sep

    mov  dh, ROW_ATT
    call blank_row

    call draw_color_picker
    call draw_sel_name

    mov  dh, ROW_SEP2
    call draw_sep

    call draw_slot_labels

    mov  dh, ROW_SLOTS
    lea  si, p1Code
    call draw_code_row

    mov  dh, ROW_ERR
    call blank_row
    mov  dh, ROW_RESULT
    call blank_row

    mov  dh, ROW_SEP3
    call draw_sep

    mov  dh, ROW_HISTHDR
    call blank_row

    call draw_legend_p1
    ret
draw_p1_screen endp

draw_p2_screen proc near
    call draw_base

    mov  dh, ROW_TITLE
    mov  dl, 1
    lea  si, s_p2_title
    mov  bl, ATTR_TITL
    call write_str

    mov  dh, ROW_SEP1
    call draw_sep

    call draw_att_bar
    call draw_color_picker
    call draw_sel_name

    mov  dh, ROW_SEP2
    call draw_sep

    call draw_slot_labels

    mov  dh, ROW_SLOTS
    lea  si, p2Code
    call draw_code_row

    mov  dh, ROW_ERR
    call blank_row

    call draw_last_result

    mov  dh, ROW_SEP3
    call draw_sep

    call draw_history
    call draw_legend_p2
    ret
draw_p2_screen endp

draw_handoff_screen proc near
    call draw_base

    mov  dh, ROW_TITLE
    mov  dl, 1
    lea  si, s_ho_title
    mov  bl, ATTR_TITL
    call write_str

    mov  dh, ROW_SEP1
    call draw_sep

    mov  dh, 4
    mov  dl, 1
    lea  si, s_ho_msg1
    mov  bl, ATTR_SEL
    call write_str

    mov  dh, 6
    mov  dl, 1
    lea  si, s_ho_msg2
    mov  bl, ATTR_LBL
    call write_str

    mov  dh, 9
    mov  dl, 1
    lea  si, s_ho_codelb
    mov  bl, ATTR_HINT
    call write_str

    mov  dh, 11
    lea  si, p1Code
    call draw_code_row

    mov  dh, 20
    call draw_sep

    mov  dh, 22
    mov  dl, 1
    lea  si, s_ho_hint
    mov  bl, ATTR_HINT
    call write_str
    ret
draw_handoff_screen endp

draw_win_screen proc near
    call draw_base

    mov  dh, ROW_TITLE
    mov  dl, 1
    lea  si, s_win_title
    mov  bl, ATTR_WIN
    call write_str

    mov  dh, ROW_SEP1
    call draw_sep

    mov  bl, ATTR_WIN
    mov  dh, 4
    mov  dl, 20
    lea  si, s_win1
    call write_str
    mov  dh, 5
    mov  dl, 20
    lea  si, s_win2
    call write_str
    mov  dh, 6
    mov  dl, 20
    lea  si, s_win3
    call write_str
    mov  dh, 7
    mov  dl, 20
    lea  si, s_win4
    call write_str

    mov  dh, 10
    mov  dl, 1
    lea  si, s_win_msg
    mov  bl, ATTR_LBL
    call write_str

    mov  dh, 12
    lea  si, p1Code
    call draw_code_row

    mov  dh, 20
    call draw_sep

    mov  dh, 22
    mov  dl, 1
    lea  si, s_win_hint
    mov  bl, ATTR_HINT
    call write_str
    ret
draw_win_screen endp

draw_lose_screen proc near
    call draw_base

    mov  dh, ROW_TITLE
    mov  dl, 1
    lea  si, s_los_title
    mov  bl, ATTR_LOSE
    call write_str

    mov  dh, ROW_SEP1
    call draw_sep

    mov  bl, ATTR_LOSE
    mov  dh, 5
    mov  dl, 30
    lea  si, s_los1
    call write_str
    mov  dh, 6
    mov  dl, 30
    lea  si, s_los2
    call write_str

    mov  dh, 10
    mov  dl, 1
    lea  si, s_los_msg
    mov  bl, ATTR_LBL
    call write_str

    mov  dh, 12
    lea  si, p1Code
    call draw_code_row

    mov  dh, 20
    call draw_sep

    mov  dh, 22
    mov  dl, 1
    lea  si, s_los_hint
    mov  bl, ATTR_HINT
    call write_str
    ret
draw_lose_screen endp

; ============================================================================
;  SCORING
; ============================================================================
score_guess proc near
    push ax
    push bx
    push cx
    push si
    push di

    mov  cx, CODE_LEN
    lea  si, p1Code
    lea  di, p2Code
    xor  bl, bl
sg_p1:
    mov  al, [si]
    cmp  al, [di]
    jne  sg_p1sk
    inc  bl
sg_p1sk:
    inc  si
    inc  di
    loop sg_p1
    mov  byte ptr corPos, bl

    mov  cx, CODE_LEN
    lea  si, p1Code
    lea  di, P1Temp
sg_cp:
    mov  al, [si]
    mov  [di], al
    inc  si
    inc  di
    loop sg_cp

    mov  cx, CODE_LEN
    lea  di, p2Code
    xor  bl, bl
sg_p2o:
    push cx
    mov  al, [di]
    mov  cx, CODE_LEN
    lea  si, P1Temp
sg_p2i:
    cmp  al, [si]
    jne  sg_p2isk
    inc  bl
    mov  byte ptr [si], 0FFh
    jmp  sg_p2id
sg_p2isk:
    inc  si
    loop sg_p2i
sg_p2id:
    pop  cx
    inc  di
    loop sg_p2o
    mov  byte ptr corCol, bl

    pop  di
    pop  si
    pop  cx
    pop  bx
    pop  ax
    ret
score_guess endp

; ============================================================================
;  RESET HELPERS
; ============================================================================
reset_p1 proc near
    mov  byte ptr p1Code[0], 0FFh
    mov  byte ptr p1Code[1], 0FFh
    mov  byte ptr p1Code[2], 0FFh
    mov  byte ptr p1Code[3], 0FFh
    ret
reset_p1 endp

reset_p2_code proc near
    mov  byte ptr p2Code[0], 0FFh
    mov  byte ptr p2Code[1], 0FFh
    mov  byte ptr p2Code[2], 0FFh
    mov  byte ptr p2Code[3], 0FFh
    ret
reset_p2_code endp

reset_p2_state proc near
    call reset_p2_code
    mov  byte ptr attempts, MAX_GUESSES
    mov  byte ptr guessCnt, 0
    mov  byte ptr selColor, 0FFh
    mov  byte ptr corPos, 0
    mov  byte ptr corCol, 0
    push ax
    push cx
    push di
    mov  cx, 40
    lea  di, p2Hist
rph_lp:
    mov  byte ptr [di], 0FFh
    inc  di
    loop rph_lp
    pop  di
    pop  cx
    pop  ax
    ret
reset_p2_state endp

; ============================================================================
;  P1 INPUT LOOP
; ============================================================================
p1_full proc near
    cmp  byte ptr p1Code[0], 0FFh
    je   p1fn
    cmp  byte ptr p1Code[1], 0FFh
    je   p1fn
    cmp  byte ptr p1Code[2], 0FFh
    je   p1fn
    cmp  byte ptr p1Code[3], 0FFh
    je   p1fn
    xor  ax, ax
    ret
p1fn:
    mov  ax, 1
    ret
p1_full endp

p1_loop proc near
p1lp:
    call wait_key
    cmp  ah, 01h
    jne  p1_notesc
    call reset_p1
    mov  byte ptr selColor, 0FFh
    call draw_p1_screen
    jmp  p1lp
p1_notesc:
    cmp  ah, 44h
    jne  p1_notquit
    jmp  quit_game
p1_notquit:
    cmp  al, 0Dh
    jne  p1_notenter
    call p1_full
    cmp  ax, 0
    jne  p1_bad_enter
    mov  byte ptr curPhase, 1
    mov  byte ptr selColor, 0FFh
    ret
p1_bad_enter:
    lea  si, s_p1_efill
    call draw_err_line
    jmp  p1lp
p1_notenter:
    cmp  al, '1'
    jb   p1_notcolor
    cmp  al, '6'
    ja   p1_notcolor
    sub  al, '1'
    mov  byte ptr selColor, al
    call draw_p1_screen
    jmp  p1lp
p1_notcolor:
    cmp  byte ptr selColor, 0FFh
    je   p1lp
    cmp  al, 'Q'
    je   p1_sq
    cmp  al, 'q'
    je   p1_sq
    cmp  al, 'W'
    je   p1_sw
    cmp  al, 'w'
    je   p1_sw
    cmp  al, 'E'
    je   p1_se
    cmp  al, 'e'
    je   p1_se
    cmp  al, 'R'
    je   p1_sr
    cmp  al, 'r'
    je   p1_sr
    jmp  p1lp
p1_sq:
    mov  bl, byte ptr selColor
    mov  byte ptr p1Code[0], bl
    jmp  p1_placed
p1_sw:
    mov  bl, byte ptr selColor
    mov  byte ptr p1Code[1], bl
    jmp  p1_placed
p1_se:
    mov  bl, byte ptr selColor
    mov  byte ptr p1Code[2], bl
    jmp  p1_placed
p1_sr:
    mov  bl, byte ptr selColor
    mov  byte ptr p1Code[3], bl
p1_placed:
    call clear_err_line
    call draw_p1_screen
    jmp  p1lp
p1_loop endp

; ============================================================================
;  P2 INPUT LOOP
; ============================================================================
p2_full proc near
    cmp  byte ptr p2Code[0], 0FFh
    je   p2fn
    cmp  byte ptr p2Code[1], 0FFh
    je   p2fn
    cmp  byte ptr p2Code[2], 0FFh
    je   p2fn
    cmp  byte ptr p2Code[3], 0FFh
    je   p2fn
    xor  ax, ax
    ret
p2fn:
    mov  ax, 1
    ret
p2_full endp

p2_save proc near
    push ax
    push bx
    push si
    push di
    xor  ah, ah
    mov  al, byte ptr guessCnt
    mov  bl, CODE_LEN
    mul  bl
    lea  di, p2Hist
    add  di, ax
    mov  al, byte ptr p2Code[0]
    mov  [di+0], al
    mov  al, byte ptr p2Code[1]
    mov  [di+1], al
    mov  al, byte ptr p2Code[2]
    mov  [di+2], al
    mov  al, byte ptr p2Code[3]
    mov  [di+3], al
    xor  ah, ah
    mov  al, byte ptr guessCnt
    lea  si, p2HPos
    add  si, ax
    mov  bl, byte ptr corPos
    mov  [si], bl
    lea  si, p2HCol
    add  si, ax
    mov  bl, byte ptr corCol
    mov  [si], bl
    pop  di
    pop  si
    pop  bx
    pop  ax
    ret
p2_save endp

p2_loop proc near
p2lp:
    call wait_key
    cmp  ah, 01h
    jne  p2_notesc
    call reset_p2_code
    mov  byte ptr selColor, 0FFh
    call draw_p2_screen
    jmp  p2lp
p2_notesc:
    cmp  ah, 44h
    jne  p2_notquit
    jmp  quit_game
p2_notquit:
    cmp  al, 0Dh
    jne  p2_notenter
    call p2_full
    cmp  ax, 0
    jne  p2_bad_enter
    call score_guess
    call p2_save
    inc  byte ptr guessCnt
    dec  byte ptr attempts
    cmp  byte ptr corPos, CODE_LEN
    je   p2_win
    cmp  byte ptr attempts, 0
    je   p2_lose
    call reset_p2_code
    mov  byte ptr selColor, 0FFh
    call draw_p2_screen
    jmp  p2lp
p2_win:
    mov  byte ptr curPhase, 3
    ret
p2_lose:
    mov  byte ptr curPhase, 4
    ret
p2_bad_enter:
    lea  si, s_p2_efill
    call draw_err_line
    jmp  p2lp
p2_notenter:
    cmp  al, '1'
    jb   p2_notcolor
    cmp  al, '6'
    ja   p2_notcolor
    sub  al, '1'
    mov  byte ptr selColor, al
    call draw_p2_screen
    jmp  p2lp
p2_notcolor:
    cmp  byte ptr selColor, 0FFh
    je   p2lp
    cmp  al, 'Q'
    je   p2_sq
    cmp  al, 'q'
    je   p2_sq
    cmp  al, 'W'
    je   p2_sw
    cmp  al, 'w'
    je   p2_sw
    cmp  al, 'E'
    je   p2_se
    cmp  al, 'e'
    je   p2_se
    cmp  al, 'R'
    je   p2_sr
    cmp  al, 'r'
    je   p2_sr
    jmp  p2lp
p2_sq:
    mov  bl, byte ptr selColor
    mov  byte ptr p2Code[0], bl
    jmp  p2_placed
p2_sw:
    mov  bl, byte ptr selColor
    mov  byte ptr p2Code[1], bl
    jmp  p2_placed
p2_se:
    mov  bl, byte ptr selColor
    mov  byte ptr p2Code[2], bl
    jmp  p2_placed
p2_sr:
    mov  bl, byte ptr selColor
    mov  byte ptr p2Code[3], bl
p2_placed:
    call clear_err_line
    call draw_p2_screen
    jmp  p2lp
p2_loop endp

; ============================================================================
;  MAIN
; ============================================================================
main proc
    mov  ax, @data
    mov  ds, ax

    mov  ah, 01h
    mov  ch, 26h
    mov  cl, 07h
    int  10h

    mov  ah, 00h
    mov  al, 03h
    int  10h

main_lp:
    mov  al, byte ptr curPhase

    cmp  al, 0
    jne  ml_1
    call draw_p1_screen
    call p1_loop
    jmp  main_lp
ml_1:
    cmp  al, 1
    jne  ml_2
    call draw_handoff_screen
    call wait_key
    mov  byte ptr curPhase, 2
    call reset_p2_state
    jmp  main_lp
ml_2:
    cmp  al, 2
    jne  ml_3
    call draw_p2_screen
    call p2_loop
    jmp  main_lp
ml_3:
    cmp  al, 3
    jne  ml_4
    call draw_win_screen
    call wait_key
    call reset_p1
    call reset_p2_state
    mov  byte ptr curPhase, 0
    jmp  main_lp
ml_4:
    call draw_lose_screen
    call wait_key
    call reset_p1
    call reset_p2_state
    mov  byte ptr curPhase, 0
    jmp  main_lp

quit_game:
    mov  ah, 01h
    mov  ch, 06h
    mov  cl, 07h
    int  10h
    mov  ah, 06h
    mov  al, 00h
    mov  bh, 07h
    xor  cx, cx
    mov  dx, 184Fh
    int  10h
    mov  ah, 02h
    mov  bh, 00h
    xor  dx, dx
    int  10h
    mov  ah, 4Ch
    mov  al, 00h
    int  21h

main endp
end main