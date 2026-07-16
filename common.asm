; -----------------------------------------------------------
; common.asm - routines shared by the states: screen drawing,
; text printing, input, RNG and the rabbit sprite positioning
; -----------------------------------------------------------

; ---- clear screen RAM, fill color RAM with black ----
clear_screen:
    ldx #0
cls_loop:
    lda #$20             ; space
    sta SCREEN,x
    sta SCREEN+$100,x
    sta SCREEN+$200,x
    sta SCREEN+$2e8,x
    lda #BLACK
    sta COLRAM,x
    sta COLRAM+$100,x
    sta COLRAM+$200,x
    sta COLRAM+$2e8,x
    inx
    bne cls_loop
    rts

; ---- print a text line: txtlo/hi, prow, pcol, pcolor, plen ----
print_text:
    ldx prow
    lda mul40lo,x
    clc
    adc pcol
    sta scrlo
    sta collo
    lda mul40hi,x
    adc #>SCREEN         ; carry still valid from the low-byte add
    sta scrhi
    clc
    adc #$d4             ; COLRAM - SCREEN high byte distance
    sta colhi
    ldy #0
pt_loop:
    lda (txtlo),y
    sta (scrlo),y
    lda pcolor
    sta (collo),y
    iny
    cpy plen
    bne pt_loop
    rts

; ---- set scrlo/hi + collo/hi to the start of char row X ----
row_ptr:
    lda mul40lo,x
    sta scrlo
    sta collo
    lda mul40hi,x
    clc
    adc #>SCREEN
    sta scrhi
    clc
    adc #$d4             ; COLRAM - SCREEN high byte distance
    sta colhi
    rts

; ---- the road: grey surface between two painted edge lines,
; from the horizon apex down to the screen corners, then the
; trees along both shoulders ----
draw_road:
    ldx #0
dr_loop:
    stx drtmp
    jsr road_row
    ldx drtmp
    inx
    cpx #19
    bne dr_loop
    jmp draw_trees

; ---- redraw road row drtmp (0-18, char row 6+drtmp):
; edge chars + grey fill; also erases text printed over it ----
road_row:
    lda drtmp
    clc
    adc #6               ; road runs from char row 6 to row 24
    tax
    jsr row_ptr
    ldx drtmp            ; use perspective curve for the edge offset
    lda #19
    sec
    sbc road_off,x
    tay
    sty drleft
    lda #$4e             ; '/' diagonal
    sta (scrlo),y
    lda #COL_EDGE
    sta (collo),y
    lda #20
    clc
    adc road_off,x
    tay
    lda #$4d             ; '\' diagonal
    sta (scrlo),y
    lda #COL_EDGE
    sta (collo),y
    dey                  ; fill the surface between the edges
rr_fill:
    cpy drleft
    beq rr_done
    lda #$a0             ; inverse space: solid block
    sta (scrlo),y
    lda #COL_ROAD
    sta (collo),y
    dey
    jmp rr_fill
rr_done:
    rts

; ---- the roadside trees ----
draw_trees:
    lda #0
    sta ttidx
dt_loop:
    ldx ttidx
    lda tree_tbl,x
    sta trow
    lda tree_tbl+1,x
    sta tcol
    jsr draw_tree
    inc ttidx
    inc ttidx
    lda ttidx
    cmp #NTREES*2
    bne dt_loop
    rts

; ---- one tree: crown of balls on trow, top ball above,
; trunk below (trow/tcol = middle row, left column) ----
draw_tree:
    ldx trow
    dex
    jsr row_ptr
    ldy tcol
    iny
    jsr tree_ball
    ldx trow
    jsr row_ptr
    ldy tcol
    jsr tree_ball
    iny
    jsr tree_ball
    iny
    jsr tree_ball
    ldx trow
    inx
    jsr row_ptr
    ldy tcol
    iny
    lda #$5d             ; trunk
    sta (scrlo),y
    lda #BROWN
    sta (collo),y
    rts

; ---- erase one tree (write spaces at trow/tcol positions) ----
erase_tree:
    ldx trow
    dex
    jsr row_ptr
    ldy tcol
    iny
    lda #$20
    sta (scrlo),y
    ldx trow
    jsr row_ptr
    ldy tcol
    lda #$20
    sta (scrlo),y
    iny
    sta (scrlo),y
    iny
    sta (scrlo),y
    ldx trow
    inx
    jsr row_ptr
    ldy tcol
    iny
    lda #$20
    sta (scrlo),y
    rts

tree_ball:
    lda #$51             ; foliage ball
    sta (scrlo),y
    lda #LGREEN
    sta (collo),y
    rts

tree_tbl:                ; middle row, left column - far trees sit
    !byte  9,  4         ;   higher and closer to the road
    !byte 14,  6
    !byte 18,  2
    !byte  8, 31
    !byte 12, 34
    !byte 17, 36

