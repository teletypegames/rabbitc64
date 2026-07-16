; -----------------------------------------------------------
; credits.asm - demo style credits: a smooth pixel scroller
; along the top (slide1's fine-scroll trick), gold wash on the
; big CREDITS, pulsing TELETYPE GAMES, rainbow crew names and
; a sprite parade of the scooter chasing the rabbits
; -----------------------------------------------------------

CR_SCROW    = 1          ; scroller char row (raster lines 58-65)
CR_RASTOP   = 56         ; switch fine scroll on just above it
CR_RASBOT   = 66         ; ... and off just below (rows 0/2 are blank)
CR_STEP     = 2          ; scroll speed: 8 px / 4 frames = 1 char
CR_PARADE_Y = 228        ; the parade runs along the bottom rows

credits_init:
    lda #BLACK           ; same black card style as the menu
    sta bg_top
    sta bg_bot
    jsr clear_screen

    +prbig 4, 6, YELLOW, txt_credits, 7

    +prtext 11, 13, WHITE, txt_ttgname, 14

    +prtext 13,  8, LGREEN, txt_crew0, 23
    +prtext 14, 10, LGREEN, txt_crew1, 20
    +prtext 15,  9, LGREEN, txt_crew2, 21
    +prtext 16, 10, LGREEN, txt_crew3, 20

    +prtext 18,  9, LGREY, txt_ai1, 22
    +prtext 19, 12, LGREY, txt_ai2, 16

    ; the scroller row renders in white
    ldx #39
ci_scol:
    lda #WHITE
    sta COLRAM+CR_SCROW*40,x
    dex
    bpl ci_scol
    lda #6               ; multiple of CR_STEP -> clean 4-frame cycle
    sta xscroll
    lda #0
    sta scrollidx
    sta washphase

    ; parade sprites: the red scooter chases seven white rabbits
    lda #RED
    sta SPR_COL
    ldx #7
ci_col:
    lda #WHITE
    sta SPR_COL,x
    dex
    bne ci_col
    lda #SPRP_SCOOT
    sta SPRPTR
    lda #0
    sta SPR_XEX
    sta SPR_YEX
    lda #$ff
    sta SPR_EN

    +setupd credits_update
    rts

credits_update:
    ; ---- all the heavy drawing runs first, while the beam
    ; is still far above the scroller row ----

    ; scroller: step the fine scroll, shift on wrap-around
    lda xscroll
    sec
    sbc #CR_STEP
    bpl cu_noshift
    clc
    adc #8
    sta xscroll
    ldx #0
cu_shift:
    lda SCREEN+CR_SCROW*40+1,x
    sta SCREEN+CR_SCROW*40,x
    inx
    cpx #39
    bne cu_shift
    ldx scrollidx        ; feed the next char in on the right
    lda scrolltext,x
    sta SCREEN+CR_SCROW*40+39
    inx
    cpx #scrolltext_end - scrolltext
    bne cu_feedok
    ldx #0
cu_feedok:
    stx scrollidx
    jmp cu_scrolled
cu_noshift:
    sta xscroll
cu_scrolled:

    ; gold wash rolling down the big CREDITS (rows 4-8; the
    ; letters are inverse spaces, color RAM on blanks is moot)
    inc washphase
    lda #0
    sta g8row
cu_wash:
    lda #4
    clc
    adc g8row
    tax
    jsr row_ptr
    lda washphase
    lsr
    clc
    adc g8row
    and #15
    tax
    lda washtbl,x
    ldy #33
cu_wcol:
    sta (collo),y
    dey
    cpy #5
    bne cu_wcol
    inc g8row
    lda g8row
    cmp #5
    bne cu_wash

    ; TELETYPE GAMES pulses grey-white
    ldx #11
    jsr row_ptr
    lda framectr
    lsr
    lsr
    lsr
    and #7
    tax
    lda pulsetbl,x
    ldy #26
cu_pulse:
    sta (collo),y
    dey
    cpy #12
    bne cu_pulse

    ; rainbow runs down the crew lines
    lda #0
    sta rtmp2            ; line counter
cu_crew:
    lda #13
    clc
    adc rtmp2
    tax
    jsr row_ptr
    lda framectr
    lsr
    lsr
    clc
    adc rtmp2
    and #7
    tax
    lda raintbl,x
    ldy #31
cu_ccol:
    sta (collo),y
    dey
    cpy #7
    bne cu_ccol
    inc rtmp2
    lda rtmp2
    cmp #4
    bne cu_crew

    ; the parade: everything scoots right to left, wraps at 344
    ldx #7
cu_par:
    lda crx_lo,x
    sec
    sbc crspd,x
    sta crx_lo,x
    lda crx_hi,x
    sbc #0
    sta crx_hi,x
    bne cu_ponscr        ; x >= 256: still on screen
    lda crx_lo,x
    cmp #24
    bcs cu_ponscr
    lda #$58             ; wrapped: back to x = 344
    sta crx_lo,x
    lda #1
    sta crx_hi,x
cu_ponscr:
    txa
    asl
    tay
    lda crx_lo,x
    sta SPRPOS,y
    cpx #0
    beq cu_pscoot
    ; rabbits bob and cycle their hop frames
    lda framectr
    lsr
    lsr
    lsr
    sta rtmp
    txa
    clc
    adc rtmp
    and #7
    tay
    lda hoptab,y
    sta rtmp
    lda #CR_PARADE_Y
    sec
    sbc rtmp
    pha
    lda framectr
    lsr
    lsr
    lsr
    sta rtmp
    txa
    clc
    adc rtmp
    and #3
    clc
    adc #SPRP_BIG
    sta SPRPTR,x
    txa
    asl
    tay
    pla
    sta SPRPOS+1,y
    jmp cu_pnext
cu_pscoot:
    lda #CR_PARADE_Y
    sta SPRPOS+1
cu_pnext:
    dex
    bpl cu_par
    ; x MSB shadow from the high bytes
    lda #0
    sta rtmp
    ldx #7
cu_pmsb:
    lda crx_hi,x
    beq cu_pmnext
    lda crbit,x
    ora rtmp
    sta rtmp
cu_pmnext:
    dex
    bpl cu_pmsb
    lda rtmp
    sta SPR_MSBX

    ; blink the return prompt
    lda framectr
    and #32
    bne cu_hide
    +prtext 21, 13, YELLOW, txt_return, 13
    jmp cu_input
cu_hide:
    +prtext 21, 13, YELLOW, txt_blank, 13
cu_input:
    jsr start_edge
    beq cu_stay
    lda #$c8             ; leave with the scroll register clean
    sta XCTRL
    jmp menu_init        ; back to the menu
cu_stay:

    ; ---- beam work: fine scroll on for the scroller row only ----
cu_wtop:
    lda RASTER
    cmp #CR_RASTOP
    bne cu_wtop
    lda xscroll          ; bits 0-2 = x scroll, bit 3 = 0 -> 38 cols
    sta XCTRL
cu_wbot:
    lda RASTER
    cmp #CR_RASBOT
    bne cu_wbot
    lda #$c8             ; back to default: 40 columns, no scroll
    sta XCTRL
    rts

; ---- tables ----
pulsetbl:                ; grey-white pulse (8 entries, cyclic)
    !byte $0b, $0c, $0f, $01, $01, $0f, $0c, $0b

raintbl:                 ; rainbow ramp for the crew lines
    !byte $02, $08, $07, $0d, $03, $0e, $04, $0a

crbit:                   ; sprite number -> register bit
    !byte 1, 2, 4, 8, 16, 32, 64, 128

crspd:                   ; parade speeds (sprite 0 = the scooter)
    !byte 2, 1, 3, 1, 2, 1, 3, 2
crx_lo:                  ; parade x positions (16 bit, start staggered)
    !byte 60, 100, 140, 180, 220, 4, 44, 84
crx_hi:
    !byte 0, 0, 0, 0, 0, 1, 1, 1

; ---- scrolltext (wraps around) ----
scrolltext:
    !scr "welcome to rabbit scooter ... the crew: "
    !scr "mr.zero - tasnadi zsolt ... mr.one - tari balazs ... "
    !scr "mr.two - timar zoltan ... mr.three - mezo bela ... "
    !scr "this whole game was written by an ai - honest! ... "
    !scr "greetings to all sceners out there ...      "
scrolltext_end:

; ---- credits variables ----
xscroll:   !byte 6       ; fine scroll register value (0-7)
scrollidx: !byte 0       ; next scrolltext char to feed in
