; -----------------------------------------------------------
; story.asm - the true story behind the game: a wild rabbit
; knocked over a scooter rider near Budapest (Százhalombatta)
; -----------------------------------------------------------

story_init:
    lda #BLACK
    sta bg_top
    sta bg_bot
    lda #0
    sta SPR_EN
    jsr clear_screen

    +prbig 1, 10, YELLOW, txt_story, 5

    +prtext  7, 9, LGREY, txt_st0, 21
    +prtext  9, 8, WHITE, txt_st1, 24
    +prtext 10, 6, WHITE, txt_st2, 28
    +prtext 12, 7, WHITE, txt_st3, 26
    +prtext 13, 9, WHITE, txt_st4, 22
    +prtext 15, 7, LGREEN, txt_st5, 25
    +prtext 16, 8, LGREEN, txt_st6, 24
    +prtext 18, 6, RED, txt_st7, 27
    +prtext 19, 8, RED, txt_st8, 23
    +prtext 21, 6, CYAN, txt_st9, 28

    +setupd story_update
    rts

story_update:
    ; blink the return prompt
    lda framectr
    and #32
    bne su_hide
    +prtext 23, 13, YELLOW, txt_return, 13
    jmp su_input
su_hide:
    +prtext 23, 13, YELLOW, txt_blank, 13
su_input:
    jsr start_edge
    beq su_done
    jmp menu_init
su_done:
    rts
