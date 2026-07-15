; -----------------------------------------------------------
; over.asm - game over box over the frozen playfield: final
; score + blinking retry prompt, fire restarts the round
; -----------------------------------------------------------

BOXROW = 10              ; box: rows 10-14, columns 12-27
BOXCOL = 12
BOXW   = 16

over_init:
    lda en_sh            ; the scooter may be mid-blink: show it
    ora #1
    sta SPR_EN

    ; box interior + frame, drawn over the frozen road
    ldx #0
oi_row:
    txa
    clc
    adc #BOXROW
    tay
    lda mul40lo,y
    clc
    adc #BOXCOL
    sta scrlo
    lda mul40hi,y
    adc #>SCREEN
    sta scrhi
    sta colhi            ; color RAM pointer for the same cells
    lda scrlo
    sta collo
    lda colhi
    clc
    adc #$d4
    sta colhi
    ldy #BOXW-1
oi_col:
    jsr box_char
    sta (scrlo),y
    lda #WHITE
    sta (collo),y
    dey
    bpl oi_col
    inx
    cpx #5
    bne oi_row

    +prtext BOXROW+1, 15, WHITE, txt_over, 9
    +prtext BOXROW+2, 15, WHITE, txt_score, 5

    ; final score digits next to the label
    lda sc_d0
    ora #48
    sta SCREEN+(BOXROW+2)*40+21
    lda sc_d1
    ora #48
    sta SCREEN+(BOXROW+2)*40+22
    lda sc_d2
    ora #48
    sta SCREEN+(BOXROW+2)*40+23
    lda #YELLOW
    sta COLRAM+(BOXROW+2)*40+21
    sta COLRAM+(BOXROW+2)*40+22
    sta COLRAM+(BOXROW+2)*40+23

    +setupd over_update
    rts

; pick the frame/fill character for box row X, column Y (keeps Y)
box_char:
    cpx #0
    beq bc_top
    cpx #4
    beq bc_bottom
    cpy #0
    beq bc_side
    cpy #BOXW-1
    beq bc_side
    lda #$20             ; interior: erase the road behind the box
    rts
bc_side:
    lda #$5d             ; vertical bar
    rts
bc_top:
    cpy #0
    beq bc_tl
    cpy #BOXW-1
    beq bc_tr
    lda #$40             ; horizontal bar
    rts
bc_tl:
    lda #$55             ; rounded corners
    rts
bc_tr:
    lda #$49
    rts
bc_bottom:
    cpy #0
    beq bc_bl
    cpy #BOXW-1
    beq bc_br
    lda #$40
    rts
bc_bl:
    lda #$4a
    rts
bc_br:
    lda #$4b
    rts

over_update:
    ; blink the retry prompt
    lda framectr
    and #32
    bne ou_hide
    +prtext BOXROW+3, 14, YELLOW, txt_retry, 12
    jmp ou_start
ou_hide:
    +prtext BOXROW+3, 14, YELLOW, txt_blank, 12
ou_start:
    jsr start_edge
    beq ou_done
    jmp play_init        ; its rts returns to the main loop
ou_done:
    rts
