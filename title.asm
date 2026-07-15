; -----------------------------------------------------------
; title.asm - big RABBIT logo over the road, scooters parked
; on all five lanes, three demo rabbits hopping in, blinking
; "press fire to start"
; -----------------------------------------------------------

title_init:
    jsr clear_screen
    jsr draw_road

    +prbig 1, 8, BLACK, txt_rabbit, 6
    +prtext 6, 16, BLACK, txt_scooter, 7
    +prtext 17, 5, BLACK, txt_info, 30

    ; one parked scooter per lane on sprites 0-4
    ldx #4
ti_scoot:
    txa
    asl
    tay
    lda pxlo,x
    sta SPRPOS,y
    lda #PLAYER_SY
    sta SPRPOS+1,y
    lda #SPRP_SCOOT
    sta SPRPTR,x
    dex
    bpl ti_scoot
    lda #0
    sta SPR_XEX
    sta SPR_YEX

    ; demo rabbits on slots 4-6 (sprites 5-7), staggered starts
    ldx #4
ti_demo:
    jsr rand5
    sta r_lane,x
    lda demo_t-4,x
    sta r_thi,x
    lda #1
    sta r_act,x
    inx
    cpx #NRABBITS
    bne ti_demo

    +setupd title_update
    rts

title_update:
    ; shadows: five scooters (lane 4 needs the x MSB), no expand
    lda #%00011111
    sta en_sh
    lda #%00010000
    sta msb_sh
    lda #0
    sta xex_sh
    sta yex_sh

    ; demo rabbits: constant lope, respawn on a random lane
    ldx #4
tu_rab:
    lda r_thi,x
    clc
    adc #3
    sta r_thi,x
    bcc tu_pos
    lda #0
    sta r_thi,x
    jsr rand5
    sta r_lane,x
tu_pos:
    jsr rab_pos
    inx
    cpx #NRABBITS
    bne tu_rab

    jsr write_shadows

    ; blink the start line
    lda framectr
    and #32
    bne tu_hide
    +prtext 15, 10, BLACK, txt_press, 19
    jmp tu_start
tu_hide:
    +prtext 15, 10, BLACK, txt_blank, 19
tu_start:
    jsr start_edge
    beq tu_done
    jmp play_init        ; its rts returns to the main loop
tu_done:
    rts

demo_t: !byte 0, 85, 170
