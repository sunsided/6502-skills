---
name: 6502-to-rust
description: >-
  A workflow for porting 6502/65C02/65816 assembly (Apple II, Commodore 64,
  Atari 8-bit, NES, Merlin source, SWEET16) to modern Rust by first lifting it to
  an explicit
  intermediate language (IL) and then raising that IL to idiomatic Rust. Covers
  the two-stage method (faithful flag-explicit lift → idiom recovery → emit),
  modeling A/X/Y/flags/memory, translating carry/overflow/BCD correctly,
  recognizing idioms (16-bit math, multiply, pointer loops, jump tables), and
  mapping ROM/hardware calls. Use this skill WHENEVER the user wants to port,
  translate, convert, reimplement, decompile, or "rewrite in Rust/a modern
  language" any 6502-family assembly or disassembly, or asks how a 6502 routine
  would look in Rust, or how to build an intermediate representation of 6502
  code. Trigger on "port this assembly to Rust", "convert this 6502 routine",
  "reimplement this Apple II code". Pairs with the 6502-instruction-set,
  6502-merlin-assembler, 6502-memory-map, and 6502-sweet16 skills.
---

# Porting 6502 Assembly to Rust via an Intermediate Language

Porting 6502 code directly to readable Rust in one step usually fails: you
either produce an unreadable transliteration that carries every flag update, or
you "guess" the intent and silently drop edge-case behavior (carry, overflow,
wraparound, decimal mode). The reliable method is **two stages with an
intermediate language in between**:

```
6502 asm  ──lift──▶  IL (explicit, flag-faithful)  ──raise──▶  idiomatic Rust
                          │
                          └─ verifiable against the original, idiom-recoverable
```

The IL is the contract. It is mechanical and faithful enough to *trust*, and
structured enough to *recover intent* from. Get the IL right and the Rust falls
out; skip it and you will ship subtle arithmetic bugs.

## Prerequisites — gather these first

Before lifting a single instruction, establish the context (use the sibling
skills):

1. **CPU variant** (6502 / 65C02 / 65816) — decides which instructions and flag
   behaviors apply. See the 6502-instruction-set skill.
2. **Platform** (Apple II / C64 / NES / …) — decides what every non-RAM address
   *means*. See the 6502-memory-map skill. Classify each memory access as: plain
   RAM, hardware register (I/O effect), or ROM/OS service call.
3. **Assembler dialect** — if it's Merlin source, expand macros and re-bracket
   expressions first (6502-merlin-assembler skill). Decimal mode and SWEET16
   regions need special handling (6502-sweet16 skill).
4. **Decimal mode usage** — scan for `SED`/`CLD`; any ADC/SBC between them is
   BCD, not binary. NES code never uses it; C64/Apple II code sometimes does.

## The workflow

### Stage 1 — Lift to IL (faithful, mechanical)

Translate each instruction to IL operations that make the registers, every
affected flag, and every memory access **explicit**. Do not simplify yet.
`references/il-spec.md` gives the IL grammar and a per-instruction lifting table,
including the exact flag-producing helpers (`adc8`, `sbc8`, `cmp`, `setNZ`,
shifts). Build basic blocks at every branch target and label them.

The point of faithfulness here: the lifted IL should be executable in your head
(or literally) and match the 6502 bit-for-bit, including carry and overflow.

### Stage 2 — Raise the IL (recover intent)

Now transform the IL toward intent:
- **Dead-flag elimination.** Most flag writes are never read. Compute a flag
  only if a later branch/ADC actually consumes it before it's overwritten. This
  removes ~80% of the noise. (See "flag liveness" in `il-spec.md`.)
- **Idiom recognition.** Collapse recognized multi-instruction patterns into one
  high-level IL op: 16-/24-bit add/sub/compare, shift-add multiply and
  subtract-shift divide, `(zp),Y` buffer walks (→ slices/iterators), memcpy/
  memset loops, jump/branch tables, RTS-trampoline computed jumps, BCD
  arithmetic. The catalog with before/after is in `references/rust-patterns.md`.
