; -----------------------------------------------------------
; over.asm - full-screen game over card: big GAME OVER, the
; final score and a blinking retry prompt; fire restarts
; -----------------------------------------------------------

over_init:
    lda #BLACK           ; clean card, the playfield is gone
    sta bg_top
    sta bg_bot
    lda #0
    sta SPR_EN
    jsr clear_screen

    +prbig 4, 2, RED, txt_over, 9

    +prtext 12, 15, WHITE, txt_score, 5
    lda sc_d0
    ora #48
    sta SCREEN+12*40+21
    lda sc_d1
    ora #48
    sta SCREEN+12*40+22
    lda sc_d2
    ora #48
    sta SCREEN+12*40+23
    lda #YELLOW
    sta COLRAM+12*40+21
    sta COLRAM+12*40+22
    sta COLRAM+12*40+23

    +setupd over_update
    rts

over_update:
    ; blink the retry prompt
    lda framectr
    and #32
    bne ou_hide
    +prtext 16, 14, YELLOW, txt_retry, 12
    jmp ou_start
ou_hide:
    +prtext 16, 14, YELLOW, txt_blank, 12
ou_start:
    jsr start_edge
    beq ou_done
    jmp play_init        ; its rts returns to the main loop
ou_done:
    rts
