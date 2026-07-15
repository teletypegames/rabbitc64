; -----------------------------------------------------------
; title.asm - full-screen menu card: big RABBIT / SCOOTER
; logo flanked by two hopping rabbits, single/multiplayer
; picker (joystick up/down + fire, or the 1 / 2 keys)
; -----------------------------------------------------------

title_init:
    lda #BLACK           ; the menu plays on a black screen
    sta bg_top
    sta bg_bot
    jsr clear_screen

    +prbig 2, 8, RED, txt_rabbit, 6
    +prbig 8, 6, WHITE, txt_scooter, 7
    +prtext 18, 9, LGREY, txt_info, 21
    +prtext 19, 9, LGREY, txt_info2, 21

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

    ; joystick up/down picks the mode
    jsr read_joy
    lda joyb
    and #1               ; up
    beq tu_noup
    lda #0
    sta mp_mode
tu_noup:
    lda joyb
    and #2               ; down
    beq tu_nodown
    lda #1
    sta mp_mode
tu_nodown:

    ; the 's' / 'm' keys pick the mode (fire still starts)
    lda #$fd             ; 's': keyboard column 1, row bit 5
    sta CIA1_PA
    lda CIA1_PB
    and #$20
    bne tu_nos
    lda #0
    sta mp_mode
tu_nos:
    lda #$ef             ; 'm': keyboard column 4, row bit 4
    sta CIA1_PA
    lda CIA1_PB
    and #$10
    bne tu_nom
    lda #1
    sta mp_mode
tu_nom:

    ; the 1 / 2 keys pick and start right away (edge detected)
    lda #$7f             ; keyboard column 7: '1' = bit 0, '2' = bit 3
    sta CIA1_PA
    lda CIA1_PB
    and #$09
    cmp #$09
    beq tu_keyup         ; neither key held
    ldx k12held
    bne tu_menu          ; still held from an earlier frame
    inx
    stx k12held
    and #$01
    bne tu_key2
    lda #0
    sta mp_mode
    jmp title_go
tu_key2:
    lda #1
    sta mp_mode
    jmp title_go
tu_keyup:
    lda #0
    sta k12held
tu_menu:

    ; the two options: the picked line is yellow
    lda mp_mode
    bne tm_multi
    +prtext 14, 14, YELLOW, txt_1p, 13
    +prtext 16, 14, WHITE, txt_2p, 11
    jmp tm_cursor
tm_multi:
    +prtext 14, 14, WHITE, txt_1p, 13
    +prtext 16, 14, YELLOW, txt_2p, 11
tm_cursor:
    ; blinking '>' cursor in front of the picked line
    lda #$20
    sta SCREEN+14*40+12
    sta SCREEN+16*40+12
    lda framectr
    and #16
    bne tu_start
    lda mp_mode
    bne tm_cur2
    lda #62              ; '>'
    sta SCREEN+14*40+12
    lda #YELLOW
    sta COLRAM+14*40+12
    jmp tu_start
tm_cur2:
    lda #62
    sta SCREEN+16*40+12
    lda #YELLOW
    sta COLRAM+16*40+12

tu_start:
    ; fire or space starts the picked mode
    jsr start_edge
    beq tu_done
title_go:
    jmp play_init        ; its rts returns to the main loop
tu_done:
    rts
