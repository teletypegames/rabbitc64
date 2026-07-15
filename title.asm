; -----------------------------------------------------------
; title.asm - full-screen menu card: big RABBIT / SCOOTER
; logo flanked by two hopping rabbits, the scooter waiting at
; the bottom, blinking "fire = start game"
; -----------------------------------------------------------

title_init:
    lda #BLACK           ; the menu plays on a black screen
    sta bg_top
    sta bg_bot
    jsr clear_screen

    +prbig 2, 8, RED, txt_rabbit, 6
    +prbig 8, 6, WHITE, txt_scooter, 7
    +prtext 18, 8, WHITE, txt_info, 23

    ; decoration: white rabbits flank the logo (sprites 1-2,
    ; double-sized), the red scooter waits at the bottom
    lda #RED
    sta SPR_COL
    lda #WHITE
    sta SPR_COL+1
    sta SPR_COL+2
    lda #SPRP_SCOOT
    sta SPRPTR
    lda #172             ; center lane position
    sta SPRPOS
    lda #210
    sta SPRPOS+1
    lda #30              ; left rabbit
    sta SPRPOS+2
    lda #66
    sta SPRPOS+3
    sta SPRPOS+5
    lda #34              ; right rabbit: x = 290, MSB below
    sta SPRPOS+4
    lda #%00000100
    sta SPR_MSBX
    lda #%00000110       ; both rabbits double-sized
    sta SPR_XEX
    sta SPR_YEX
    lda #%00000111
    sta SPR_EN

    +setupd title_update
    rts

title_update:
    ; hop the flanking rabbits through the big frames,
    ; half a cycle apart
    lda framectr
    lsr
    lsr
    lsr
    and #3
    sta rtmp
    clc
    adc #SPRP_BIG
    sta SPRPTR+1
    lda rtmp
    clc
    adc #2
    and #3
    clc
    adc #SPRP_BIG
    sta SPRPTR+2

    ; blink the start line
    lda framectr
    and #32
    bne tu_hide
    +prtext 15, 11, YELLOW, txt_press, 17
    jmp tu_start
tu_hide:
    +prtext 15, 11, YELLOW, txt_blank, 17
tu_start:
    jsr start_edge
    beq tu_done
    jmp play_init        ; its rts returns to the main loop
tu_done:
    rts
