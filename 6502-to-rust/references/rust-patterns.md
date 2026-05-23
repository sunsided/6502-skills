# Raising IL to Idiomatic Rust

How to turn the (simplified) IL into Rust: flag helpers when you need them, the
faithful fallback, an idiom catalog (the high-value part), and verification.

## Flag helpers in Rust (use when a flag is genuinely live)

Rust's primitives give you the 6502 flags directly — don't hand-roll them:

```rust
// ADC: A + M + carry, returning (result, carry_out, overflow)
fn adc8(a: u8, m: u8, carry: bool) -> (u8, bool, bool) {
    let (s1, c1) = a.overflowing_add(m);
    let (r,  c2) = s1.overflowing_add(carry as u8);
    let carry_out = c1 || c2;
    let overflow = ((a ^ r) & (m ^ r) & 0x80) != 0;
    (r, carry_out, overflow)
}

// SBC is ADC of the complement (binary mode)
fn sbc8(a: u8, m: u8, carry: bool) -> (u8, bool, bool) {
    adc8(a, !m, carry)
}
```

For multi-byte arithmetic prefer Rust's carrying ops directly:
`u16`/`u32` math, or `a.carrying_add(b, c)` / `a.borrowing_sub(b, c)` when you
want to keep the carry chain explicit across bytes.

## Faithful CPU-state shape (verification oracle / SMC fallback)

When intent is unclear, the code self-modifies, or you need a test oracle,
emit a literal interpreter:

```rust
#[derive(Clone)]
struct Cpu {
    a: u8, x: u8, y: u8, sp: u8, pc: u16,
    c: bool, z: bool, i: bool, d: bool, v: bool, n: bool,
    mem: Vec<u8>,           // or [u8; 0x10000]
}
impl Cpu {
    fn lda(&mut self, m: u8) { self.a = m; self.set_nz(self.a); }
    fn set_nz(&mut self, v: u8) { self.z = v == 0; self.n = v & 0x80 != 0; }
    // ... one method per instruction, mirroring il-spec.md exactly
}
```
This is ugly on purpose: it is *provably equal* to the original and serves as
the oracle the idiomatic port is tested against.

## Idiom catalog — the high-value transformations

Recognizing these collapses many instructions into one clear Rust expression.

### 16-bit (and wider) add / subtract / compare

`CLC / ADC lo / ADC hi` (low byte first, carry chained) is a `u16` add:
```rust
let r = lo16(a).wrapping_add(lo16(b));        // CLC; LDA;ADC; ... ;LDA;ADC
let r = lo16(a).wrapping_sub(lo16(b));        // SEC; LDA;SBC; ... ;LDA;SBC
```
`SEC / SBC lo / SBC hi` then testing carry/zero is a 16-bit compare → use `<`,
`>=`, `==` on the reconstructed `u16`s. Reconstruct words with
`u16::from_le_bytes([lo, hi])` and write back with `.to_le_bytes()`.

### Shift-add multiply, subtract-shift divide

A loop that shifts one operand and conditionally adds the other (often 8 rounds,
using `ASL`/`ROL` through carry across a 16-bit product) is multiplication:
```rust
let product: u16 = (a as u16) * (b as u16);   // recovered 8x8 -> 16 multiply
```
The mirror image (shift dividend left, trial-subtract divisor, set quotient bit)
is division/modulo → `a / b`, `a % b`. Verify the rounding/range matches before
collapsing; if the original guards against div-by-zero, keep that.

### `(zp),Y` buffer walks → slices and iterators

The canonical "loop Y from 0, `LDA (ptr),Y`, process, `INY`, compare, branch"
is iteration over a slice:
```rust
for &byte in &mem[ptr..ptr + len] { process(byte); }      // bounded by a length
// or, terminated by a sentinel (e.g. high-bit set / zero byte):
let s = &mem[ptr..];
for &b in s { if b == 0 { break; } emit(b); }             // null/hi-bit terminator
```
A DCI string (high bit set on the last char — see the Merlin skill) becomes a
`take_while`/`for` that stops *after* the byte with bit 7 set.

### memcpy / memset

