; -----------------------------------------------------------
; tables.asm - perspective and speed tables, generated at
; assembly time; t is the rabbit's distance (0 = horizon,
; 255 = the player's line)
; -----------------------------------------------------------

; feet y along the lane: linear from the horizon to the player
ytab:
!for i, 0, 255 {
    !byte 100 + (111*i) DIV 256
}

; horizontal fan-out on a t^2 curve (full offset of the outer
; lanes; the inner lanes use half of it)
offtab:
!for i, 0, 255 {
    !byte (107*i*i) DIV 65536
}

; hop wave, subtracted from the feet y (doubled for big rabbits)
hoptab:
    !byte 0, 1, 2, 4, 4, 3, 2, 1

; speed ramp: score (capped at 64) -> 16-bit speed bonus
sptab_lo:
!for i, 0, 64 {
    !byte <(i*13)
}
sptab_hi:
!for i, 0, 64 {
    !byte >(i*13)
}

; scooter sprite x per lane (lane center - 12); lane 4 crosses
; the 8-bit boundary, pxhi is its MSB flag
pxlo:
    !byte 66, 119, 172, 225, 22
pxhi:
    !byte 0, 0, 0, 0, 1

; rabbit slot -> sprite register offset (sprite = slot + 1)
sprxreg:
    !byte 2, 4, 6, 8, 10, 12, 14

; rabbit slot -> sprite enable/MSB/expand bit
sprbit:
    !byte 2, 4, 8, 16, 32, 64, 128
