; -----------------------------------------------------------
; play.asm - the game: lane movement with key-repeat, rabbit
; spawning with a score-driven interval, arrivals scored or
; counted as a miss, HUD updates
; -----------------------------------------------------------

; ---- start (or restart) a round ----
play_init:
    lda #COL_SKY         ; in case we come from a black screen
    sta bg_top
    lda #COL_GRASS
    sta bg_bot
    jsr clear_screen
    jsr draw_road

    ; Copy static tree positions into dynamic arrays
    ldx #0
    ldy #0
pti_loop:
    lda tree_tbl,y
    sta t_row,x
    iny
    lda tree_tbl,y
    sta t_col,x
    iny
    inx
    cpx #NTREES
    bne pti_loop

    ; HUD: score on the left, miss slots on the right
    +prtext 0, 1, BLACK, txt_score, 5
    +prtext 0, 30, BLACK, txt_miss, 4

    lda #0
    sta score8
    sta sc_d0
    sta sc_d1
    sta sc_d2
    sta miss
    sta flash
    sta spawnt
    sta tree_timer
    sta lcnt
    sta rcnt
    sta p2lcnt
    sta p2rcnt
    jsr draw_score

    lda #0               ; draw_score leaves a digit code in A
    ldx #NRABBITS-1
pi_clr:
    sta r_act,x
    dex
    bpl pi_clr

    lda #2               ; start in the middle lane
    sta player_lane

    ; sprite colors back to red scooter + white rabbits
    ; (the title borrows sprites 1-4 as red scooters)
    ldx #7
pi_col:
    lda #WHITE
    sta SPR_COL,x
    dex
    bne pi_col
    lda #RED
    sta SPR_COL

    ; player sprite: scooter, fixed row, rabbits come per frame
    lda #SPRP_SCOOT
    sta SPRPTR
    lda #PLAYER_SY
    sta SPRPOS+1
    lda #1
    sta SPR_EN
    lda #0
    sta SPR_XEX
    sta SPR_YEX

    +setupd play_update
    rts

; ---- one frame of gameplay ----
play_update:
    jsr read_joy

    ; -- left: move on press, then auto-repeat while held --
    lda joyb
    and #JOY_LEFT
    beq pu_lrel
    inc lcnt
    lda lcnt
    cmp #1
    beq pu_lmove
    cmp #REP_HOLD+REP_PERIOD
    bne pu_lend
    lda #REP_HOLD
    sta lcnt
pu_lmove:
    lda player_lane
    beq pu_lend
    dec player_lane
    jmp pu_lend
pu_lrel:
    lda #0
    sta lcnt
pu_lend:

    ; -- right, same dance --
    lda joyb
    and #JOY_RIGHT
    beq pu_rrel
    inc rcnt
    lda rcnt
    cmp #1
    beq pu_rmove
    cmp #REP_HOLD+REP_PERIOD
    bne pu_rend
    lda #REP_HOLD
    sta rcnt
pu_rmove:
    lda player_lane
    cmp #LANES-1
    beq pu_rend
    inc player_lane
    jmp pu_rend
pu_rrel:
    lda #0
    sta rcnt
pu_rend:

    ; -- multiplayer: player 2 steers the closest rabbit --
    lda mp_mode
    beq pu_nop2
    jsr read_joy2
    lda joyb2
    and #JOY_LEFT
    beq pu_p2lrel
    inc p2lcnt
    lda p2lcnt
    cmp #1
    beq pu_p2lmove
    cmp #REP_HOLD+REP_PERIOD
    bne pu_p2lend
    lda #REP_HOLD
    sta p2lcnt
pu_p2lmove:
    lda #$ff             ; one lane to the left
    sta rtmp2
    jsr steer_closest
    jmp pu_p2lend
pu_p2lrel:
    lda #0
    sta p2lcnt
pu_p2lend:
    lda joyb2
    and #JOY_RIGHT
    beq pu_p2rrel
    inc p2rcnt
    lda p2rcnt
    cmp #1
    beq pu_p2rmove
    cmp #REP_HOLD+REP_PERIOD
    bne pu_p2rend
    lda #REP_HOLD
    sta p2rcnt