- **Type recovery.** Promote pairs of bytes that are always used together (a
  low/high zero-page pair, a 16-bit pointer) to a single `u16`/pointer value.

### Stage 3 — Emit Rust

Choose the target shape based on the goal (`references/rust-patterns.md` has full
examples of each):

- **Idiomatic Rust** (default): functions taking/returning real types, `u8`/`u16`
  with `wrapping_*`/`checked_*`, `&mut [u8]` for buffers, structs for records,
  `enum`/`match` for jump tables. Flags are gone; intent is explicit. This is
  what you want for a maintainable port.
- **Faithful CPU-state Rust** (for verification or when intent is unclear): a
  `struct Cpu { a: u8, x: u8, y: u8, sp: u8, status: Flags, mem: [u8; N] }` with
  one method per instruction. Slower and ugly, but provably equal to the
  original — useful as a test oracle or for self-modifying code.

A good port often does both: keep the faithful version as a test oracle and
develop the idiomatic version against it.

## Correctness rules that are easy to get wrong

These cause the majority of porting bugs — see `references/rust-patterns.md` for
the exact Rust idioms:

1. **Carry is inverted on subtract.** `SBC` is `A + !M + C`; the original must
   `SEC` first. After `CMP`, carry set ⇔ `A >= M` (unsigned). Port compares with
   the right comparison operator, not by replicating the subtraction.
2. **All 8-bit arithmetic wraps.** Use `wrapping_add`/`wrapping_sub`; `255 + 1
   == 0`, `0 - 1 == 255`. A plain Rust `+` will panic in debug — never use it for
   register math.
3. **16-bit values are little-endian** in memory and built low-byte-first. A
   `LDA lo / STA / LDA hi / STA` pair is a `u16`; reassemble as
   `lo as u16 | (hi as u16) << 8`.
4. **Decimal mode** changes ADC/SBC entirely. Port BCD arithmetic as explicit
   BCD, or convert to/from binary at the boundaries — do not pretend it's binary.
5. **Indexed reads can cross page boundaries**; the 6502 wraps zero-page indexing
   within page 0 (`$FF,X` with X=1 → `$00`, not `$0100`). Preserve the wrap if
   the original relied on it.
6. **Self-modifying code and computed jumps** cannot be expressed as static Rust
   control flow. Detect them (a store into the code region, an RTS trampoline, a
   `JMP (table,X)`); port as a `match`/dispatch table or fall back to the
   faithful interpreter for that region.
7. **Hardware/ROM accesses are effects, not memory.** A `STA $D020` or
   `JSR $FFD2` must become a typed call (`set_border_color(a)`, `chrout(a)`), not
   an array write — otherwise the port loses its observable behavior.

## Worked micro-example (the shape of the output)

6502 (16-bit add of two zero-page words into a third):
```
        CLC
        LDA $06
        ADC $08
        STA $0A
        LDA $07
        ADC $09
        STA $0B
```
Lifted IL (faithful), then raised (idiom: 16-bit add recognized), then Rust:
```rust
// raised IL recognized this as: word[$0A] = word[$06] + word[$08] (mod 2^16)
let a = u16::from_le_bytes([mem[0x06], mem[0x07]]);
let b = u16::from_le_bytes([mem[0x08], mem[0x09]]);
let sum = a.wrapping_add(b);
mem[0x0A..0x0C].copy_from_slice(&sum.to_le_bytes());
```
The carry flag, the two separate byte adds, and the intermediate A loads all
vanish — but only because we proved (in IL) that the carry out of the high byte
is never read afterward. If it *were* read, the raised form would surface it as
a returned `bool`/`(u16, bool)`.

Read `references/il-spec.md` to lift, then `references/rust-patterns.md` to raise
and emit.