; ---- input ----

; read joystick port 2 merged with the a/d keys,
; return active-high bits in A and joyb
read_joy:
    lda #$ff             ; deselect every keyboard column first
    sta CIA1_PA
    lda CIA1_PA
    eor #$ff
    and #$1f
    sta joyb
    lda #$fd             ; 'a' = left: keyboard column 1, row bit 2
    sta CIA1_PA
    lda CIA1_PB
    and #$04
    bne rj_noleft
    lda joyb
    ora #JOY_LEFT
    sta joyb
rj_noleft:
    lda #$fb             ; 'd' = right: keyboard column 2, row bit 2
    sta CIA1_PA
    lda CIA1_PB
    and #$04
    bne rj_noright
    lda joyb
    ora #JOY_RIGHT
    sta joyb
rj_noright:
    lda joyb
    rts

; read joystick port 1 merged with the j/l keys (player 2),
; return active-high bits in A and joyb2
read_joy2:
    lda #$ff             ; no column selected: port B = joystick 1
    sta CIA1_PA
    lda CIA1_PB
    eor #$ff
    and #$1f
    sta joyb2
    and #$0f             ; a held direction grounds the same port B
    bne rj2_done         ;   lines the key rows use: skip the scan
    lda #$ef             ; 'j' = left: keyboard column 4, row bit 2
    sta CIA1_PA
    lda CIA1_PB
    and #$04
    bne rj2_noleft
    lda joyb2
    ora #JOY_LEFT
    sta joyb2
rj2_noleft:
    lda #$df             ; 'l' = right: keyboard column 5, row bit 2
    sta CIA1_PA
    lda CIA1_PB
    and #$04
    bne rj2_done
    lda joyb2
    ora #JOY_RIGHT
    sta joyb2
rj2_done:
    lda joyb2
    rts

; fire on either stick or space held? returns A != 0 when pressed
start_pressed:
    jsr read_joy
    and #JOY_FIRE
    bne sp_done
    lda #$ff             ; deselect the columns: port B = joystick 1
    sta CIA1_PA
    lda CIA1_PB
    eor #$ff
    and #JOY_FIRE
    bne sp_done
    lda #$7f             ; space: keyboard column 7, row bit 4
    sta CIA1_PA
    lda CIA1_PB
    and #$10
    eor #$10
sp_done:
    rts

; edge-detected start: A = 1 only on the frame fire/space goes down
start_edge:
    jsr start_pressed
    beq se_up
    lda fheld
    bne se_no
    lda #1
    sta fheld
    rts                  ; A = 1: fresh press
se_up:
    lda #0
    sta fheld
se_no:
    lda #0
    rts

; ---- RNG: 8-bit LFSR stirred with the free-running CIA timer
; (the timer counts every cycle, so call timing = entropy) ----
rand8:
    lda seed
    asl
    bcc r8_tap
    eor #$1d
r8_tap:
    eor CIA1_TA
    sta seed
    rts

; random lane 0-4
rand5:
    jsr rand8
    and #7
    cmp #LANES
    bcs rand5            ; every retry steps the LFSR, so it terminates
    rts

; ---- write the per-frame sprite register shadows ----
write_shadows:
    lda en_sh
    sta SPR_EN
    lda msb_sh
    sta SPR_MSBX
    lda xex_sh
    sta SPR_XEX
    lda yex_sh
    sta SPR_YEX
    rts

; ============================================================
; rab_pos - place rabbit slot X on hardware sprite X+1
;   reads r_thi/r_lane, picks size stage + hop frame, writes
;   the position registers and ORs the shadow bits; keeps X
; ============================================================
rab_pos:
    stx rslot
    lda r_thi,x
    sta rt
    lda r_lane,x
    sta rlane

    ; hop offset: 8-entry wave, one hop per 64 t units
    lda rt
    lsr
    lsr
    lsr
    and #7
    tay
    lda hoptab,y
    sta rhop

    ; animation frame 0-3
    lda rt
    lsr
    lsr
    lsr
    lsr
    and #3
    sta rfrm

    lda #0
    sta rexp
    lda rt
    cmp #T_BIG
    bcs rp_big
    ; -- far: small frames --
    lda #SPRP_SMALL
    clc
    adc rfrm
    sta rptr
    lda #12
    sta ranchor
    jmp rp_y
rp_big:
    ; -- near: big frames, stronger hop --
    lda #SPRP_BIG
    clc
    adc rfrm
    sta rptr
    asl rhop
    lda #12
    sta ranchor
    lda rt
    cmp #T_EXP
    bcc rp_y
    ; -- closest: the same frames double-sized --
    lda #1
    sta rexp
    lda #24
    sta ranchor