pu_p2rmove:
    lda #1               ; one lane to the right
    sta rtmp2
    jsr steer_closest
    jmp pu_p2rend
pu_p2rrel:
    lda #0
    sta p2rcnt
pu_p2rend:
pu_nop2:

    ; -- shadow init: player sprite bit + its x MSB --
    ldx player_lane
    lda pxlo,x
    sta SPRPOS           ; sprite 0 x
    lda pxhi,x
    sta msb_sh           ; lane 4 sits past x=255
    lda #0
    sta xex_sh
    sta yex_sh
    lda #1
    sta en_sh

    ; -- a hit blinks the scooter for a dozen frames --
    lda flash
    beq pu_noflash
    dec flash
    lda framectr
    and #4
    bne pu_noflash
    lda #0
    sta en_sh
pu_noflash:

    ; -- spawn: interval = 70 - score/2, floor 22 (as the original) --
    inc spawnt
    lda score8
    cmp #96
    bcc pu_ivcalc
    lda #22
    jmp pu_ivgot
pu_ivcalc:
    lsr
    sta rtmp
    lda #70
    sec
    sbc rtmp
pu_ivgot:
    cmp spawnt
    bcs pu_nospawn
    lda #0
    sta spawnt
    jsr spawn_rabbit
pu_nospawn:

    ; -- advance every live rabbit --
    ldx #NRABBITS-1
pu_rab:
    lda r_act,x
    beq pu_rnext
    lda r_tlo,x          ; t += speed (8.8 fixed point)
    clc
    adc r_splo,x
    sta r_tlo,x
    lda r_thi,x
    adc r_sphi,x
    sta r_thi,x
    bcc pu_ralive
    ; arrived at the player line
    lda #0
    sta r_act,x
    lda r_lane,x
    cmp player_lane
    beq pu_rhit
    jsr add_score        ; dodged: one point
    jmp pu_rnext
pu_rhit:
    jsr add_miss         ; ran into you
    jmp pu_rnext
pu_ralive:
    jsr rab_pos
pu_rnext:
    dex
    bpl pu_rab

    jsr write_shadows
    jsr animate_trees

    ; -- third miss ends the round --
    lda miss
    cmp #MAX_MISS
    bcc pu_done
    jmp over_init        ; its rts returns to the main loop
pu_done:
    rts

; ---- shift the closest live rabbit's lane by rtmp2 (+/-1) ----
steer_closest:
    ldx #$ff             ; best slot so far
    lda #0
    sta rtmp             ; best t so far
    ldy #NRABBITS-1
stc_find:
    lda r_act,y
    beq stc_next
    lda r_thi,y
    cmp rtmp
    bcc stc_next
    sta rtmp
    tya
    tax
stc_next:
    dey
    bpl stc_find
    cpx #$ff
    beq stc_done         ; no rabbit on the road
    lda r_lane,x
    clc
    adc rtmp2
    bmi stc_done         ; already on the leftmost lane
    cmp #LANES
    bcs stc_done         ; ... or the rightmost one
    sta r_lane,x
stc_done:
    rts

; ---- claim a free rabbit slot and roll its lane + speed ----
spawn_rabbit:
    ldx #NRABBITS-1
sr_find:
    lda r_act,x
    beq sr_got
    dex
    bpl sr_find
    rts                  ; every slot busy: skip this spawn
sr_got:
    lda #1
    sta r_act,x
    jsr rand5
    sta r_lane,x
    lda #0
    sta r_tlo,x
    sta r_thi,x
    ; speed = $0260 base + random byte + score ramp (tops out at 64)
    jsr rand8
    clc
    adc #$60
    sta rtmp
    lda #2
    adc #0
    sta rtmp2
    lda score8
    cmp #64
    bcc sr_ramp
    lda #64
sr_ramp:
    tay
    lda rtmp
    clc
    adc sptab_lo,y
    sta r_splo,x
    lda rtmp2
    adc sptab_hi,y
    sta r_sphi,x
    rts

; ---- animate roadside trees: scroll down + fan outward ----
animate_trees:
    inc tree_timer
    lda tree_timer
    cmp #TREE_SPEED
    bcs at_go
    rts
