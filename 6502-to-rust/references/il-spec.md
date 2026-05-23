# The Intermediate Language: Grammar and Lifting

The IL is a small, explicit, side-effect-honest representation of 6502 code. It
is not a real language — it's a thinking and bookkeeping tool. Write it as
commented pseudocode. Its job: make every register, flag, and memory effect
visible so the lift is *trustworthy*, then be regular enough to *simplify*.

## Values and state

- Registers: `A`, `X`, `Y` (u8), `SP` (u8), and the 16-bit `PC` (only needed for
  computed flow). On 65816 also `A16`, `X16`, `Y16`, `D`, `DBR`, `PBR` and the
  mode bits `E`, `M`, `Xf` (see the 65816 reference).
- Flags as booleans: `N V D I Z C` (B is not a real register).
- Memory: three *distinct* access forms, chosen by classifying the address with
  the 6502-memory-map skill:
  - `ram[addr]` — plain read/write RAM.
  - `io_r(addr)` / `io_w(addr, v)` — hardware register access (an *effect*).
  - `rom_call(addr)` / a named service — a `JSR` to a known ROM/OS routine.
- Temporaries: `t0, t1, …` (SSA-ish; introduce a fresh temp per intermediate
  value to keep data flow explicit).

## Flag-producing helpers (lift arithmetic through these — do not inline)

These capture the exact 6502 semantics. Defining them once keeps every lift
correct.

```
setNZ(v)        : N = (v & 0x80) != 0 ;  Z = (v == 0)

adc8(a, m, c)   -> (r, c_out, v_out):           # binary mode
    s     = a + m + (c?1:0)                      # full-width sum
    r     = s & 0xFF
    c_out = s > 0xFF
    v_out = ((a ^ r) & (m ^ r) & 0x80) != 0      # signed overflow
    # then setNZ(r)

sbc8(a, m, c)   -> (r, c_out, v_out):           # binary mode
    = adc8(a, m ^ 0xFF, c)                        # SBC is ADC of the complement

cmp(reg, m)     -> sets N, Z, C:                # CMP/CPX/CPY (no V, no store)
    d = reg - m  (mod 256)
    C = reg >= m            # unsigned
    setNZ(d)

asl(v) -> (r,c): c=(v&0x80)!=0; r=(v<<1)&0xFF; setNZ(r)
lsr(v) -> (r,c): c=(v&0x01)!=0; r=v>>1;        setNZ(r)
rol(v,cin) -> (r,c): c=(v&0x80)!=0; r=((v<<1)|(cin?1:0))&0xFF; setNZ(r)
ror(v,cin) -> (r,c): c=(v&0x01)!=0; r=(v>>1)|(cin?0x80:0);     setNZ(r)
```

`adc8`/`sbc8` in **decimal mode (D=1)** follow BCD rules instead; lift those to a
`adc_bcd`/`sbc_bcd` helper and flag the region so the raise stage handles it
explicitly. (NMOS leaves N/V/Z garbage in decimal mode; the 65C02 defines them.)

## Per-instruction lifting

Effective-address resolution happens first (per addressing mode), producing the
operand `M` (a value for reads, an lvalue for writes). Then:

| 6502 | IL |
|------|----|
| `LDA M` | `A = M; setNZ(A)` |
| `LDX M` / `LDY M` | `X = M; setNZ(X)` / `Y = M; setNZ(Y)` |
| `STA M` | `M = A` (M may be `ram[..]` / `io_w(..)`) |
| `STX/STY M` | `M = X` / `M = Y` |
| `TAX`/`TAY`/`TXA`/`TYA`/`TSX` | copy + `setNZ(dest)` |
| `TXS` | `SP = X`  *(no flags)* |
| `ADC M` | `(A, C, V) = adc8(A, M, C)` |
| `SBC M` | `(A, C, V) = sbc8(A, M, C)` |
| `CMP M` | `cmp(A, M)` ; `CPX/CPY` → `cmp(X/Y, M)` |
| `AND/ORA/EOR M` | `A = A op M; setNZ(A)` |
| `BIT M` | `Z = (A & M)==0; N = (M&0x80)!=0; V = (M&0x40)!=0` |
| `ASL/LSR/ROL/ROR` | `(M, C) = shift(M[, C])` (M = A in accumulator mode) |
| `INC/DEC M` | `M = (M ± 1) & 0xFF; setNZ(M)` |
| `INX/INY/DEX/DEY` | `reg = (reg ± 1) & 0xFF; setNZ(reg)` |
| `JMP addr` | `goto Laddr` |
| `JMP (ptr)` | `goto *read16(ptr)` (NMOS page-bug: see addressing-modes.md) |
| `JSR addr` | `call Laddr` (push return; model as a call) |
| `RTS` / `RTI` | `return` (RTI also restores flags from the pulled byte) |
| `PHA/PHP/PLA/PLP` | explicit `push(..)`/`pull(..)` of A or the packed status |
| `Bcc target` | `if cond goto Ltarget` (cond per the branch table below) |
| `CLC/SEC/CLD/SED/CLI/SEI/CLV` | set the named flag |
| `BRK` | `trap()` / software interrupt |
| `NOP` | (nothing) |