rp_y:
    ; sprite y: feet ride the perspective line (art bottom row)
    ldy rt
    lda ytab,y
    sec
    sbc rhop
    sec
    sbc #21
    ldx rexp
    beq rp_ydone
    sec
    sbc #21              ; expanded sprite is 42 tall
rp_ydone:
    sta ry

    ; x center = ROAD_CX +/- lane offset on the t^2 curve
    ldy rt
    lda offtab,y
    sta roff
    lda #ROAD_CX
    sta rxlo
    lda #0
    sta rxhi
    ldy rlane
    cpy #2
    beq rp_xdone         ; middle lane: stay on the center line
    bcs rp_right
    lda roff             ; lanes 0-1: left of center
    cpy #1
    bne rp_lfull
    lsr                  ; lane 1 fans out half as far
rp_lfull:
    sta rtmp
    lda rxlo
    sec
    sbc rtmp             ; max offset is 107, never underflows
    sta rxlo
    jmp rp_xdone
rp_right:
    lda roff             ; lanes 3-4: right of center
    cpy #3
    bne rp_rfull
    lsr
rp_rfull:
    sta rtmp
    lda rxlo
    clc
    adc rtmp
    sta rxlo
    lda rxhi
    adc #0
    sta rxhi
rp_xdone:
    ; sprite left edge = center - anchor (16 bit)
    lda rxlo
    sec
    sbc ranchor
    sta rxlo
    lda rxhi
    sbc #0
    sta rxhi

    ; ---- write the hardware registers + shadow bits ----
    ldx rslot
    ldy sprxreg,x
    lda rxlo
    sta SPRPOS,y
    lda ry
    sta SPRPOS+1,y
    lda rptr
    sta SPRPTR+1,x
    lda sprbit,x
    ora en_sh
    sta en_sh
    lda rxhi
    beq rp_nomsb
    lda sprbit,x
    ora msb_sh
    sta msb_sh
rp_nomsb:
    lda rexp
    beq rp_done
    lda sprbit,x
    ora xex_sh
    sta xex_sh
    lda sprbit,x
    ora yex_sh
    sta yex_sh
rp_done:
    rts

; ---- draw a text line with big 3x5 block letters ----
; txtlo/hi = text (screen codes), bigrow/bigcol = top-left cell,
; bigcolor = color, biglen = char count; each letter is 3 cells
; wide + 1 gap, 5 cells tall
draw_big:
    lda #0
    sta bigi
db_char:
    ldy bigi
    lda (txtlo),y
    cmp #$20             ; space: leave the cell empty
    beq db_next
    tax
    lda bigmap,x         ; screen code -> glyph index
    sta glyphbase
    asl                  ; glyph base = index * 5
    asl
    clc
    adc glyphbase
    sta glyphbase
    lda bigi             ; cell x = bigcol + charindex * 4
    asl
    asl
    clc
    adc bigcol
    sta charx
    lda #0
    sta rowidx
db_row:
    lda bigrow           ; row pointers from the row*40 tables
    clc
    adc rowidx
    tax
    lda mul40lo,x
    sta scrlo
    sta collo
    lda mul40hi,x
    clc
    adc #>SCREEN
    sta scrhi
    clc
    adc #$d4
    sta colhi
    lda glyphbase
    clc
    adc rowidx
    tax
    lda bigglyphs,x
    asl                  ; 3-bit pattern up to bits 7-5
    asl
    asl
    asl
    asl
    sta curbits
    ldy charx
    lda #3
    sta bitcnt
db_bit:
    asl curbits          ; leftmost pixel first
    bcc db_nobit
    lda #$a0             ; inverse space = solid block
    sta (scrlo),y
    lda bigcolor
    sta (collo),y
db_nobit:
    iny
    dec bitcnt
    bne db_bit
    inc rowidx
    lda rowidx
    cmp #5
    bne db_row
db_next:
    inc bigi
    lda bigi
    cmp biglen
    beq db_done
    jmp db_char          ; too far for a relative branch
db_done:
    rts

; ---- shared tables ----

; row * 40 lookup tables (25 rows)
mul40lo:
    !byte $00, $28, $50, $78, $a0, $c8, $f0, $18, $40, $68
    !byte $90, $b8, $e0, $08, $30, $58, $80, $a8, $d0, $f8
    !byte $20, $48, $70, $98, $c0
mul40hi:
    !byte $00, $00, $00, $00, $00, $00, $00, $01, $01, $01
    !byte $01, $01, $01, $02, $02, $02, $02, $02, $02, $02
    !byte $03, $03, $03, $03, $03

