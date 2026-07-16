; -----------------------------------------------------------
; main.asm - RABBIT SCOOTER for the C64
;   port of the rabbitroller Game & Watch style LCD game:
;   rabbits hop toward you on a five-lane road, dodge them
;   on your scooter - a rabbit reaching your lane is a miss,
;   one passing in another lane is a point; 3 misses = over
;
; Files:
;   defs.asm    - constants, zero page, macros
;   title.asm   - title screen: demo rabbits + press fire
;   play.asm    - the game itself
;   over.asm    - game over box + retry
;   common.asm  - shared routines, input, rabbit positioning
;   tables.asm  - perspective / speed tables (assembly-time)
;   sprites.asm - sprite art (scooter, small + big rabbits)
;
; Build: acme -f cbm -o rabbit.prg main.asm
; -----------------------------------------------------------

!to "rabbit.prg", cbm

* = $0801

; ---- BASIC stub: 10 SYS 2064 ----
; so after LOAD"*",8,1 it's enough to type RUN
!byte $0c, $08          ; address of next line
!byte $0a, $00          ; line number: 10
!byte $9e               ; SYS token
!byte $20, $32, $30, $36, $34   ; " 2064"
!byte $00               ; end of line
!byte $00, $00          ; end of program

* = $0810                ; = 2064 in decimal

!src "defs.asm"

start:
    sei                  ; no KERNAL IRQ - raster polling must not jitter

    ; sunny scene: black frame, sky above the horizon split
    lda #BLACK
    sta BORDER
    lda #COL_SKY
    sta BG

    ; sprites: red scooter, white rabbits, hires, in front
    lda #RED
    sta SPR_COL
    ldx #7
sprcol:
    lda #WHITE
    sta SPR_COL,x
    dex
    bne sprcol
    lda #0
    sta SPR_EN
    sta SPR_MC
    sta SPR_PRIO
    sta SPR_MSBX
    sta SPR_XEX
    sta SPR_YEX
    sta framectr
    sta fheld

!ifdef AUTOPLAY {        ; test builds boot straight into the game
    jsr play_init
} else {
    jsr intro_init       ; TTG logo, then the menu
}

; ============================================================
; main loop - one state update per PAL frame, synced to the
; raster beam in the lower border
; ============================================================
main:
    jsr wait_frame
    lda bg_top           ; repaint the sky while the beam is off screen
    sta BG
    inc framectr
    jsr rand8            ; stir the RNG once per frame
    jsr call_update      ; finishes long before the horizon line
wait_grass:
    lda RASTER           ; split the background at the horizon:
    cmp #RAS_SPLIT       ;   sky above, grass below (the intro
    bne wait_grass       ;   sets both halves to black)
    lda bg_bot
    sta BG
    jmp main

call_update:
    jmp (updvec)         ; each update runs exactly one frame, ends with rts

; ---- wait for raster line RAS_SYNC (leave it first, so a
; fast update cannot run twice in the same frame) ----
wait_frame:
    lda RASTER
    cmp #RAS_SYNC
    beq wait_frame
wf_hit:
    lda RASTER
    cmp #RAS_SYNC
    bne wf_hit
    rts

; ============================================================
; sprite art first: it must stay below $1000, where the VIC
; would see the character ROM shadow instead of our RAM
; ============================================================
!src "sprites.asm"
!if * > $1000 {
    !error "sprite data ran into the char ROM shadow at $1000"
}

; ============================================================
; the states and everything they share
; ============================================================
!src "intro.asm"
!src "menu.asm"
!src "credits.asm"
!src "story.asm"
!src "play.asm"
!src "over.asm"
!src "common.asm"
!src "tables.asm"
