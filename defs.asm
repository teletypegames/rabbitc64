; -----------------------------------------------------------
; defs.asm - hardware registers, constants, zero page, macros
; included first by main.asm
; -----------------------------------------------------------

; ---- hardware registers ----
RASTER  = $d012          ; current raster line
XCTRL   = $d016          ; horizontal fine scroll + 38/40 column mode
BORDER  = $d020          ; border color register
BG      = $d021          ; background color register
SCREEN  = $0400          ; screen RAM (40x25 chars)
COLRAM  = $d800          ; color RAM
SPRPTR  = $07f8          ; sprite pointers (screen RAM + $3f8)
CIA1_PA = $dc00          ; CIA1 port A: keyboard columns / joystick 2
CIA1_PB = $dc01          ; CIA1 port B: keyboard matrix row read
CIA1_TA = $dc04          ; CIA1 timer A low byte: free-running entropy

; ---- sprite registers ----
SPRPOS   = $d000         ; sprite 0 x; +1 = y, +2 = sprite 1 x, ...
SPR_MSBX = $d010         ; 9th bit of each sprite's x coordinate
SPR_EN   = $d015         ; sprite enable bits
SPR_YEX  = $d017         ; vertical expand
SPR_PRIO = $d01b         ; 1 = sprite behind the characters
SPR_MC   = $d01c         ; multicolor enable
SPR_XEX  = $d01d         ; horizontal expand
SPR_COL  = $d027         ; sprite 0 color, +1 = sprite 1, ...


; ---- SID registers (voice 1 used for SFX) ----
SID_V1FL = $d400         ; voice 1 frequency low
SID_V1FH = $d401         ; voice 1 frequency high
SID_V1PL = $d402         ; voice 1 pulse width low
SID_V1PH = $d403         ; voice 1 pulse width high
SID_V1CR = $d404         ; voice 1 control (waveform + gate)
SID_V1AD = $d405         ; voice 1 attack/decay
SID_V1SR = $d406         ; voice 1 sustain/release
SID_VOL  = $d418         ; filter mode + master volume

; ---- SFX IDs ----
SFX_SCORE  = 0           ; rabbit dodged: high pling
SFX_MISS   = 1           ; rabbit hit: noise crash
SFX_OVER   = 2           ; game over: descending sweep
SFX_CURSOR = 3           ; menu cursor move: click
SFX_SELECT = 4           ; menu fire: rising tone
NSFX       = 5

; ---- colors ----
BLACK   = 0
WHITE   = 1
RED     = 2
CYAN    = 3
GREEN   = 5
BLUE    = 6
YELLOW  = 7
ORANGE  = 8
BROWN   = 9
DGREY   = 11
MGREY   = 12
LGREEN  = 13
LBLUE   = 14
LGREY   = 15

; ---- scene palette ----
COL_SKY   = LBLUE        ; background above the horizon
COL_GRASS = GREEN        ; background below it
COL_ROAD  = MGREY        ; road surface (inverse-space fill)
COL_EDGE  = WHITE        ; painted road edge lines

; ---- joystick port 2 bits (after read_joy, active high) ----
JOY_LEFT  = 4
JOY_RIGHT = 8
JOY_FIRE  = 16

; ---- game constants ----
LANES     = 5
NRABBITS  = 7            ; rabbit slots, hardware sprites 1-7
MAX_MISS  = 3
ROAD_CX   = 184          ; road center in sprite x coordinates
PLAYER_SY = 200          ; scooter sprite top (feet on raster line 221)
T_BIG     = 112          ; rabbit distance where the big frames start
T_EXP     = 192          ; ... and where the sprite gets double-sized
REP_HOLD  = 12           ; frames before a held direction auto-repeats
REP_PERIOD = 6           ; frames between auto-repeat steps
TREE_SPEED = 3           ; frames between tree scroll steps
NTREES    = 6            ; roadside trees per side-pair
RAS_SYNC  = 251          ; raster line polled for the frame sync
RAS_SPLIT = 97           ; horizon line: sky/grass background split

; ---- zero page pointers (same slots as the c64-demo) ----
txtlo  = $f5             ; text pointer for the print routines (2 bytes)
txthi  = $f6
updvec = $f9             ; state update vector (2 bytes)
scrlo  = $fb
scrhi  = $fc
collo  = $fd
colhi  = $fe

; ---- helper macros: print a normal / big text line ----
!macro prtext .row, .col, .color, .txt, .len {
    lda #<.txt
    sta txtlo
    lda #>.txt
    sta txthi
    lda #.row
    sta prow
    lda #.col
    sta pcol
    lda #.color
    sta pcolor
    lda #.len
    sta plen
    jsr print_text
}

!macro prbig .row, .col, .color, .txt, .len {
    lda #<.txt
    sta txtlo
    lda #>.txt
    sta txthi
    lda #.row
    sta bigrow
    lda #.col
    sta bigcol
    lda #.color
    sta bigcolor
    lda #.len
    sta biglen
    jsr draw_big
}

; ---- set the state update vector ----
!macro setupd .addr {
    lda #<.addr
    sta updvec
    lda #>.addr
    sta updvec+1
}
