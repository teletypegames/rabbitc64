; -----------------------------------------------------------
; menu.asm - full-screen menu card: big RABBIT VS SCOOTER
; logo flanked by two hopping rabbits, and a four-item menu:
; single player / multiplayer / credits / story
; (joystick up/down + fire; s, m, c, t shortcut keys;
; 1 and 2 pick player mode and start at once)
; -----------------------------------------------------------

menu_init:
    lda #BLACK           ; the menu plays on a black screen
    sta bg_top
    sta bg_bot
    jsr clear_screen

    +prbig 1, 8, RED, txt_rabbit, 6
    +prtext 6, 19, YELLOW, txt_vs, 2
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
    lda #%00000110       ; only the two flanking rabbits
    sta SPR_EN

    +setupd menu_update
    rts

menu_update:
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
    beq mu_udrel
    lda udheld
    bne mu_udend
    lda #1
    sta udheld
    lda joyb
    and #1               ; up
    beq mu_down
    lda menusel
    beq mu_udend
    dec menusel
    lda #SFX_CURSOR
    jsr sfx_play
    jmp mu_udend
mu_down:
    lda menusel
    cmp #MENU_ITEMS-1
    beq mu_udend
    inc menusel
    lda #SFX_CURSOR
    jsr sfx_play
    jmp mu_udend
mu_udrel:
    lda #0
    sta udheld
mu_udend:

    ; letter keys pick a line (fire still starts); skipped
    ; while joystick 1 fire is down, because it grounds the
    ; same row line the 'm' and 'c' keys sit on
    lda #$ff
    sta CIA1_PA
    lda CIA1_PB
    and #$10
    beq mu_keydone
    lda #$fd             ; 's': keyboard column 1, row bit 5
    sta CIA1_PA
    lda CIA1_PB
    and #$20
    bne mu_nos
    lda #0
    sta menusel
mu_nos:
    lda #$ef             ; 'm': keyboard column 4, row bit 4
    sta CIA1_PA
    lda CIA1_PB
    and #$10
    bne mu_nom
    lda #1
    sta menusel
mu_nom:
    lda #$fb             ; 'c': keyboard column 2, row bit 4
    sta CIA1_PA
    lda CIA1_PB
    and #$10
    bne mu_noc
    lda #2
    sta menusel
mu_noc:
    lda CIA1_PB          ; column 2 still selected
    and #$40             ; 't': keyboard column 2, row bit 6
    bne mu_not
    lda #3
    sta menusel
mu_not:

    ; the 1 / 2 keys pick and start right away (edge detected)
    lda #$7f             ; keyboard column 7: '1' = bit 0, '2' = bit 3
    sta CIA1_PA
    lda CIA1_PB
    and #$09
    cmp #$09
    beq mu_keyup         ; neither key held
    ldx k12held
    bne mu_keydone       ; still held from an earlier frame
    inx
    stx k12held
    and #$01
    bne mu_key2
    lda #0
    sta menusel
    jmp menu_go
mu_key2:
    lda #1
    sta menusel
    jmp menu_go
mu_keyup:
    lda #0
    sta k12held
mu_keydone:

    ; footer: both control lines always visible
    +prtext 22, 9, LGREY, txt_info, 21
    +prtext 23, 9, LGREY, txt_info2, 21

    ; the menu items: the picked line is yellow
    ldx #0
mm_items:
    txa
    pha
    jsr draw_mitem
    pla
    tax
    inx
    cpx #MENU_ITEMS
    bne mm_items

    ; blinking '>' cursor in front of the picked line
    lda #$20
    sta SCREEN+14*40+12
    sta SCREEN+16*40+12
    sta SCREEN+18*40+12
    sta SCREEN+20*40+12
    lda framectr
    and #16
    bne mu_start
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

mu_start:
    ; fire or space opens the picked line
    jsr start_edge
    beq mu_done
menu_go:
    lda #SFX_SELECT
    jsr sfx_play
    lda menusel
    cmp #2
    beq mg_credits
    cmp #3
    beq mg_story
    sta mp_mode          ; item 0 / 1 doubles as the player count
    jmp play_init        ; its rts returns to the main loop
mg_credits:
    jmp credits_init
mg_story:
    jmp story_init
mu_done:
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
    stx rtmp              ; print_text trashes X
    jsr print_text
    ldx rtmp
    ldy mitem_key,x      ; recolor the shortcut letter
    lda #CYAN
    sta (collo),y
    rts

; ---- menu tables ----
MENU_ITEMS = 4
mitem_lo:  !byte <txt_1p, <txt_2p, <txt_credits, <txt_story
mitem_hi:  !byte >txt_1p, >txt_2p, >txt_credits, >txt_story
mitem_key: !byte 0, 0, 0, 1  ; offset of the highlighted shortcut letter
mitem_len: !byte 13, 11, 7, 5
mitem_row: !byte 14, 16, 18, 20
mcur_lo:                 ; cursor cells: column 12 of those rows
    !byte <(SCREEN+14*40+12), <(SCREEN+16*40+12)
    !byte <(SCREEN+18*40+12), <(SCREEN+20*40+12)
mcur_hi:
    !byte >(SCREEN+14*40+12), >(SCREEN+16*40+12)
    !byte >(SCREEN+18*40+12), >(SCREEN+20*40+12)

; ---- menu variables ----
menusel:   !byte 0       ; picked line: 0-3
udheld:    !byte 0       ; joystick up/down edge detection state