; 3x5 block font for the big title (5 bytes per glyph,
; low 3 bits used, MSB side = left)
bigglyphs:
    !byte 0, 0, 0, 0, 0          ;  0 space
    !byte 2, 5, 7, 5, 5          ;  1 A
    !byte 3, 4, 4, 4, 3          ;  2 C
    !byte 6, 5, 5, 5, 6          ;  3 D
    !byte 7, 4, 6, 4, 7          ;  4 E
    !byte 7, 4, 6, 4, 4          ;  5 F
    !byte 7, 2, 2, 2, 7          ;  6 I
    !byte 4, 4, 4, 4, 7          ;  7 L
    !byte 5, 7, 7, 5, 5          ;  8 M
    !byte 6, 5, 5, 5, 5          ;  9 N
    !byte 7, 5, 5, 5, 7          ; 10 O
    !byte 6, 5, 6, 4, 4          ; 11 P
    !byte 6, 5, 6, 5, 5          ; 12 R
    !byte 3, 4, 2, 1, 6          ; 13 S
    !byte 7, 2, 2, 2, 2          ; 14 T
    !byte 5, 5, 2, 2, 2          ; 15 Y
    !byte 3, 4, 5, 5, 7          ; 16 G
    !byte 6, 5, 6, 5, 6          ; 17 B
    !byte 5, 5, 5, 5, 2          ; 18 V

bigmap:                  ; screen code (a=1..z=26) -> glyph index
    !byte  0             ; (unused)
    !byte  1, 17,  2,  3,  4,  5, 16,  0,  6,  0   ; a-j
    !byte  0,  7,  8,  9, 10, 11,  0, 12, 13, 14   ; k-t
    !byte  0, 18,  0,  0, 15,  0                   ; u-z

; ---- texts (screen codes) ----
txt_score:   !scr "score"
txt_miss:    !scr "miss"
txt_rabbit:  !scr "rabbit"
txt_scooter: !scr "scooter"
txt_1p:      !scr "single player"
txt_2p:      !scr "multiplayer"
txt_credits: !scr "credits"
txt_crew0:   !scr "mr.zero - tasnadi zsolt"
txt_crew1:   !scr "mr.one - tari balazs"
txt_crew2:   !scr "mr.two - timar zoltan"
txt_crew3:   !scr "mr.three - mezo bela"
txt_ai1:     !scr "warning: this game was"
txt_ai2:     !scr "written by an ai"
txt_info:    !scr "p1: joystick 2 or a/d"
txt_info2:   !scr "p2: joystick 1 or j/l"
txt_ttgname: !scr "teletype games"
txt_presents:!scr "presents"
txt_vs:      !scr "vs"
txt_over:    !scr "game over"
txt_return:  !scr "fire = return"
txt_blank:   !fill 19, $20

washtbl:                 ; gold glow ramp (16 entries, cyclic)
    !byte $09, $02, $08, $0a, $07, $07, $01, $01
    !byte $01, $01, $07, $07, $0a, $08, $02, $09

; ---- shared variables ----
framectr:  !byte 0       ; frame counter, incremented by the main loop
washphase: !byte 0       ; gold wash offset on the intro letters
bg_top:    !byte COL_SKY ; background color above / below the
bg_bot:    !byte COL_GRASS   ; horizon raster split
seed:      !byte $a7     ; rand8 LFSR state
fheld:     !byte 0       ; fire/space edge detection state
joyb:      !byte 0       ; player 1 input bits from read_joy
joyb2:     !byte 0       ; player 2 input bits from read_joy2
mp_mode:   !byte 0       ; 0 = single player, 1 = multiplayer
k12held:   !byte 0       ; menu '1'/'2' key edge detection state
en_sh:     !byte 0       ; per-frame sprite register shadows
msb_sh:    !byte 0
xex_sh:    !byte 0
yex_sh:    !byte 0
prow:      !byte 0       ; print_text: row, column, color, length
pcol:      !byte 0
pcolor:    !byte 0
plen:      !byte 0
bigrow:    !byte 0       ; draw_big: row, column, color, length
bigcol:    !byte 0
bigcolor:  !byte 0
biglen:    !byte 0
bigi:      !byte 0       ; draw_big internals
glyphbase: !byte 0
charx:     !byte 0
rowidx:    !byte 0
bitcnt:    !byte 0
curbits:   !byte 0
drtmp:     !byte 0       ; draw_road internals
drleft:    !byte 0
ttidx:     !byte 0       ; draw_trees internals
trow:      !byte 0
tcol:      !byte 0
rslot:     !byte 0       ; rab_pos internals
rt:        !byte 0
rlane:     !byte 0
rhop:      !byte 0
rfrm:      !byte 0
rexp:      !byte 0
rptr:      !byte 0
ranchor:   !byte 0
roff:      !byte 0
rxlo:      !byte 0
rxhi:      !byte 0
ry:        !byte 0
rtmp:      !byte 0
rtmp2:     !byte 0
