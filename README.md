# Rabbit Scooter — C64

A Commodore 64 port of [rabbitroller](../rabbitroller), the Game & Watch
style LCD mini game, written in 6502 assembly (built with the ACME
assembler, using the same toolchain and layout as [c64-demo](../c64-demo)).

Rabbits hop toward you on a five-lane road. Steer your scooter left and
right to dodge them: a rabbit that reaches your lane is a **miss**, one
that passes in any other lane is a **point**. Three misses end the round.
The spawn rate and the rabbits' speed ramp up with your score, just like
in the original.

## Controls

| Input | Action |
|-------|--------|
| Joystick port 2 left/right, or `A` / `D` | change lane (auto-repeats while held) |
| Fire (or `SPACE`) | start / retry |

## How it works

- PAL frame loop synced by polling the raster beam (no interrupts), one
  state update per frame — title, play and game over are `updvec` states.
- The background is raster-split at the horizon: sky above, grass below.
  The road is a grey wedge of inverse-space characters between painted
  white edge lines, with trees along both shoulders.
- The player is hardware sprite 0; up to seven rabbits live on sprites
  1–7. Rabbits follow the road's perspective: a linear y ramp and a t²
  horizontal fan-out, both precomputed into tables at assembly time
  (`tables.asm`). Far rabbits use small sprite frames, near ones switch
  to big frames and finally to double-sized expanded sprites.
- Random lanes and speeds come from an 8-bit LFSR stirred with the
  free-running CIA timer.
- Sprite art sits below `$1000` so the VIC never sees the character ROM
  shadow instead of it.

## Files

| File | Contents |
|------|----------|
| `main.asm` | BASIC stub, init, frame loop, state dispatch |
| `defs.asm` | registers, constants, zero page, macros |
| `title.asm` | title screen: logo, parked scooters, demo rabbits |
| `play.asm` | gameplay: input, spawning, scoring, HUD |
| `over.asm` | game over box + retry |
| `common.asm` | shared routines: printing, road, input, RNG, rabbit positioning |
| `tables.asm` | assembly-time perspective and speed tables |
| `sprites.asm` | sprite art (scooter, 4+4 rabbit frames) |

## Build & run

```
make deps        # macOS: brew install acme vice
make build       # -> rabbit.prg
make run         # build + launch in VICE (x64sc)
```

The same targets are available as VS Code tasks. A test build that boots
straight into gameplay: `acme -DAUTOPLAY=1 -f cbm -o test.prg main.asm`.
