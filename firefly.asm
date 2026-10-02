; FIREFLY - Atari 2600 proof of concept
; Title screen + collect-the-embers gameplay with score
;
; Controls:
;   Title: Press FIRE to start
;   Game: Joystick moves firefly, collect blinking embers for +1 each

    processor 6502

; ==================== TIA Registers ====================
VSYNC   = $00
VBLANK  = $01
WSYNC   = $02
NUSIZ0  = $04
COLUP0  = $06
COLUP1  = $07
COLUPF  = $08
COLUBK  = $09
CTRLPF  = $0A
PF0     = $0D
PF1     = $0E
PF2     = $0F
RESP0   = $10
RESP1   = $11
RESM0   = $12
RESBL   = $14
GRP0    = $1B
GRP1    = $1C
ENAM0   = $1D
ENABL   = $1F
AUDC0   = $15
AUDF0   = $17
AUDV0   = $19
HMP0    = $20
HMP1    = $21
HMM0    = $22
HMBL    = $24
HMOVE   = $2A
HMCLR   = $2B
CXCLR   = $2C
INPT4   = $0C
SWCHA   = $0280
INTIM   = $0284
TIM64T  = $0296

; ==================== Zero Page ====================
State       = $80    ; 0=title, 1=game
FrameCnt    = $81
FireX       = $82    ; firefly X (0-159)
FireY       = $83    ; firefly Y (0-151)
Glow        = $84    ; 0=dim, 1=bright
TP          = $85    ; text pointer (2 bytes: $85-$86)
Score       = $87    ; BCD score 00-99
EmberX      = $88    ; collectible X
EmberY      = $89    ; collectible Y
Rand        = $8A    ; RNG state (nonzero)
ScoreP0     = $8B    ; tens digit pointer (2 bytes)
ScoreP1     = $8D    ; ones digit pointer (2 bytes)
SfxT        = $8F    ; collect sound timer (0=off)
MusT        = $90    ; start jingle timer (0=off)

; ==================== Code ====================
    ORG $F000