`LDA (src),Y / STA (dst),Y / INY / CPY #n / BNE` is `copy_from_slice`; storing a
constant is `fill`:
```rust
dst[..n].copy_from_slice(&src[..n]);
buf[..n].fill(value);
```

### Jump tables and RTS trampolines

`JMP (table,X)`, or the "push hi/lo of target-1 then RTS" trampoline, or an
index into a table of `DA` addresses, is dynamic dispatch → `match`:
```rust
match cmd {
    0 => do_move(),
    1 => do_jump(),
    _ => default(),
}
```
Recover the cases from the address table (each `DA entry` is one arm). This is
also where self-modifying dispatch must be made explicit rather than emulated.

### BCD arithmetic (decimal mode)

If the region runs under `SED`, port it as explicit BCD — e.g. score counters
on the C64/NES-style games (note: real NES has no BCD). Convert at the edges:
```rust
fn bcd_add(a: u8, b: u8, carry: bool) -> (u8, bool) { /* nibble-wise add+adjust */ }
```
or keep the values as packed BCD bytes if the display logic reads nibbles
directly. Do not silently treat it as binary.

### Bit masks and flags

`LDA flags / AND #mask / BNE` tests a bit; `ORA #mask` / `AND #~mask` set/clear.
Port a byte of independent bits to a `bitflags!`-style struct or named `bool`s
when their meanings are known; keep it a `u8` with `& / |` when they aren't.

## Mapping ROM calls and hardware to Rust

Every classified I/O / ROM access (see the 6502-memory-map skill) becomes a
typed operation, not memory:

```rust
trait Platform {
    fn chrout(&mut self, ch: u8);          // Apple COUT $FDED / C64 CHROUT $FFD2
    fn getin(&mut self) -> Option<u8>;     // GETIN $FFE4 / RDKEY $FD0C
    fn set_border(&mut self, color: u8);   // STA $D020 (C64)
    // ...one method per service the code actually uses
}
```
`JSR $FFD2` → `plat.chrout(self.a)`. `STA $D020` → `plat.set_border(self.a)`.
This keeps the port testable (mock the `Platform`) and portable (real impl vs
headless test impl). A `JSR` into a known FP routine (FADD/FMULT…) maps to Rust
`f64`/fixed-point math or a reimplementation of the 5-byte float if exact
bit-compatibility matters.

## Self-modifying code

If a store targets the instruction stream (common: patching an operand byte of a
`LDA abs` to index a table, or an RTS trampoline), you cannot express it as
static control flow. Options, in order of preference:
1. Recognize the *intent* — a patched operand is usually an array index or a
   function pointer; raise it to that (`table[i]`, a `match`, a `fn` pointer).
2. If the pattern is too tangled, port that region with the faithful `Cpu`
   interpreter and call into it.
Flag every SMC site explicitly in the port; never let it pass silently.

## Verifying the port

1. **Differential testing.** Run the faithful `Cpu` oracle and the idiomatic
   port on the same inputs (register/memory states) and assert equal observable
   results. Drive it with random and boundary inputs (`0`, `0xFF`, carry in/out,
   page-crossing addresses).
2. **Boundary cases first.** Wraparound (`0xFF+1`, `0x00-1`), carry/borrow
   chains, signed vs unsigned compares, page crossings, and decimal-mode values
   (`0x09+0x01`, `0x99+0x01`).
3. **Trace equivalence** for control flow: confirm the same branch decisions on
   representative inputs.
4. If a ROM routine was reimplemented, test it against documented behavior (e.g.
   FOUT formatting, CHROUT side effects) rather than against the ROM bytes.

## Emit checklist

- [ ] CPU variant, platform, and decimal-mode regions identified.
- [ ] Lifted to faithful IL; flags made explicit.
- [ ] Dead flags eliminated (proven, not assumed).
- [ ] Idioms collapsed (16-bit math, loops, multiply/divide, tables, BCD).
- [ ] Byte pairs raised to `u16`; buffers to slices.
- [ ] Every I/O/ROM access mapped to a typed `Platform` call.
- [ ] `wrapping_*` used for all register arithmetic.
- [ ] SMC sites handled explicitly.
- [ ] Differential test against the faithful oracle passes on boundary inputs.
