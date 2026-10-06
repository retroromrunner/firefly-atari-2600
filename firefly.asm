; FIREFLY - Atari 2600 proof of concept
; Title screen + collect-the-embers gameplay with score
; v2: border clamps corrected (ball kisses walls, no overlap/gap),
;     the SHADE (chaser enemy, Player 1 sprite) and multi-room progression.
;
; Controls:
;   Title: Press FIRE to start
;   Game: Joystick moves firefly, collect blinking embers for +1 each
;   Avoid the shade! It gets faster and hotter-colored as you score.
;   When you've collected enough embers, a door opens in the bottom wall -
;   fly through it to escape to the next room (new color, faster shade).

    processor 6502

; ==================== TIA Registers ====================
VSYNC   = $00
VBLANK  = $01
WSYNC   = $02
NUSIZ0  = $04
NUSIZ1  = $05
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
RESM1   = $13
RESBL   = $14
GRP0    = $1B
GRP1    = $1C
ENAM0   = $1D
ENAM1   = $1E
ENABL   = $1F
AUDC0   = $15
AUDF0   = $17
AUDV0   = $19
HMP0    = $20
HMP1    = $21
HMM0    = $22
HMM1    = $23
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
FireY       = $83    ; firefly Y (0-166 in door shaft)
Glow        = $84    ; (unused)
TP          = $85    ; text pointer (2 bytes: $85-$86)
Score       = $87    ; BCD score 00-99
EmberX      = $88    ; collectible X
EmberY      = $89    ; collectible Y
Rand        = $8A    ; RNG state (nonzero)
ScoreP0     = $8B    ; tens digit pointer (2 bytes)
ScoreP1     = $8D    ; ones digit pointer (2 bytes)
SfxT        = $8F    ; sound effect timer (0=off)
MusT        = $90    ; start jingle timer (0=off)
EnemyX      = $91    ; shade X
EnemyY      = $92    ; shade Y
MoveT       = $93    ; shade move countdown
Room        = $94    ; current room (1..)
RoomScore   = $95    ; binary points collected this room
Points      = $96    ; binary total points (drives shade speed)
DoorOpen    = $97    ; 0=closed, 1=open
DeathT      = $98    ; death anim timer (0=alive)
YA          = $99    ; draw slot A: Y (topmost)
YB          = $9A    ; draw slot B: Y
YC          = $9B    ; draw slot C: Y
HA          = $9C    ; draw slot A: height
HB          = $9D
HC          = $9E
TA          = $9F    ; draw slot A: type (0=ball,1=ember,2=shade)
TB          = $A0
TC          = $A1
TMP         = $A2    ; scratch
Gap0        = $A3    ; blank lines before A
Gap1        = $A4    ; blank lines between A and B
Gap2        = $A5    ; blank lines between B and C
Rest        = $A6    ; blank lines after C
IsPower     = $A7    ; (unused, legacy)
HasFreeze   = $A8    ; 0/1: player holds freeze power
FreezeT     = $A9    ; shade freeze timer (0=not frozen)
PowX        = $AA    ; power ember X
PowY        = $AB    ; power ember Y
PowActive   = $AC    ; 0/1: power ember visible
YD          = $AD    ; draw slot D: Y (4th object)
HD          = $AE    ; draw slot D: height
TD          = $AF    ; draw slot D: type (3=power ember)
Gap3        = $B0    ; blank lines between C and D
ShadeCol    = $B1    ; precomputed shade color for EnemyBlock

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
    lda #1
    sta Glow
    lda #$A5
    sta Rand
    lda #$20
    sta NUSIZ0          ; missile 0 = 4px wide
    sta NUSIZ1          ; missile 1 = 4px wide (power ember)
    jsr ResetGame
    jmp MainLoop

