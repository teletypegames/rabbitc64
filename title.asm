; -----------------------------------------------------------
; title.asm - full-screen menu card: big RABBIT / SCOOTER
; logo flanked by two hopping rabbits, and a three-item menu:
; single player / multiplayer / credits (joystick up/down +
; fire; s, m, c pick; 1 and 2 pick and start at once)
; -----------------------------------------------------------

title_init:
    lda #BLACK           ; the menu plays on a black screen
    sta bg_top
    sta bg_bot
    jsr clear_screen

    +prbig 1, 8, RED, txt_rabbit, 6
    +prbig 7, 6, WHITE, txt_scooter, 7

    lda mp_mode          ; cursor starts on the last played mode
    sta menusel

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
    lda #226             ; just below the footer line
    sta SPRPOS+1
    lda #30              ; left rabbit
    sta SPRPOS+2
    lda #58
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

    ; joystick up/down steps the cursor (edge detected)
    jsr read_joy
    lda joyb
    and #3
    beq tu_udrel
    lda udheld
    bne tu_udend
    lda #1
    sta udheld
    lda joyb
    and #1               ; up
    beq tu_down
    lda menusel
    beq tu_udend
    dec menusel
    jmp tu_udend
tu_down:
    lda menusel
    cmp #MENU_ITEMS-1
    beq tu_udend
    inc menusel
    jmp tu_udend
tu_udrel:
    lda #0
    sta udheld
tu_udend:

    ; letter keys pick a line (fire still starts); skipped
    ; while joystick 1 fire is down, because it grounds the
    ; same row line the 'm' and 'c' keys sit on
    lda #$ff
    sta CIA1_PA
    lda CIA1_PB
    and #$10
    beq tu_keydone
    lda #$fd             ; 's': keyboard column 1, row bit 5
    sta CIA1_PA
    lda CIA1_PB
    and #$20
    bne tu_nos
    lda #0
    sta menusel
tu_nos:
    lda #$ef             ; 'm': keyboard column 4, row bit 4
    sta CIA1_PA
    lda CIA1_PB
    and #$10
    bne tu_nom
    lda #1
    sta menusel
tu_nom:
    lda #$fb             ; 'c': keyboard column 2, row bit 4
    sta CIA1_PA
    lda CIA1_PB
    and #$10
    bne tu_noc
    lda #2
    sta menusel
tu_noc:

    ; the 1 / 2 keys pick and start right away (edge detected)
    lda #$7f             ; keyboard column 7: '1' = bit 0, '2' = bit 3
    sta CIA1_PA
    lda CIA1_PB
    and #$09
    cmp #$09
    beq tu_keyup         ; neither key held
    ldx k12held
    bne tu_keydone       ; still held from an earlier frame
    inx
    stx k12held
    and #$01
    bne tu_key2
    lda #0
    sta menusel
    jmp title_go
tu_key2:
    lda #1
    sta menusel
    jmp title_go
tu_keyup:
    lda #0
    sta k12held
tu_keydone:

    ; footer: the two control lines take turns
    lda framectr
    and #64
    beq tu_foot2
    +prtext 21, 9, LGREY, txt_info, 21
    jmp tu_footdone
tu_foot2:
    +prtext 21, 9, LGREY, txt_info2, 21
tu_footdone:

    ; the menu items: the picked line is yellow
    ldx #0
tm_items:
    txa
    pha
    jsr draw_mitem
    pla
    tax
    inx
    cpx #MENU_ITEMS
    bne tm_items

    ; blinking '>' cursor in front of the picked line
    lda #$20
    sta SCREEN+14*40+12
    sta SCREEN+16*40+12
    sta SCREEN+18*40+12
    lda framectr
    and #16
    bne tu_start
    ldx menusel
    lda mcur_lo,x
    sta scrlo
    lda mcur_hi,x
    sta scrhi
    ldy #0
    lda #62              ; '>'
    sta (scrlo),y
    lda scrhi
    clc
    adc #$d4             ; same cell in color RAM
    sta scrhi
    lda #YELLOW
    sta (scrlo),y

tu_start:
    ; fire or space opens the picked line
    jsr start_edge
    beq tu_done
title_go:
    lda menusel
    cmp #2
    beq tg_credits
    sta mp_mode          ; item 0 / 1 doubles as the player count
    jmp play_init        ; its rts returns to the main loop
tg_credits:
    jmp credits_init
tu_done:
    rts

; ---- draw menu item X, yellow when it is the picked one ----
draw_mitem:
    lda mitem_lo,x
    sta txtlo
    lda mitem_hi,x
    sta txthi
    lda mitem_row,x
    sta prow
    lda #14
    sta pcol
    lda mitem_len,x
    sta plen
    lda #WHITE
    cpx menusel
    bne dm_store
    lda #YELLOW
dm_store:
    sta pcolor
    jmp print_text

; ---- menu tables ----
MENU_ITEMS = 3
mitem_lo:  !byte <txt_1p, <txt_2p, <txt_credits
mitem_hi:  !byte >txt_1p, >txt_2p, >txt_credits
mitem_len: !byte 13, 11, 7
mitem_row: !byte 14, 16, 18
mcur_lo:                 ; cursor cells: column 12 of those rows
    !byte <(SCREEN+14*40+12), <(SCREEN+16*40+12), <(SCREEN+18*40+12)
mcur_hi:
    !byte >(SCREEN+14*40+12), >(SCREEN+16*40+12), >(SCREEN+18*40+12)

; ---- menu variables ----
menusel:   !byte 0       ; picked line: 0-2
udheld:    !byte 0       ; joystick up/down edge detection state