Branch conditions: `BCC`→`!C`, `BCS`→`C`, `BNE`→`!Z`, `BEQ`→`Z`, `BPL`→`!N`,
`BMI`→`N`, `BVC`→`!V`, `BVS`→`V`.

65C02 extras: `STZ M`→`M=0`; `BRA`→`goto`; `PHX/PLX/…`; `INC A`/`DEC A`;
`(zp)`→ pointer deref with index 0; `TSB`→`Z=(A&M)==0; M=M|A`; `TRB`→
`Z=(A&M)==0; M=M&~A`. 65816 mode/width and long modes per the 65816 reference.

## Control flow

- Split the routine into **basic blocks** at every branch target and after every
  branch/jump/return. Label them `L<hexaddr>`.
- A block is a straight-line list of IL ops ending in a branch/jump/return.
- Represent the whole routine as a labeled block graph; this is what you pattern-
  match and ultimately turn into Rust control flow (`loop`/`while`/`match`).
- `JSR`/`RTS` map to calls/returns; recover a real function boundary at each
  `JSR` target that is only ever entered via `JSR`.

## Loop trip counts — count iterations exactly (the off-by-256 trap)

6502 loops come in two shapes with **different behavior at zero**. Getting this
wrong produces off-by-one or off-by-256 bugs that look fine on typical inputs.
Trace the first iteration and the `n == 0` case explicitly before you port a loop.

- **Decrement do-while** — `LDX #n … DEX / BNE`, or `SEC / SBC #1 / BNE`. The
  test is at the *bottom*, after the decrement. Runs `n` times for n ≥ 1, and
  **256 times when n = 0** (the counter wraps `0 → 255 → … → 0`). Port as
  `for _ in 0..(if n == 0 { 256 } else { n })`.

- **Count-up while-less-than** — `LDY #0 / INY / CPY #n / BCC`. It increments
  *first*, then branches while `Y < n` (carry clear). Runs `max(n, 1)` times:
  both `n = 0` and `n = 1` give exactly **1** iteration, because the first `INY`
  makes Y = 1 and `1 >= 0` (and `1 >= 1`) sets carry, exiting immediately. Port
  as `for _ in 0..n.max(1)` — **not** 256 at zero. (This is the opposite of the
  decrement loop, and the two diverge precisely at `n = 0`.)

When a 16-bit delay is two nested count-up loops (inner over the low byte, outer
over the high byte), the total trip count is `hi.max(1) * lo.max(1)`, not
`hi + lo` and not `(hi<<8)|lo`.

## Flag liveness (the key simplification)

A flag assignment is **dead** if, on every path from it, the flag is overwritten
before it is read. Compute this with a standard backward pass:

1. At each branch, the tested flag(s) are *live-in*.
2. `adc8`/`sbc8` read `C` (live-in); they and `cmp`/`setNZ`/shifts *define*
   flags (kill prior defs).
3. Walk backward; a `setNZ`/`(.., C, V)=` whose results are all killed before any
   use is dead — drop it (keep the value computation, drop the flag side effects).

In practice most `setNZ` calls are dead (the code loads a value and uses it
without testing). After this pass the IL reads like ordinary code with only the
flags that actually drive decisions remaining — which is exactly what you can
turn into clean Rust. **Never** drop a flag without proving it dead: a faraway
`BCS` or a chained `ADC` (multi-byte arithmetic) is a real use.

## Example lift (faithful, before raising)

```
        SEC
        LDA $10
        SBC $12
        STA $14
```
```
C = true                                  # SEC
t0 = ram[0x10]; A = t0; setNZ(A)          # LDA  (setNZ here is dead → later dropped)
t1 = ram[0x12]
(A, C, V) = sbc8(A, t1, C); setNZ(A)      # SBC  (C live? only if a following SBC/BCS uses it)
ram[0x14] = A
```
If nothing downstream reads `C`/`V`/`N`/`Z`, liveness reduces this to
`ram[0x14] = ram[0x10].wrapping_sub(ram[0x12])`. If a high-byte `SBC` follows,
`C` is live and the raise stage keeps a borrow — i.e. it's a 16-bit subtract.
Continue in `rust-patterns.md`.
