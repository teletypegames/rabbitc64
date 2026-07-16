; -----------------------------------------------------------
; music.asm - SID music driver (adapted from the c64-demo)
;   voice 1: bass (pulse), voice 2: drums (noise),
;   voice 3: echo lead (triangle)
;   music_init:  clear SID, set instruments, restart song
;   music_play:  call once per frame
;   music_stop:  silence everything
; -----------------------------------------------------------

; ---- waveform control values ----
BASS_ON   = $41                 ; pulse + gate
BASS_OFF  = $40
DRUM_ON   = $81                 ; noise + gate
DRUM_OFF  = $80
LEAD_ON   = $11                 ; triangle + gate
LEAD_OFF  = $10

SONG_LEN  = 128

; ---- initialize SID and restart the song ----
music_init:
    ldx #24
    lda #0
mi_clr:
    sta SID_BASE,x
    dex
    bpl mi_clr

    lda #$00                    ; bass: instant attack, full sustain
    sta SID_V1AD
    lda #$f3
    sta SID_V1SR
    lda #$08                    ; bass pulse width 50%
    sta SID_V1PH
    lda #$00
    sta SID_V1PL
    lda #$04                    ; drums: instant attack, ~110 ms decay
    sta SID_V2AD
    lda #$00
    sta SID_V2SR
    lda #$06                    ; lead: pluck, ~200 ms decay
    sta SID_V3AD
    lda #$00
    sta SID_V3SR

    lda #$0f                    ; master volume = 15
    sta SID_VOL

    lda #0
    sta mus_row
    sta mus_spd_ix
    sta mus_bcut
    lda #1
    sta mus_tick
    rts

; ---- play one tick: called once per frame ----
music_play:
    pha
    txa
    pha
    tya
    pha
    jsr mp_core
    pla
    tay
    pla
    tax
    pla
    rts

mp_core:
    lda mus_bcut
    beq mp_tick
    dec mus_bcut
    bne mp_tick
    lda #BASS_OFF
    sta SID_V1CR
mp_tick:
    dec mus_tick
    beq mp_row
    rts

mp_row:
    ldx mus_spd_ix
    lda mus_spd_tbl,x
    sta mus_tick
    inx
    cpx #6
    bne mp_spd_ok
    ldx #0
mp_spd_ok:
    stx mus_spd_ix

    ldx mus_row

    ; ---- voice 1: bass ----
    lda bass_pat,x
    beq mp_drums
    cmp #1
    bne mp_bass_note
    lda #BASS_OFF
    sta SID_V1CR
    jmp mp_drums
mp_bass_note:
    and #$7f
    tay
    lda bass_flo,y
    sta SID_V1FL
    lda bass_fhi,y
    sta SID_V1FH
    lda #BASS_OFF
    sta SID_V1CR
    lda #BASS_ON
    sta SID_V1CR

    ; ---- voice 2: drums ----
mp_drums:
    lda drum_pat,x
    beq mp_lead
    cmp #1
    bne mp_drum_note
    lda #DRUM_OFF
    sta SID_V2CR
    jmp mp_lead
mp_drum_note:
    and #$7f
    tay
    lda drum_flo,y
    sta SID_V2FL
    lda drum_fhi,y
    sta SID_V2FH
    lda #DRUM_OFF
    sta SID_V2CR
    lda #DRUM_ON
    sta SID_V2CR

    ; ---- voice 3: lead echo ----
mp_lead:
    lda lead_pat,x
    beq mp_next
    and #$7f
    tay
    lda lead_flo,y
    sta SID_V3FL
    lda lead_fhi,y
    sta SID_V3FH
    lda #LEAD_OFF
    sta SID_V3CR
    lda #LEAD_ON
    sta SID_V3CR

mp_next:
    inx
    cpx #SONG_LEN
    bne mp_store
    ldx #0
    stx mus_spd_ix
mp_store:
    stx mus_row
    lda bass_pat,x
    bpl mp_nocut
    lda mus_tick
    sec
    sbc #2
    sta mus_bcut
mp_nocut:
    rts

; ---- stop: silence SID, restore for SFX use ----
music_stop:
    ldx #24
    lda #0
ms_clr:
    sta SID_BASE,x
    dex
    bpl ms_clr
    rts

; ---- state ----
mus_row:       !byte 0
mus_tick:      !byte 1
mus_spd_ix:    !byte 0
mus_bcut:      !byte 0

mus_spd_tbl:   !byte 4,4,4,4,4,4

; ---- note tables (PAL SID) ----
bass_flo: !byte $5a,$e0,$2d,$cf
bass_fhi: !byte $04,$03,$05,$05
drum_flo: !byte $9c,$ff
drum_fhi: !byte $45,$ff
lead_flo: !byte $ce,$02,$64,$76,$9c,$04,$c8,$eb
lead_fhi: !byte $22,$1f,$29,$2e,$45,$3e,$52,$5c

; ---- pattern data ----
bass_pat:
    !byte $80,$00,$00,$00,$01,$00,$80,$00,$01,$00,$00,$00,$81,$00,$80,$00
    !byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    !byte $80,$00,$00,$00,$01,$00,$80,$00,$01,$00,$00,$00,$81,$00,$80,$00
    !byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    !byte $80,$00,$00,$00,$01,$00,$80,$00,$01,$00,$00,$00,$81,$00,$80,$00
    !byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    !byte $82,$00,$82,$00,$01,$00,$82,$00,$01,$00,$00,$00,$82,$00,$83,$00
    !byte $01,$00,$83,$00,$01,$00,$83,$00,$83,$00,$01,$00,$83,$00,$01,$00
drum_pat:
    !byte $80,$00,$00,$00,$00,$00,$00,$00,$81,$00,$00,$00,$00,$00,$00,$00
    !byte $80,$00,$00,$00,$00,$00,$80,$00,$81,$00,$00,$00,$00,$00,$00,$00
    !byte $80,$00,$00,$00,$00,$00,$00,$00,$81,$00,$00,$00,$00,$00,$00,$00
    !byte $80,$00,$00,$00,$00,$00,$80,$00,$81,$00,$00,$00,$00,$00,$00,$00
    !byte $80,$00,$00,$00,$00,$00,$00,$00,$81,$00,$00,$00,$00,$00,$00,$00
    !byte $80,$00,$00,$00,$00,$00,$80,$00,$81,$00,$00,$00,$00,$00,$00,$00
    !byte $80,$00,$00,$00,$00,$00,$00,$00,$81,$00,$00,$00,$00,$00,$00,$00
    !byte $80,$00,$00,$00,$00,$00,$80,$00,$81,$00,$00,$00,$00,$00,$00,$00
lead_pat:
    !byte $00,$00,$80,$00,$00,$00,$00,$00,$84,$00,$00,$00,$00,$00,$81,$00
    !byte $80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    !byte $00,$00,$84,$00,$00,$00,$00,$00,$80,$00,$00,$00,$00,$00,$81,$00
    !byte $80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    !byte $00,$00,$84,$00,$00,$00,$00,$00,$80,$00,$00,$00,$00,$00,$81,$00
    !byte $80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    !byte $00,$00,$82,$00,$86,$00,$00,$00,$82,$00,$00,$00,$00,$00,$86,$00
    !byte $83,$00,$00,$00,$87,$00,$00,$00,$83,$00,$87,$00,$00,$00,$83,$00