; ==================== Reset Game ====================
; Full reset: score, room, shade, door, player. Used at boot,
; after death, and (partially) on room change - see NextRoom.
ResetGame:
    lda #0
    sta Score
    sta Points
    sta RoomScore
    sta DoorOpen
    sta DeathT
    sta SfxT
    sta MusT
    sta HasFreeze
    sta FreezeT
    sta PowActive
    lda #1
    sta Room
    lda #80
    sta FireX
    lda #76
    sta FireY
    lda #12
    sta EnemyX
    lda #140
    sta EnemyY
    jsr CalcLevel
    tax
    lda TickTable,x
    sta MoveT
    jsr NewEmber
    rts

; ==================== Shade speed level ====================
; A = min(6, Points/4 + Room - 1). Higher = faster + hotter color.
CalcLevel:
    lda Points
    lsr
    lsr                 ; Points/4
    clc
    adc Room
    sec
    sbc #1              ; +Room-1
    cmp #7
    bcc CLDone
    lda #6
CLDone:
    rts

; ==================== Next Room ====================
; Player escaped through the door. Harder room, same arena.
NextRoom:
    inc Room
    lda #0
    sta RoomScore
    sta DoorOpen
    sta HasFreeze
    sta FreezeT
    sta PowActive
    lda #80
    sta FireX
    lda #16
    sta FireY
    lda #12
    sta EnemyX
    lda #140
    sta EnemyY
    jsr CalcLevel
    tax
    lda TickTable,x
    sta MoveT
    jsr NewEmber
    lda #32
    sta SfxT            ; room-enter fanfare (higher/longer than blips)
    rts

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

; Position P0 (score tens digit)
PosXP0:
    jsr PosXGen
    sta HMP0
    sta RESP0
    rts

; Position P1 (score ones digit / shade - repositioned mid-kernel)
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

PosXM1:
    jsr PosXGen
    sta HMM1
    sta RESM1
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
; Y is clamped to 136 so the 3-object draw layout always fits in 168 lines.
NewEmber:
    jsr Rand8
    and #$77
    clc
    adc #8              ; X: 8..127 (inside play area)
    sta EmberX
    jsr Rand8
    and #$7F
    clc
    adc #12             ; Y: 12..139
    cmp #137
    bcc EmYOk
    lda #136            ; clamp Y to 136
EmYOk:
    sta EmberY
    rts

NewPowerEmber:
    jsr Rand8
    and #$77
    clc
    adc #8              ; X: 8..127
    sta PowX
    jsr Rand8
    and #$7F
    clc
    adc #12             ; Y: 12..139
    cmp #137
    bcc PowYOk
    lda #136
PowYOk:
    sta PowY
    lda #1
    sta PowActive
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
    sta ENAM1
    sta HMCLR
    lda #$00
    sta COLUBK          ; BLACK background
    ; death flash: blink background red while dying
    lda DeathT
    beq NoDeathFlash
    lda FrameCnt
    and #$08
    beq NoDeathFlash
    lda #$40
    sta COLUBK
NoDeathFlash:
    lda #$31
    sta CTRLPF          ; reflect playfield + 8px ball
    ; ---- game logic (frozen during death anim) ----
    lda DeathT
    beq DoLogic
    jmp SkipLogic
DoLogic:
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
    cmp #158
    bcc DownInc         ; below wall top: normal move
    ; at/below wall: only through the open door shaft
    lda DoorOpen
    beq NotDown
    lda FireX
    cmp #66             ; door shaft x-range
    bcc NotDown
    cmp #86
    bcs NotDown
    lda FireY
    cmp #166
    bcs NotDown
DownInc:
    inc FireY
NotDown:
    lda SWCHA
    and #$40            ; Left
    bne NotLeft
    lda FireY
    cmp #153
    bcc LeftGo          ; above door area: free move
    lda DoorOpen
    beq LeftGo          ; door closed: free move along bottom
    lda FireX
    cmp #66
    bcc LeftGo          ; left of shaft: free move
    cmp #86
    bcs LeftGo          ; right of shaft: free move
    jmp NotLeft         ; in open door shaft: no lateral move