at_go:
    lda #0
    sta tree_timer

    ; Phase 1: erase all trees at current positions
    ldx #NTREES-1
at_erase:
    stx at_idx
    lda t_row,x
    sta trow
    lda t_col,x
    sta tcol
    jsr erase_tree
    ldx at_idx
    dex
    bpl at_erase

    ; Phase 2: update all positions
    ldx #NTREES-1
at_move:
    inc t_row,x
    lda t_col,x
    cmp #20
    bcs at_mright
    ; left side: move one column left
    lda t_col,x
    beq at_mresp
    dec t_col,x
    jmp at_mcheck
at_mright:
    ; right side: move one column right
    lda t_col,x
    cmp #37
    bcs at_mresp
    inc t_col,x
at_mcheck:
    lda t_row,x
    cmp #23
    bcc at_mnext
at_mresp:
    ; respawn near the horizon
    lda t_col,x
    cmp #20
    bcs at_mrespr
    ; left side: random col 10-13
    jsr rand8
    and #3
    clc
    adc #10
    sta t_col,x
    jmp at_mresprow
at_mrespr:
    ; right side: random col 24-27
    jsr rand8
    and #3
    clc
    adc #24
    sta t_col,x
at_mresprow:
    jsr rand8
    and #1
    clc
    adc #7
    sta t_row,x
at_mnext:
    dex
    bpl at_move

    ; Phase 3: redraw all trees at new positions
    ldx #NTREES-1
at_draw:
    stx at_idx
    lda t_row,x
    sta trow
    lda t_col,x
    sta tcol
    jsr draw_tree
    ldx at_idx
    dex
    bpl at_draw
at_done:
    rts

; ---- score: bump the decimal digits and the difficulty byte ----
add_score:
    lda score8
    cmp #$ff
    beq as_digits
    inc score8
as_digits:
    inc sc_d2
    lda sc_d2
    cmp #10
    bne draw_score
    lda #0
    sta sc_d2
    inc sc_d1
    lda sc_d1
    cmp #10
    bne draw_score
    lda #0
    sta sc_d1
    inc sc_d0
    lda sc_d0
    cmp #10
    bne draw_score
    lda #0
    sta sc_d0
; falls through: repaint the three HUD digits
draw_score:
    lda sc_d0
    ora #48              ; digit screen codes start at 48
    sta SCREEN+7
    lda sc_d1
    ora #48
    sta SCREEN+8
    lda sc_d2
    ora #48
    sta SCREEN+9
    rts

; ---- miss: X mark on the HUD + blink the scooter ----
add_miss:
    inc miss
    ldy miss             ; Y: the rabbit loop still needs X
    lda #24              ; 'x'
    sta SCREEN+34,y      ; marks land on columns 35-37
    lda #RED
    sta COLRAM+34,y
    lda #12
    sta flash
    rts

; ---- gameplay variables ----
player_lane: !byte 2
score8:      !byte 0     ; score capped at 255, drives the difficulty
sc_d0:       !byte 0     ; score digits: hundreds, tens, ones
sc_d1:       !byte 0
sc_d2:       !byte 0
miss:        !byte 0
flash:       !byte 0     ; frames left of the post-hit blink
spawnt:      !byte 0     ; frames since the last spawn
lcnt:        !byte 0     ; held-direction counters for the auto-repeat
rcnt:        !byte 0
p2lcnt:      !byte 0     ; the same for player 2's steering
p2rcnt:      !byte 0

; ---- dynamic tree state ----
t_row:      !fill NTREES, 0  ; current row of each tree
t_col:      !fill NTREES, 0  ; current column of each tree
tree_timer: !byte 0           ; frames since last tree scroll
at_idx:     !byte 0           ; animate_trees loop index

; ---- rabbit slots (hardware sprites 1-7) ----
r_act:  !fill NRABBITS, 0
r_lane: !fill NRABBITS, 0
r_tlo:  !fill NRABBITS, 0    ; distance along the lane, 8.8 fixed point
r_thi:  !fill NRABBITS, 0
r_splo: !fill NRABBITS, 0    ; per-rabbit speed, 8.8 fixed point
r_sphi: !fill NRABBITS, 0