Start:
    sei
    cld
    ldx #$FF
    txs
    ; clear TIA (CRITICAL: use lda #0, NOT txa!)
    ldx #$2C
    lda #0
ClearTia:
    sta $00,x
    dex
    bpl ClearTia
    ; clear RAM
    ldx #0
    txa
ClearRam:
    sta $80,x
    inx
    cpx #$80
    bne ClearRam
    ; init
    lda #80
    sta FireX
    lda #76
    sta FireY
    lda #1
    sta Glow
    lda #0
    sta Score
    lda #$A5
    sta Rand
    lda #$20
    sta NUSIZ0          ; missile 0 = 4px wide
    jsr NewEmber
    jmp MainLoop

; ==================== Main Loop ====================
MainLoop:
    lda State
    bne ToGame
    jmp TitleFrame
ToGame:
    jmp GameFrame

; ==================== VSYNC (3 lines) ====================
VSYNC3:
    sta WSYNC           ; align to scanline start so VSYNC fires at cycle 0
    lda #2
    sta VSYNC
    sta WSYNC
    sta WSYNC
    sta WSYNC
    lda #0
    sta VSYNC
    rts

; ==================== Position Object ====================
; A = x (0-159). X variants store to different HMxx/RESxx.
PosXGen:
    sta WSYNC
    sec
Div15:
    sbc #15
    bcs Div15
    eor #7
    asl
    asl
    asl
    asl
    rts                 ; caller stores A to HMxx then RESxx

; Position P0 (tens digit of score)
PosXP0:
    jsr PosXGen
    sta HMP0
    sta RESP0
    rts

; Position P1 (ones digit of score)
PosXP1:
    jsr PosXGen
    sta HMP1
    sta RESP1
    rts

; Position missile 0 (ember)
PosXM0:
    jsr PosXGen
    sta HMM0
    sta RESM0
    rts

; Position ball (firefly)
PosXBall:
    jsr PosXGen
    sta HMBL
    sta RESBL
    rts

; ==================== Blank Lines ====================
; X = count
BlankLines:
    cpx #0
    beq BLDone
BLLoop:
    sta WSYNC
    dex
    bne BLLoop
BLDone:
    rts

; ==================== RNG ====================
; 8-bit LFSR, returns random byte in A, updates Rand
Rand8:
    lda Rand
    asl
    bcc RandDone
    eor #$B4
RandDone:
    sta Rand
    rts

; Place ember at random position inside walls
NewEmber:
    jsr Rand8
    and #$7F
    clc
    adc #12             ; X: 12..139
    sta EmberX
    jsr Rand8
    and #$7F
    clc
    adc #12             ; Y: 12..139
    sta EmberY
    rts

; ==================== Text12 ====================
; Draw 12 lines of text from (TP). 72 bytes total (6 bytes/row).
; Non-reflect 40-bit playfield: left PF0,PF1,PF2 then right PF0,PF1,PF2.
; Cycle-timed: each PF write must land BEFORE the beam draws that section.
;   L-PF0 @clk26 (draw 68), L-PF1 @clk57 (draw 84), L-PF2 @clk90 (draw 116),
;   R-PF0 @clk123 (draw 148), R-PF1 @clk156 (draw 164), R-PF2 @clk189 (draw 196).
Text12:
    ldy #0
    ldx #12
Text12Loop:
    sta WSYNC
    lda (TP),y
    sta PF0
    iny
    lda (TP),y
    sta PF1
    iny
    lda (TP),y
    sta PF2
    iny
    lda (TP),y
    sta PF0
    iny
    lda (TP),y
    sta PF1
    iny
    lda (TP),y
    sta PF2
    iny
    dex
    bne Text12Loop
    rts

; ==================== TITLE FRAME ====================
TitleFrame:
    jsr VSYNC3
    ; VBLANK (37 lines)
    lda #2
    sta VBLANK
    lda #43
    sta TIM64T
    lda #0
    sta PF0
    sta PF1
    sta PF2
    sta GRP0
    sta ENABL
    lda #$00
    sta COLUBK          ; black background
    lda #$0E
    sta COLUPF          ; white text
    lda #0
    sta AUDV0           ; mute audio on title
    ; position ball for firefly glow
    lda #80
    jsr PosXBall
    sta WSYNC
    sta HMOVE
TitleVbw:
    sta WSYNC
    lda INTIM
    bne TitleVbw
    lda #0
    sta VBLANK
    ; Kernel (192 lines)
    ldx #40
    jsr BlankLines
    ; "FIREFLY" text
    lda #<TextFire
    sta TP
    lda #>TextFire
    sta TP+1
    jsr Text12
    lda #0
    sta PF0
    sta PF1
    sta PF2
    ldx #20
    jsr BlankLines
    ; glowing dot (ball, 16 lines)
    lda #$30
    sta CTRLPF          ; 8px ball
    lda #$1E
    sta COLUPF          ; yellow
    ldx #16
TitleDot:
    sta WSYNC
    lda FrameCnt
    and #$08
    beq DotOff
    lda #2
    sta ENABL
    jmp DotNext
DotOff:
    lda #0
    sta ENABL
DotNext:
    dex
    bne TitleDot
    lda #0
    sta ENABL
    ldx #24
    jsr BlankLines
    ; "PRESS FIRE" blink
    lda FrameCnt
    and #$20
    beq TitleNoPress
    lda #<TextPress
    sta TP
    lda #>TextPress
    sta TP+1
    lda #$0E
    sta COLUPF
    jsr Text12
    lda #0
    sta PF0
    sta PF1
    sta PF2
    jmp TitleDone
TitleNoPress:
    ldx #12
    jsr BlankLines
TitleDone:
    ldx #68
    jsr BlankLines
    ; Overscan (30 lines)
    lda #2
    sta VBLANK
    lda #35
    sta TIM64T
    inc FrameCnt
    ; check fire button (INPT4: bit set = not pressed)
    lda INPT4
    and #$80
    bne TitleOsw
    lda #1
    sta State
    lda #30
    sta MusT            ; trigger start jingle
TitleOsw:
    sta WSYNC
    lda INTIM
    bne TitleOsw
    jmp MainLoop

; ==================== GAME FRAME ====================
GameFrame:
    jsr VSYNC3
    ; VBLANK (37 lines)
    lda #2
    sta VBLANK
    lda #43
    sta TIM64T
    lda #0
    sta PF0
    sta PF1
    sta PF2
    sta GRP0
    sta GRP1
    sta ENABL
    sta ENAM0
    sta HMCLR
    lda #$00
    sta COLUBK          ; BLACK background
    lda #$31
    sta CTRLPF          ; reflect playfield + 8px ball
    lda #$1E
    sta COLUPF          ; yellow (walls + firefly)
    sta COLUP0          ; yellow ember (missile 0 uses player 0 color)
    sta COLUP1
    ; ---- read joystick ----
    lda SWCHA
    and #$10            ; Up
    bne NotUp
    lda FireY
    beq NotUp
    dec FireY
NotUp:
    lda SWCHA
    and #$20            ; Down
    bne NotDown
    lda FireY
    cmp #152
    bcs NotDown
    inc FireY
NotDown:
    lda SWCHA
    and #$40            ; Left
    bne NotLeft
    lda FireX
    cmp #1
    bcc NotLeft
    dec FireX
NotLeft:
    lda SWCHA
    and #$80            ; Right
    bne NotRight
    lda FireX
    cmp #140
    bcs NotRight
    inc FireX
NotRight:
    ; safety: if FireX ever wraps/invalid (>160), reset to center
    lda FireX
    cmp #161
    bcc NoWrapFix
    lda #80
    sta FireX
    lda #76
    sta FireY
NoWrapFix:
    ; ---- collision: firefly vs ember ----
    lda FireX
    sec
    sbc EmberX
    bcs CXPos
    eor #$FF
    clc
    adc #1
CXPos:
    cmp #9
    bcs NoHit
    lda FireY
    sec
    sbc EmberY
    bcs CYPos
    eor #$FF
    clc
    adc #1
CYPos:
    cmp #11
    bcs NoHit
    ; collect! score+1 (BCD), respawn ember, play sound
    sed
    clc
    lda Score
    adc #1
    cld
    sta Score
    jsr NewEmber
    lda #12
    sta SfxT            ; trigger collect blip
NoHit:
    ; ---- score digit pointers (tens*8, ones*8 into Digits) ----
    lda Score
    and #$F0
    lsr
    lsr
    lsr
    lsr
    asl
    asl
    asl
    clc
    adc #<Digits
    sta ScoreP0
    lda #>Digits
    adc #0
    sta ScoreP0+1
    lda Score
    and #$0F
    asl
    asl
    asl
    clc
    adc #<Digits
    sta ScoreP1
    lda #>Digits
    adc #0
    sta ScoreP1+1
    ; ---- position objects ----
    lda FireX
    jsr PosXBall        ; firefly
    lda EmberX
    jsr PosXM0          ; ember
    lda #68
    jsr PosXP0          ; score tens digit
    lda #76
    jsr PosXP1          ; score ones digit
    sta WSYNC
    sta HMOVE
    ; ---- audio: collect blip (priority) or start jingle ----
    lda SfxT
    beq TryMus
    lda #$04
    sta AUDC0           ; pure tone
    lda SfxT
    sta AUDF0           ; pitch rises as timer counts down
    lda #$08
    sta AUDV0
    dec SfxT
    jmp AudioDone
TryMus:
    lda MusT
    beq MuteAudio
    lda #$04
    sta AUDC0
    lda MusT
    cmp #21
    bcs MusN0
    cmp #11
    bcs MusN1
    lda #8              ; note 2 (high)
    jmp MusPlay
MusN0:
    lda #20             ; note 0 (low)
    jmp MusPlay
MusN1:
    lda #14             ; note 1 (mid)
MusPlay:
    sta AUDF0
    lda #$08
    sta AUDV0
    dec MusT
    jmp AudioDone
MuteAudio:
    lda #0
    sta AUDV0
AudioDone:
GameVbw:
    sta WSYNC
    lda INTIM
    bne GameVbw
    lda #0
    sta VBLANK
    ; ==================== Kernel (192 lines) ====================
    ; Score: 8 lines (score mode; set all player/pf colors white
    ; so digits show regardless of which color source score mode uses)
    lda #2
    sta CTRLPF          ; score mode
    lda #$0E
    sta COLUPF          ; white digits
    sta COLUP0
    sta COLUP1
    ldy #0
ScoreLp:
    sta WSYNC
    lda (ScoreP0),y
    sta GRP0
    lda (ScoreP1),y
    sta GRP1
    iny
    cpy #8
    bne ScoreLp
    lda #0
    sta GRP0
    sta GRP1
    lda #$31
    sta CTRLPF          ; reflect + 8px ball
    lda #$1E
    sta COLUPF          ; yellow walls
    sta COLUP0          ; yellow ember
    ; Top wall (8 lines) - full width
    lda #$FF
    sta PF0
    sta PF1
    sta PF2
    ldx #8
TopWall:
    sta WSYNC
    dex
    bne TopWall
    ; Middle (168 lines) - side walls only
    lda #$10            ; 4px on each side (with reflect)
    sta PF0
    lda #0
    sta PF1
    sta PF2
    ; draw ball (16 lines) and ember (8 lines) in Y order
    lda FireY
    cmp EmberY
    bcc BallFirst
    ; ---- ember first (FireY >= EmberY) ----
    ldx EmberY
    jsr BlankLines
    jsr EmberBlock        ; 8 lines -> Y = EmberY+8
    lda FireY
    sec
    sbc EmberY
    sbc #8                ; gap = FireY-EmberY-8
    bcs Gap1Ok
    lda #0
Gap1Ok:
    tax
    jsr BlankLines        ; Y = max(FireY, EmberY+8)
    jsr BallBlock         ; 16 lines
    ; rest = 168-16-max(FireY, EmberY+8); overlap if FireY < EmberY+8
    lda FireY
    sec
    sbc EmberY
    cmp #8
    bcs NoOv1
    lda #144              ; overlap: 168-16-(EmberY+8) = 144-EmberY
    sec
    sbc EmberY
    tax
    jsr BlankLines
    jmp MidDone
NoOv1:
    lda #152              ; no overlap: 168-16-FireY
    sec
    sbc FireY
    tax
    jsr BlankLines
    jmp MidDone
BallFirst:
    ldx FireY
    jsr BlankLines
    jsr BallBlock         ; 16 lines -> Y = FireY+16
    lda EmberY
    sec
    sbc FireY
    sbc #16               ; gap = EmberY-FireY-16
    bcs Gap2Ok
    lda #0
Gap2Ok:
    tax
    jsr BlankLines        ; Y = max(EmberY, FireY+16)
    jsr EmberBlock        ; 8 lines
    ; rest = 168-8-max(EmberY, FireY+16); overlap if EmberY < FireY+16
    lda EmberY
    sec
    sbc FireY
    cmp #16
    bcs NoOv2
    lda #144              ; overlap: 168-8-(FireY+16) = 144-FireY
    sec
    sbc FireY
    tax
    jsr BlankLines
    jmp MidDone
NoOv2:
    lda #160              ; no overlap: 168-8-EmberY
    sec
    sbc EmberY
    tax
    jsr BlankLines
MidDone:
    ; Bottom wall (8 lines) - full width
    lda #$FF
    sta PF0
    sta PF1
    sta PF2
    ldx #8
BotWall:
    sta WSYNC
    dex
    bne BotWall
    lda #0
    sta PF0
    sta PF1
    sta PF2
    ; Overscan (30 lines)
    lda #2
    sta VBLANK
    lda #35
    sta TIM64T
    inc FrameCnt
GameOsw:
    sta WSYNC
    lda INTIM
    bne GameOsw
    jmp MainLoop

; ==================== Draw Blocks ====================
; Firefly: ball, 16 lines, blinking
BallBlock:
    lda FrameCnt
    and #$10
    beq BallBlkOff
    ldx #16
BallBlkOn:
    sta WSYNC
    lda #2
    sta ENABL
    dex
    bne BallBlkOn
    jmp BallBlkDone
BallBlkOff:
    ldx #16
BallBlkOffLp:
    sta WSYNC
    dex
    bne BallBlkOffLp
BallBlkDone:
    lda #0
    sta ENABL
    rts

; Ember: missile 0, 8 lines, blinking (different rate than firefly)
EmberBlock:
    lda FrameCnt
    and #$08
    beq EmberBlkOff
    ldx #8
EmberBlkOn:
    sta WSYNC
    lda #2
    sta ENAM0
    dex
    bne EmberBlkOn
    jmp EmberBlkDone
EmberBlkOff:
    ldx #8
EmberBlkOffLp:
    sta WSYNC
    dex
    bne EmberBlkOffLp
EmberBlkDone:
    lda #0
    sta ENAM0
    rts

; ==================== Data ====================
; Digit font: 10 digits x 8 scanlines, MSB left
Digits:
    ; 0
    .byte $3C,$66,$6E,$76,$66,$66,$3C,$00
    ; 1
    .byte $18,$38,$18,$18,$18,$18,$3C,$00
    ; 2
    .byte $3C,$66,$06,$0C,$30,$60,$7E,$00
    ; 3
    .byte $3E,$0C,$18,$0C,$06,$66,$3C,$00
    ; 4
    .byte $0C,$1C,$3C,$6C,$7E,$0C,$0C,$00
    ; 5
    .byte $7E,$60,$7C,$06,$06,$66,$3C,$00
    ; 6
    .byte $1C,$30,$60,$7C,$66,$66,$3C,$00
    ; 7
    .byte $7E,$06,$0C,$18,$30,$30,$30,$00
    ; 8
    .byte $3C,$66,$66,$3C,$66,$66,$3C,$00
    ; 9
    .byte $3C,$66,$66,$7E,$06,$0C,$38,$00

FireflySpr:
    .byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18

; Text data
; "FIREFLY"
TextFire:
    .byte $F0,$FE,$FF,$00,$00,$91
    .byte $F0,$FE,$FF,$00,$00,$91
    .byte $10,$69,$11,$00,$00,$91
    .byte $10,$69,$11,$00,$00,$91
    .byte $70,$69,$77,$00,$00,$61
    .byte $70,$69,$77,$00,$00,$61
    .byte $10,$6C,$11,$00,$00,$61
    .byte $10,$6C,$11,$00,$00,$61
    .byte $10,$6A,$11,$00,$00,$61
    .byte $10,$6A,$11,$00,$00,$61
    .byte $10,$F9,$1F,$00,$00,$6F
    .byte $10,$F9,$1F,$00,$00,$6F

TextPress:
    .byte $70,$EF,$EE,$F0,$FE,$F0
    .byte $70,$EF,$EE,$F0,$FE,$F0
    .byte $90,$98,$11,$10,$69,$10
    .byte $90,$98,$11,$10,$69,$10
    .byte $90,$9E,$66,$70,$69,$70
    .byte $90,$9E,$66,$70,$69,$70
    .byte $70,$C8,$88,$10,$6C,$10
    .byte $70,$C8,$88,$10,$6C,$10
    .byte $10,$A8,$88,$10,$6A,$10
    .byte $10,$A8,$88,$10,$6A,$10
    .byte $10,$9F,$77,$F0,$F9,$10
    .byte $10,$9F,$77,$F0,$F9,$10

; ==================== Vectors ====================
    ORG $FFFA
    .word Start           ; NMI
    .word Start           ; RESET
    .word Start           ; IRQ
