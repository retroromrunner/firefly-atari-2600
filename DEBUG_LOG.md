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
