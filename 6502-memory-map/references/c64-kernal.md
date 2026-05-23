# Commodore 64 KERNAL & BASIC ROM Routines

Unlike the Apple II, the C64 has a deliberate, stable **KERNAL jump table** in
the top page of ROM (`$FF81-$FFF3`). Each entry is a `JMP` to the real routine;
programs call the jump-table address so the API survives ROM revisions. Always
call the `$FFxx` entry, never the internal address.

KERNAL ROM occupies `$E000-$FFFF` (visible when `$01` bit 1 = 1). To use these,
the KERNAL ROM must be banked in.

## KERNAL jump table (`$FF81-$FFF3`)

| Addr | Name | Function | Register convention |
|------|------|----------|---------------------|
| `$FF81` | CINT | init screen editor & VIC | — |
| `$FF84` | IOINIT | init CIA chips, IRQ | — |
| `$FF87` | RAMTAS | RAM test, clear, set pointers | — |
| `$FF8A` | RESTOR | restore default KERNAL vectors | — |
| `$FF8D` | VECTOR | read/set the RAM vector table | C: set/read; X/Y → table |
| `$FF90` | SETMSG | control KERNAL messages | A = flags |
| `$FF93` | SECOND | send secondary addr after LISTEN | A = sec addr |
| `$FF96` | TKSA | send secondary addr after TALK | A = sec addr |
| `$FF99` | MEMTOP | read/set top of RAM | C: read/set; X/Y |
| `$FF9C` | MEMBOT | read/set bottom of RAM | C: read/set; X/Y |
| `$FF9F` | SCNKEY | scan the keyboard | — |
| `$FFA2` | SETTMO | set IEEE timeout flag | A |
| `$FFA5` | ACPTR | input a byte from serial bus | → A |
| `$FFA8` | CIOUT | output a byte to serial bus | A |
| `$FFAB` | UNTLK | send UNTALK on serial bus | — |
| `$FFAE` | UNLSN | send UNLISTEN on serial bus | — |
| `$FFB1` | LISTEN | command a device to LISTEN | A = device |
| `$FFB4` | TALK | command a device to TALK | A = device |
| `$FFB7` | READST | read I/O status word (ST) | → A |
| `$FFBA` | SETLFS | set logical file, device, secondary | A=lfn, X=dev, Y=sec |
| `$FFBD` | SETNAM | set filename | A=len, X/Y → name |
| `$FFC0` | OPEN | open a logical file | (uses SETLFS/SETNAM state) |
| `$FFC3` | CLOSE | close a logical file | A = logical file # |
| `$FFC6` | CHKIN | set input channel | X = logical file # |
| `$FFC9` | CHKOUT | set output channel | X = logical file # |
| `$FFCC` | CLRCHN | restore default I/O channels | — |
| `$FFCF` | CHRIN | input one character | → A |
| `$FFD2` | **CHROUT** | output one character (the workhorse) | A = PETSCII char |
| `$FFD5` | LOAD | load/verify from device | A=0 load/1 verify, X/Y=addr; → X/Y end |
| `$FFD8` | SAVE | save to device | A = ZP ptr to start, X/Y = end |
| `$FFDB` | SETTIM | set time-of-day clock | A/X/Y |
| `$FFDE` | RDTIM | read time-of-day clock | → A/X/Y |
| `$FFE1` | STOP | test the STOP key | Z set if pressed |
| `$FFE4` | GETIN | get a char from the keyboard buffer | → A (0 = none) |
| `$FFE7` | CLALL | close all files & channels | — |
| `$FFEA` | UDTIM | update the jiffy clock | — |
| `$FFED` | SCREEN | return screen dimensions | → X=cols, Y=rows |
| `$FFF0` | PLOT | read/set cursor row,col | C: set(0)/read(1); X=row, Y=col |
| `$FFF3` | IOBASE | return base address of I/O | → X/Y = `$DC00` |

### The two you'll see constantly

- **`JSR $FFD2` (CHROUT)** — print the PETSCII character in A. Ports to "output
  char A". Note PETSCII ≠ ASCII (e.g. `$0D` = CR, `$93` = clear screen, `$05`/
  `$1C…` = color codes, letters are in a different case-mapping).
- **`JSR $FFE4` (GETIN)** — non-blocking read of the keyboard buffer; A = 0 when
  empty. The blocking line/char reads are CHRIN/`$FFCF`.

## Hardware vectors (`$FFFA-$FFFF`)

| Vector | Addr | Default KERNAL target |
|--------|------|------------------------|
| NMI | `$FFFA` | `$FE43` |
| RESET | `$FFFC` | `$FCE2` |
| IRQ/BRK | `$FFFE` | `$FF48` |

These point into ROM; the *RAM* vectors at `$0314` (IRQ), `$0316` (BRK),
`$0318` (NMI) are where programs hook, because the ROM handlers jump through
them. A game that "takes over the IRQ" stores its handler address into
`$0314/$0315`.

## BASIC ROM (`$A000-$BFFF`) and floating point

BASIC is Microsoft 6502 BASIC (same lineage as Applesoft, different addresses).
Cold start `$A000→$E394`, warm `$A002→$E37B`. The floating-point package mirrors
Applesoft's: a 5-byte float, FAC1 at zero page `$61-$66`, FAC2/ARG at `$69-$6E`.
Commonly used FP entry points (verify against the exact ROM revision):

| Addr | Name | Function |
|------|------|----------|
| `$BBA2` | MOVFM | load FAC1 from memory at (A/Y) |
| `$BBD4` | MOVMF | store (pack) FAC1 to memory at (X/Y) |
| `$B867` / `$B86A` | FADD / FADDT | FAC1 = FAC1 + memory / + FAC2 |
| `$B850` / `$B853` | FSUB / FSUBT | subtract |
| `$BA28` / `$BA2B` | FMULT / FMULTT | multiply |
| `$BB0F` / `$BB12` | FDIV / FDIVT | divide |
| `$BDDD` | FOUT | FAC1 → ASCII string at `$0100` |
| `$B391` | GIVAYF | float the signed integer in (A=hi, Y=lo) into FAC1 |

Because the C64 and Applesoft FP packages share a design, the *layout* (exponent
+ 4 mantissa bytes + sign, excess-128 exponent, normalized with an implied bit)
is the same — only the addresses differ. See `apple2-rom-routines.md` for the
parallel Apple II entry points.