LeftGo:
    lda FireX
    cmp #1
    bcc NotLeft         ; min X = 0 (ball at edge)
    dec FireX
NotLeft:
    lda SWCHA
    and #$80            ; Right
    bne NotRight
    lda FireY
    cmp #153
    bcc RightGo         ; above door area: free move
    lda DoorOpen
    beq RightGo         ; door closed: free move along bottom
    lda FireX
    cmp #66
    bcc RightGo         ; left of shaft: free move
    cmp #86
    bcs RightGo         ; right of shaft: free move
    jmp NotRight        ; in open door shaft: no lateral move
RightGo:
    lda FireX
    cmp #132
    bcs NotRight        ; max X = 132
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
    ; fire button: trigger shade freeze if power held
    lda INPT4
    and #$80
    bne NoFreezeBtn      ; button not pressed
    lda HasFreeze
    beq NoFreezeBtn      ; no freeze power
    lda FreezeT
    bne NoFreezeBtn      ; already frozen
    lda #0
    sta HasFreeze        ; consume power
    lda #180
    sta FreezeT          ; 3-second freeze
    lda #40
    sta SfxT             ; freeze zap sound
NoFreezeBtn:
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
    bcc CXOk
    jmp CheckPower
CXOk:
    lda FireY
    sec
    sbc EmberY
    bcs CYPos
    eor #$FF
    clc
    adc #1
