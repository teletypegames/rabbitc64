; -----------------------------------------------------------
; sound.asm - minimal SID sound driver using voice 1
;   sfx_init  - set master volume, silence voice 1
;   sfx_play  - start effect A (SFX_SCORE, SFX_MISS, etc.)
;   sfx_update - call once per frame to handle duration/slides
; -----------------------------------------------------------

; ---- one-time setup: master volume on, voice 1 silent ----
sfx_init:
    lda #$0f             ; max volume, no filter
    sta SID_VOL
    lda #0
    sta SID_V1CR         ; gate off, no waveform
    sta sfx_timer
    rts

; ---- start playing effect A ----
sfx_play:
    tax
    ; gate off first (retrigger envelope)
    lda #0
    sta SID_V1CR
    ; load parameters from the table
    lda sfx_flo,x
    sta SID_V1FL
    lda sfx_fhi,x
    sta SID_V1FH
    lda sfx_ad,x
    sta SID_V1AD
    lda sfx_sr,x
    sta SID_V1SR
    lda #$00             ; pulse width mid-point for pulse wave
    sta SID_V1PL
    lda #$08
    sta SID_V1PH
    lda sfx_wave,x       ; waveform + gate bit
    sta SID_V1CR
    lda sfx_dur,x
    sta sfx_timer
    lda sfx_slide,x
    sta sfx_sld
    rts

; ---- per-frame update: pitch slide + gate off when done ----
sfx_update:
    lda sfx_timer
    beq sfu_done          ; nothing playing
    dec sfx_timer
    bne sfu_slide
    ; duration expired: gate off
    lda #0
    sta SID_V1CR
    rts
sfu_slide:
    ; apply pitch slide (signed: positive = up, negative = down)
    lda sfx_sld
    beq sfu_done
    bmi sfu_down
    ; slide up
    clc
    adc SID_V1FH
    sta SID_V1FH
    rts
sfu_down:
    ; slide down (sfx_sld is negative, e.g. $fe = -2)
    clc
    adc SID_V1FH          ; adding a negative = subtracting
    sta SID_V1FH
    bcs sfu_done          ; no underflow
    lda #0
    sta SID_V1FH          ; clamp at zero
sfu_done:
    rts

; ---- effect parameter tables (indexed by SFX ID) ----

; initial frequency low byte
sfx_flo:
    !byte $00             ; SFX_SCORE:  freq $1C00
    !byte $00             ; SFX_MISS:   freq $0800
    !byte $00             ; SFX_OVER:   freq $2000
    !byte $00             ; SFX_CURSOR: freq $0A00
    !byte $00             ; SFX_SELECT: freq $1000

; initial frequency high byte
sfx_fhi:
    !byte $1c             ; SFX_SCORE
    !byte $08             ; SFX_MISS
    !byte $20             ; SFX_OVER
    !byte $0a             ; SFX_CURSOR
    !byte $10             ; SFX_SELECT

; attack/decay ($XY: X=attack 0-F, Y=decay 0-F)
sfx_ad:
    !byte $00             ; SFX_SCORE:  instant attack, instant decay
    !byte $00             ; SFX_MISS:   instant attack, instant decay
    !byte $09             ; SFX_OVER:   instant attack, slow decay
    !byte $00             ; SFX_CURSOR: instant attack, instant decay
    !byte $00             ; SFX_SELECT: instant attack, instant decay

; sustain/release ($XY: X=sustain 0-F, Y=release 0-F)
sfx_sr:
    !byte $a8             ; SFX_SCORE:  medium sustain, medium release
    !byte $f5             ; SFX_MISS:   full sustain, medium release
    !byte $08             ; SFX_OVER:   zero sustain, medium release
    !byte $50             ; SFX_CURSOR: low sustain, instant release
    !byte $98             ; SFX_SELECT: medium sustain, medium release

; waveform + gate ($XY: bit7=noise, bit6=pulse, bit5=saw, bit4=tri, bit0=gate)
sfx_wave:
    !byte $11             ; SFX_SCORE:  triangle + gate
    !byte $81             ; SFX_MISS:   noise + gate
    !byte $21             ; SFX_OVER:   sawtooth + gate
    !byte $41             ; SFX_CURSOR: pulse + gate
    !byte $11             ; SFX_SELECT: triangle + gate

; duration in frames
sfx_dur:
    !byte 8               ; SFX_SCORE
    !byte 10              ; SFX_MISS
    !byte 50              ; SFX_OVER
    !byte 3               ; SFX_CURSOR
    !byte 8               ; SFX_SELECT

; pitch slide per frame (signed: + = up, - = down, 0 = none)
sfx_slide:
    !byte 0               ; SFX_SCORE:  steady
    !byte $fe             ; SFX_MISS:   slide down (-2)
    !byte $fd             ; SFX_OVER:   slide down (-3)
    !byte 0               ; SFX_CURSOR: steady
    !byte 2               ; SFX_SELECT: slide up (+2)

; ---- driver state ----
sfx_timer: !byte 0        ; frames remaining for current effect
sfx_sld:   !byte 0        ; current slide value
