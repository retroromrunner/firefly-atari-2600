; FIREFLY - Atari 2600 proof of concept
; Minimal game: title screen + movable firefly sprite
; 
; Controls:
;   Title: Press FIRE to start
;   Game: Joystick moves firefly, FIRE toggles glow

    processor 6502

; ==================== TIA Registers ====================
VSYNC   = $00
VBLANK  = $01
WSYNC   = $02
NUSIZ0  = $04
COLUP0  = $06
COLUPF  = $08
COLUBK  = $09
CTRLPF  = $0A
PF0     = $0D
PF1     = $0E
PF2     = $0F
RESP0   = $10
RESBL   = $14
GRP0    = $1B
GRP1    = $1C
ENABL   = $1F
HMP0    = $20
HMOVE   = $2A
HMCLR   = $2B
CXCLR   = $2C
SWCHA   = $0280
INTIM   = $0284
TIM64T  = $0296

; ==================== Zero Page ====================
State       = $80    ; 0=title, 1=game
FrameCnt    = $81
FireX       = $82    ; firefly X (0-159)
FireY       = $83    ; firefly Y (0-191)
Glow        = $84    ; 0=dim, 1=bright
TP          = $85    ; text pointer (2 bytes)

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
    lda #96
    sta FireY
    lda #1
    sta Glow
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
    lda #2
    sta VSYNC
    sta WSYNC
    sta WSYNC
    sta WSYNC
    lda #0
    sta VSYNC
    rts

; ==================== Position Object ====================
; A = x (0-159), X = 0 (P0)
PosX:
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
    sta HMP0
    sta RESP0
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

; ==================== Text12 ====================
; Draw 12 lines of text from (TP). 72 bytes total.
; Cycle-timed for correct PF writes.
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
    iny
    nop
    nop
    sta PF2
    lda (TP),y
    sta PF1
    iny
    lda (TP),y
    sta PF0
    iny
    dex
    bne Text12Loop
    rts

; ==================== TITLE FRAME ====================
TitleFrame:
    jsr VSYNC3
    ; VBLANK (37 lines)
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
    ; position ball for firefly glow
    lda #80
    ldx #4
    jsr PosXBall
    sta WSYNC
    sta HMOVE
TitleVbw:
    lda INTIM
    bne TitleVbw
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
    lda #35
    sta TIM64T
    inc FrameCnt
    ; check fire button
    lda SWCHA
    and #$80            ; P0 fire? (actually INPT4, but use SWCHA for simplicity)
    ; Real fire: use INPT4 ($0C)
    lda $0C
    and #$80
    bne TitleOsw        ; not pressed (bit set = not pressed)
    lda #1
    sta State
TitleOsw:
    lda INTIM
    bne TitleOsw
    jmp MainLoop

; Position ball (X=4)
PosXBall:
    sta WSYNC
    sec
Div15B:
    sbc #15
    bcs Div15B
    eor #7
    asl
    asl
    asl
    asl
    sta $24             ; HMBL
    sta RESBL
    rts

; ==================== GAME FRAME ====================
GameFrame:
    jsr VSYNC3
    ; VBLANK
    lda #43
    sta TIM64T
    lda #0
    sta PF0
    sta PF1
    sta PF2
    sta GRP0
    sta GRP1
    sta ENABL
    sta HMCLR
    lda #$00
    sta COLUBK          ; BLACK background
    lda #$31
    sta CTRLPF          ; reflect playfield + 8px ball
    lda #$1E
    sta COLUPF          ; yellow (walls + firefly)
    ; read joystick (no wraparound)
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
    cmp #158
    bcs NotDown
    inc FireY
NotDown:
    lda SWCHA
    and #$40            ; Left
    bne NotLeft
    lda FireX
    cmp #8
    bcc NotLeft
    dec FireX
NotLeft:
    lda SWCHA
    and #$80            ; Right
    bne NotRight
    lda FireX
    cmp #150
    bcs NotRight
    inc FireX
NotRight:
    lda #$1E
    sta COLUPF          ; yellow walls + firefly
    ; position ball at FireX
    lda FireX
    ldx #4
    jsr PosXBall
    sta WSYNC
    sta HMOVE
GameVbw:
    lda INTIM
    bne GameVbw
    ; Kernel (192 lines) with walls
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
    ; Middle (176 lines) - side walls only
    lda #$10            ; 4px on each side (with reflect)
    sta PF0
    lda #0
    sta PF1
    sta PF2
    ; ball at FireY (0-160)
    ldx FireY
    jsr BlankLines
    ; ball (16 lines, blinking)
    lda FrameCnt
    and #$10
    beq BallOff
    ldx #16
BallOn:
    sta WSYNC
    lda #2
    sta ENABL
    dex
    bne BallOn
    jmp BallDone
BallOff:
    ldx #16
BallOffLp:
    sta WSYNC
    dex
    bne BallOffLp
BallDone:
    lda #0
    sta ENABL
    ; rest of middle: 176 - 16 - FireY = 160 - FireY
    lda #160
    sec
    sbc FireY
    tax
    jsr BlankLines
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
    lda #35
    sta TIM64T
    inc FrameCnt
GameOsw:
    lda INTIM
    bne GameOsw
    jmp MainLoop

; ==================== Data ====================
FireflySpr:
    .byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18

; Text data
; "FIREFLY"
TextFire:
    .byte $F0,$FE,$FF,$91,$00,$00
    .byte $F0,$FE,$FF,$91,$00,$00
    .byte $10,$69,$11,$91,$00,$00
    .byte $10,$69,$11,$91,$00,$00
    .byte $70,$69,$77,$61,$00,$00
    .byte $70,$69,$77,$61,$00,$00
    .byte $10,$6C,$11,$61,$00,$00
    .byte $10,$6C,$11,$61,$00,$00
    .byte $10,$6A,$11,$61,$00,$00
    .byte $10,$6A,$11,$61,$00,$00
    .byte $10,$F9,$1F,$6F,$00,$00
    .byte $10,$F9,$1F,$6F,$00,$00

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
    .byte $10,$9F,$77,$10,$F9,$F0
    .byte $10,$9F,$77,$10,$F9,$F0

; ==================== Vectors ====================
    ORG $FFFC
    .word Start
    .word Start
    .word Start