CYPos:
    cmp #11
    bcs CheckPower
    ; REGULAR ember collect! score+1 (BCD)
    sed
    clc
    lda Score
    adc #1
    cld
    sta Score
    inc Points
    inc RoomScore
    lda #12
    sta SfxT            ; collect blip (may be overridden)
    ; door opens when RoomScore >= 4+Room ?
    lda DoorOpen
    bne SpawnReg        ; already open (shouldn't happen)
    lda Room
    clc
    adc #4
    sta TMP
    lda RoomScore
    cmp TMP
    bcc SpawnReg
    ; DOOR OPENS: hide regular ember (don't respawn)
    lda #1
    sta DoorOpen
    lda #24
    sta SfxT            ; door chime (overrides blip)
    lda #160
    sta EmberX          ; hide off-screen
    lda #0
    sta EmberY
    lda #0
    sta PowActive        ; lose uncollected power ember (use it or lose it)
    jmp CheckPower
SpawnReg:
    jsr NewEmber        ; respawn regular
    ; spawn power ember after 2nd collect (if not already have/active)
    lda RoomScore
    cmp #2
    bne CheckPower
    lda PowActive
    bne CheckPower
    lda HasFreeze
    bne CheckPower
    jsr NewPowerEmber
    jmp CheckPower
CheckPower:
    ; POWER ember collision (if active)
    lda PowActive
    beq NoHit
    lda FireX
    sec
    sbc PowX
    bcs PXPos
    eor #$FF
    clc
    adc #1
PXPos:
    cmp #9
    bcs NoHit
    lda FireY
    sec
    sbc PowY
    bcs PYPos
    eor #$FF
    clc
    adc #1
PYPos:
    cmp #11
    bcs NoHit
    ; POWER collect: grant freeze
    lda #0
    sta PowActive        ; consumed
    lda #1
    sta HasFreeze
    lda #36
    sta SfxT             ; power-up sound
NoHit:
    ; ---- shade AI: chase the firefly (unless frozen) ----
    lda FreezeT
    beq NotFrozen
    dec FreezeT          ; count down freeze
    jmp SkipShadeMove    ; frozen: no movement
NotFrozen:
    dec MoveT
    bne SkipShadeMove
    jsr CalcLevel
    tax
    lda TickTable,x
    sta MoveT
    ; move X toward player
    lda EnemyX
    cmp FireX
    beq ExDone
    bcc ExInc
    dec EnemyX
    jmp ExClamp
ExInc:
    inc EnemyX
ExClamp:
    lda EnemyX
    cmp #1
    bcc ExMin           ; min X = 0
    cmp #133
    bcc ExDone          ; max X = 132
    lda #132
    sta EnemyX
    jmp ExDone
ExMin:
    lda #0
    sta EnemyX
ExDone:
    ; move Y toward player
    lda EnemyY
    cmp FireY
    beq EyDone
    bcc EyInc
    dec EnemyY
    jmp EyClamp
EyInc:
    inc EnemyY
EyClamp:
EyClamp:
    lda EnemyY
    cmp #159
    bcc EyDone          ; max Y = 158 (layout fit)
    lda #158
    sta EnemyY
EyDone:
SkipShadeMove:
    ; ---- death check: shade catches firefly? ----
    lda EnemyX
    sec
    sbc FireX
    bcs EDXPos
    eor #$FF
    clc
    adc #1
EDXPos:
    cmp #9
    bcs NoDeath
    lda EnemyY
    sec
    sbc FireY
    bcs EDYPos
    eor #$FF
    clc
    adc #1
EDYPos:
    cmp #11
    bcs NoDeath
    lda #50
    sta DeathT          ; caught!
NoDeath:
    ; ---- door exit: fly through the open door ----
    lda DoorOpen
    beq SkipExit
    lda FireY
    cmp #162
    bcc SkipExit
    lda FireX
    cmp #66
    bcc SkipExit
    cmp #86
    bcs SkipExit
    jsr NextRoom
SkipExit:
SkipLogic:
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
    lda PowX
    jsr PosXM1          ; power ember
    lda #68
    jsr PosXP0          ; score tens digit
    lda #76
    jsr PosXP1          ; score ones digit (P1 repositioned mid-kernel for shade)
    sta WSYNC
    sta HMOVE
    ; ---- audio ----
    lda DeathT
    beq AudioNormal
    ; death sound: falling pitch buzz
    lda DeathT
    lsr
    sta TMP
    lda #31
    sec
    sbc TMP
    sta AUDF0
    lda #$08
    sta AUDC0
    lda #$08
    sta AUDV0
    dec DeathT
    bne AudioDone
    jsr ResetGame       ; death anim over: back to title
    lda #0
    sta State
    jmp AudioDone
AudioNormal:
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
    ; ---- sort draw slots by Y (A=top) ----
    ; Ball draw Y clamped to 144 so the pushed 3-object layout
    ; always fits in the 168-line middle (logic FireY unaffected).
    lda FireY
    cmp #145
    bcc BallYok
    lda #144
BallYok:
    sta YA
    lda #16
    sta HA
    lda #0
    sta TA              ; 0 = firefly (ball)
    lda EmberY
    sta YB
    ; hide regular ember if door open (player collected them all)
    lda DoorOpen
    beq EmberShow
    lda #0              ; no ember: zero height
    sta HB
    jmp EmberSet
EmberShow:
    lda #8
    sta HB
EmberSet:
    lda #1
    sta TB              ; 1 = ember (missile 0)
    lda EnemyY
    sta YC
    lda #8
    sta HC
    lda #2
    sta TC              ; 2 = shade (player 1)
    ; 4th object: power ember (missile 1)
    lda PowY
    sta YD
    lda PowActive
    beq PowHide
    lda #8
    jmp PowSetH
PowHide:
    lda #0
PowSetH:
    sta HD
    lda #3
    sta TD              ; 3 = power ember (missile 1)
    ; bubble sort 4 items by Y
    lda YA
    cmp YB
    bcc SortS1
    jsr SwapAB
SortS1:
    lda YB
    cmp YC
    bcc SortS2
    jsr SwapBC
SortS2:
    lda YC
    cmp YD
    bcc SortS3
    jsr SwapCD
SortS3:
    lda YA
    cmp YB
    bcc SortS4
    jsr SwapAB
SortS4:
    lda YB
    cmp YC
    bcc SortS5
    jsr SwapBC
SortS5:
    lda YA
    cmp YB
    bcc SortS6
    jsr SwapAB
SortS6:
    ; ---- draw layout: push down on Y overlap ----
    ; Gaps are all >= 0 and sum to exactly 168 lines by construction.
    lda YA
    sta Gap0             ; Gap0 = YA
    clc
    adc HA               ; A = YA+HA = endA
    sta TMP              ; TMP = endA
    lda YB
    cmp TMP              ; YB vs endA
    bcs PBok
    lda TMP
PBok:                    ; A = PB = max(YB, endA)
    sec
    sbc TMP              ; Gap1 = PB-endA (>= 0)
    sta Gap1
    clc
    adc TMP              ; A = PB
    clc
    adc HB               ; A = PB+HB = endB
    sta TMP              ; TMP = endB
    lda YC
    cmp TMP              ; YC vs endB
    bcs PCok
    lda TMP
PCok:                    ; A = PC = max(YC, endB)
    sec
    sbc TMP              ; Gap2 = PC-endB (>= 0)
    sta Gap2
    clc
    adc TMP              ; A = PC
    clc
    adc HC               ; A = PC+HC = endC
    sta TMP              ; TMP = endC
    lda YD
    cmp TMP              ; YD vs endC
    bcs PDok
    lda TMP
PDok:                    ; A = PD = max(YD, endC)
    sec
    sbc TMP              ; Gap3 = PD-endC (>= 0)
    sta Gap3
    clc
    adc TMP              ; A = PD
    clc
    adc HD               ; A = PD+HD = endD (<= 168 by Y limits)
    sta TMP              ; TMP = endD
    lda #168
    sec
    sbc TMP              ; Rest = 168-endD (>= 0)
    sta Rest
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
    lda HasFreeze
    beq DrawScore
    lda FrameCnt
    and #$20            ; blink score when freeze available
    beq ScoreBlank
DrawScore:
    lda (ScoreP0),y
    sta GRP0
    lda (ScoreP1),y
    sta GRP1
    jmp ScoreNext
ScoreBlank:
    lda #0
    sta GRP0
    sta GRP1
ScoreNext:
    iny
    cpy #8
    bne ScoreLp
    lda #0
    sta GRP0
    sta GRP1
    ; ---- per-room / per-level colors ----
    lda #$31
    sta CTRLPF          ; reflect + 8px ball
    lda Room
    sec
    sbc #1
    and #7
    tax
    lda RoomCols,x
    sta COLUPF          ; walls (+ firefly, the ball uses COLUPF)
    lda #$1E
    sta COLUP0          ; regular ember: yellow (M0)
    ; power ember (M1) color set in PowerEmberBlock
    jsr CalcLevel
    tax
    lda FreezeT
    bne ShadeFrozen
    lda EnemyCols,x
    jmp ShadeColDone
ShadeFrozen:
    lda #$8E            ; frozen shade: icy blue
ShadeColDone:
    sta ShadeCol        ; store for EnemyBlock (COLUP1 shared with M1)
    ; Top wall (8 lines) - full width.
    ; The last 2 lines reposition P1 for the shade: the score ones
    ; digit needed P1 in VBLANK, the shade needs it in the middle.
    lda #$FF
    sta PF0
    sta PF1
    sta PF2
    ldx #6
TopWall:
    sta WSYNC
    dex
    bne TopWall
    lda EnemyX
    jsr PosXP1          ; 1 line: coarse+fine for shade
    lda #0
    sta HMP0            ; clear other motions so the next
    sta HMM0            ; HMOVE only moves the shade
    sta HMBL
    sta WSYNC           ; 1 line
    sta HMOVE           ; apply shade fine offset
    ; Middle (168 lines) - side walls, 3 objects in Y order.
    ; Gaps precomputed in VBLANK; they sum to exactly 168 lines.
    lda #$30            ; 8px on each side (with reflect): 8-15 / 144-151
    sta PF0
    lda #0
    sta PF1
    sta PF2
    ldx Gap0
    jsr BlankLines
    lda TA
    jsr DrawDispatch
    ldx Gap1
    jsr BlankLines
    lda TB
    jsr DrawDispatch
    ldx Gap2
    jsr BlankLines
    lda TC
    jsr DrawDispatch
    ldx Gap3
    jsr BlankLines
    lda TD
    jsr DrawDispatch
    ldx Rest
    jsr BlankLines
MidDone:
    ; Bottom wall (8 lines) - full width, or door gap when open.
    ; Door: clear playfield bits 17-22 (24px centered, mirrored).
    lda #$FF
    sta PF0
    sta PF1
    lda DoorOpen
    beq DoorClosed
    lda #$F8
    sta PF2
    jmp DoorDraw
DoorClosed:
    lda #$FF
    sta PF2
DoorDraw:
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
; Dispatch A: 0=firefly ball, 1=ember missile, 2=shade sprite, 3=power ember
DrawDispatch:
    cmp #1
    bcc DD_Ball
    beq DD_Ember
    cmp #2
    beq DD_Shade
    jmp PowerEmberBlock
DD_Ball:
    jmp BallBlock
DD_Ember:
    jmp EmberBlock
DD_Shade:
    jmp EnemyBlock

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

; Power ember: missile 1, 8 lines, blinking (white-blue)
PowerEmberBlock:
    lda PowActive
    beq PowSkip          ; not active: just blank 8 lines
    lda #$0E
    sta COLUP1          ; M1 uses COLUP1 (shared with P1/shade)
    lda FrameCnt
    and #$08
    beq PowBlkOff
    ldx #8
PowBlkOn:
    sta WSYNC
    lda #2
    sta ENAM1
    dex
    bne PowBlkOn
    jmp PowBlkDone
PowBlkOff:
    ldx #8
PowBlkOffLp:
    sta WSYNC
    dex
    bne PowBlkOffLp
PowBlkDone:
    lda #0
    sta ENAM1
    rts
PowSkip:
    ldx #8
PowSkipLp:
    sta WSYNC
    dex
    bne PowSkipLp
    rts

; Shade: player 1, 8x8 ghost sprite, solid (no blink - it's scary)
EnemyBlock:
    lda ShadeCol
    sta COLUP1          ; P1 uses COLUP1 (shared with M1/power)
    ldy #0
EnBlLp:
    sta WSYNC
    lda EnemySpr,y
    sta GRP1
    iny
    cpy #8
    bne EnBlLp
    lda #0
    sta GRP1
    rts

; ==================== Sort helpers ====================
SwapAB:
    lda YA
    ldx YB
    sta YB
    stx YA
    lda HA
    ldx HB
    sta HB
    stx HA
    lda TA
    ldx TB
    sta TB
    stx TA
    rts

SwapBC:
    lda YB
    ldx YC
    sta YC
    stx YB
    lda HB
    ldx HC
    sta HC
    stx HB
    lda TB
    ldx TC
    sta TC
    stx TB
    rts

SwapCD:
    lda YC
    ldx YD
    sta YD
    stx YC
    lda HC
    ldx HD
    sta HD
    stx HC
    lda TC
    ldx TD
    sta TD
    stx TC
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

; Shade sprite (8x8 ghost, top row first)
EnemySpr:
    .byte $3C  ; 00111100
    .byte $7E  ; 01111110
    .byte $FF  ; 11111111
    .byte $A5  ; 10100101 (eyes)
    .byte $FF  ; 11111111
    .byte $FF  ; 11111111
    .byte $DB  ; 11011011 (wavy bottom)
    .byte $00

; Shade speed: frames between 1px chase steps, by level 0-6
TickTable:
    .byte 8,6,5,4,3,2,2

; Shade color by level: blue -> purple -> red -> orange -> yellow -> white
EnemyCols:
    .byte $84,$74,$44,$24,$1A,$0C,$0E

; Wall color by room (index (Room-1) & 7)
RoomCols:
    .byte $1E,$9E,$C8,$48,$A8,$28,$68,$B8

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
