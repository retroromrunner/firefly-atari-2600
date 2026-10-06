# FIREFLY Debug Log — 2026-10-02

## The "invisible ember" was a misdiagnosis
- diag1 (missile-test kernel + game's VBLANK positioning, missile at x=80):
  showed the yellow dash dead-center. **Positioning code is correct.**
- Full game in Javatari: ember IS visible, blinking, at right side (~x=138).
  This matches the RNG init position (LFSR from $A5 → EmberX=138, EmberY=84).
  The "yellow tick at the right wall" seen in bisection was the ember working
  correctly, not a glitch.
- diag2 (ember fixed at player start 80,76): score reads non-zero and changes
  across captures → **collect → score+1 (BCD) → relocate loop fully works.**

## Real bug found and fixed: VBLANK register never set
- `sta VBLANK` appeared nowhere in firefly.asm. The TIA blank bit was never
  asserted, and the INTIM wait loops had no WSYNC, so the frame phase drifted.
- Fix: `lda #2 / sta VBLANK` at VBLANK start (both frames), `sta WSYNC` in all
  four INTIM wait loops, `lda #0 / sta VBLANK` before each kernel,
  `lda #2 / sta VBLANK` in overscan.
- Also fixed README: score digits in TIA score mode use COLUP0/COLUP1
  (not COLUPF); CTRLPF=$31 (not $30).

## Status
- firefly.bin rebuilt 2026-10-02 14:21 EDT (4096 bytes, vectors $F000).
- Awaiting Javatari verification of the VBLANK-fixed build.
- Do NOT call verified until Cori tests in RetroArch/Stella.

## 2026-10-02 14:32 EDT — Title fixes
- VSYNC3 was firing mid-scanline (17 cycles in) after adding WSYNC to wait loops,
  causing slow vertical scroll. Fixed by adding `sta WSYNC` at start of VSYNC3.
- Text12 had wrong write order for non-reflect mode (wrote PF2,PF1,PF0 for right
  half; TIA draws PF0,PF1,PF2). Fixed to PF0,PF1,PF2,PF0,PF1,PF2 with corrected
  cycle timing; font data reordered from [L0,L1,L2,R2,R1,R0] to [L0,L1,L2,R0,R1,R2].
- Title now stable and readable in Javatari ("FIREF" + "LY" with gap, "PRESS FIRE"
  blinks). Gameplay verified: walls solid, score/collection loop works.
- ROM copied to ~/workspace/your_files/firefly-2600.bin for Cori.
- NOT declared verified — awaiting Cori's RetroArch/Stella test.

## 2026-10-02 15:04 EDT — Cori's playtest fixes
Cori reported (RetroArch/Stella): player passes through right wall, left wall
gap too large, score upside down.
- Score: loop was Y=7..0 (upside down). Fixed to Y=0..7 (the correct version
  from firefly-test.asm was never ported). Verified right-side up in Javatari.
- Left clamp: was 8 (5px gap from wall at 0-3). Fixed to 4 (ball touches wall).
- Right clamp: was 150 (ball overlapped wall by 2px). Fixed to 148.
- Walls verified solid on all 4 sides in Javatari.

## 2026-10-02 15:27 EDT — Y-overlap, wall tuning, sound
Cori reported: bottom wall extends down when passing vertically near ember;
left gap still too large; player wraps through right wall to left side.
- Y-overlap line count: when ball/ember Y ranges overlapped, the "rest" lines
  calculation was wrong (didn't account for overlap), drawing too many lines
  and pushing the bottom wall down. Fixed both branches to compute
  rest = 168 - max(end positions) correctly.
- Wall clamps: left 4->2 (smaller buffer), right 148->144 (bigger buffer).
- Sound: collect blip (AUDC0=$04 pure tone, AUDF0=SfxT rising pitch, 12 frames)
  on ember collect; 3-note ascending jingle (AUDF 20,14,8) on game start.
  Audio updated in GameFrame VBLANK; muted on title.

## 2026-10-06 — Borders re-tuned, shade enemy + rooms (v2)
Cori reported: player halfway through right wall, blocked too soon at left
with too large a gap. Investigation: the shipped binary's clamps were [0,140]
(left min 0, right max 140) — an undocumented overcorrection from Oct 2 15:40,
made AFTER the Javatari verification that [4,148] was correct ("ball touches
wall", "walls solid on all 4 sides"). With an 8px ball and 4px walls at pixels
0-3 / 156-159, the arithmetically correct range is 4..148. Cori's symptoms match
the [0,140] build with left/right swapped in the report (4px = half the ball
sinking into the wall on one side, 8px gap on the other). Fix: clamps back to
the verified [4,148] (left: `cmp #5/bcc`, right: `cmp #148/bcs`).

New features (Cori's idea):
- THE SHADE: player-1 8x8 ghost sprite that chases the firefly. Frame-skipped
  movement (1px/tick toward player on both axes); tick rate from TickTable by
  level = min(6, Points/4 + Room - 1); color heats blue->purple->red->orange->
  yellow->white with level (COLUP1 set per frame). Touch = death: red flash,
  falling buzz, back to title.
- P1 does double duty: positioned in VBLANK for the score ones digit, then
  repositioned mid-kernel during the top-wall lines for the shade (HMP0/HMM0/
  HMBL cleared so the second HMOVE only moves the shade).
- 3-object kernel: ball/ember/shade Y-sorted in VBLANK; layout pass pushes
  overlaps down and precomputes Gap0/1/2/Rest so the middle is exactly 168
  lines. Y limits (ball draw <=144, ember <=136, shade <=152) proven to always
  fit — no overflow possible.
- ROOMS: RoomScore >= 4+Room opens a door (PF2=$F8 clears a centered 24px gap
  in the bottom wall) with a chime. Flying down through the shaft (FireX in
  [66,86), FireY >= 162) triggers NextRoom: new wall color (RoomCols table),
  faster shade, more embers needed. Ball draw Y clamped to 144 in the shaft
  (logic continues to 162); lateral movement blocked while in the shaft.
- Sounds: collect blip (12), door chime (24), room-enter blip (16), death
  buzz (falling pitch, 50 frames), start jingle (unchanged).
- Note: firefly (ball) uses COLUPF so it tints with the room's wall color;
  ember stays yellow (COLUP0). Blink keeps the firefly distinguishable.
- Build: dasm firefly.asm -f3 -ofirefly.bin (4096 bytes, vectors $F000).
- NOT declared verified — awaiting Cori's RetroArch/Stella playtest.

## v2 verification (Oct 6, 2026)
- 6502 logic test via py65 (CPU+timer+joystick emulation, no video): ALL 16 PASS.
  - Borders clamp at FireX=4 (left) and FireX=148 (right), hold under sustained input.
  - Ember collect -> score+1, Points+1.
  - Shade chases player (moves toward FireX/FireY).
  - Shade collision -> DeathT=50 -> back to title, score reset.
  - 5th ember in room 1 -> DoorOpen=1, SfxT=24 (door chime).
  - Exit through door -> Room=2, DoorOpen=0, FireY=16 (top).
- Test script: /tmp/test_ff_logic.py (uses AtariMem MMU, TIM64T/INTIM timer, SWCHA/INPT4).
- Javatari visual test: pending (browser task) — must load exact v2 binary from GitHub raw URL.

## v2.1 wall fix (Oct 6, 2026)
Cori reported: right wall pass-through with wrap to left, left wall gap, bottom wall gap, no door-exit sound.
Root cause: side walls are PF0=$10 -> clocks 12-15 (left) and 144-147 (right, mirrored). Clamps were at X=4/148 (inside/past walls).
Fix: FireX clamp 16..136 (ball 16-23 flush vs wall 12-15; ball 136-143 flush vs wall 144-147). FireY max 152->160 (flush vs bottom wall). EnemyX/Y clamps updated to match. Ember spawn X 16..135. NextRoom SfxT 16->32 (distinct room-enter fanfare).
Verified: py65 16/16 PASS with new clamps.

## v2.4 (Oct 6, 2026)
Cori: right/top good, left larger gap, bottom small gap + "sticky" (can't move left/right at bottom).
Fixes:
- Sticky: lateral block (Y>=153) was unconditional; now only blocks when actually in door shaft (X 66-85 AND Y>=153). Player at bottom wall (Y 153-158, X outside 66-85) can now move freely.
- Bottom: 156->158 (2px closer).
- Left wall: PF0 $10->$30 (4px->8px wide: 8-15 left, 144-151 right). Ball at X=0 (0-7) now 1px from wall (was 5px). Right unchanged (Cori said good).
Backup of v2.2 working version: firefly-v2.2-working.bin/asm.

## v2.5 (Oct 6, 2026)
Cori: bottom still sticky.
Root cause: lateral block (Y>=153, X 66-85) applied even when door CLOSED. Player at bottom wall at door X position got stuck.
Fix: only block lateral when DoorOpen=1 AND in shaft. If door closed, free move along bottom.

## v2.3 (Oct 6, 2026) - BEST VERSION per Cori
Consolidates all fixes + new features:
- Walls: right 132 (good), top good, left PF0 $30 (8px, 1px gap), bottom 158.
- Sticky bottom fixed (door-open check for lateral block).
- Door opens: NO regular ember spawns (player collected them all).
- NEW: Power ember (white-blue) spawns when door opens. Collect → gain freeze ability.
- Fire button: consume freeze → shade frozen 3 sec (icy blue), can't move.
- Door exit fanfare (SfxT=32).
Verified: py65 logic 16/16 + power 7/7 PASS.

## v2.3 final (Oct 6, 2026)
Cori feedback: power ember buggy (bottom wall disappeared), wants power ALONGSIDE regular (not after door), use-it-or-lose-it per room.
Changes:
- Fixed crash: EmberY=255 broke Y-sort (Rest=161, frame overrun). Now uses HB=0 to hide.
- 4-object Y-sort: ball, regular ember (M0), shade (P1), power ember (M1). New vars YD/HD/TD/Gap3, SwapCD, PowerEmberBlock.
- Power ember (white-blue, M1) spawns after 2nd regular collect, alongside regular. Player chooses which to risk.
- Collect power → HasFreeze=1. Fire → FreezeT=180 (3 sec), shade icy blue, no move.
- When door opens: regular hidden, power hidden (PowActive=0) — use it or lose it.
- Freeze/HasFreeze reset in NextRoom (per-room).
- M1 positioning via PosXM1 (HMM1/RESM1). COLUP1 shared: set per-block.
Verified: py65 4/4 new design tests PASS.

## v2.3 fixes round 2 (Oct 6, 2026)
Cori feedback: power ember showed permanently as thin line; wanted freeze indicator, ember hidden on door open, distinct sounds.
Changes:
- NUSIZ1=$20: M1 4px wide (was default 1px thin line).
- PowerEmberBlock checks PowActive: skips draw when not active (was always drawing 8 lines).
- Score blinks when HasFreeze=1 (freeze-available indicator near score).
- EmberBlock checks DoorOpen: regular ember hidden when door opens (was ghosting in upper-left).
- Power spawn: jmp NoHit instead of CheckPower on spawn frame (avoids same-frame double-collect double-sound).
- New sound timers: PowT ($B2, distinct distorted timbre AUDC0=$0C for power-up, priority over SfxT/MusT), FanT ($B3, 8-note rising scale 31,27,23,19,15,11,7,4 for room fanfare — reverse of death fall).
- Audio handlers moved after AudioDone (DoFan/DoPow) to keep death bne in range.
- NextRoom triggers FanT=1; power collect triggers PowT=30.
Verified: dasm builds clean 4096 bytes; py65 logic tests still PASS.
