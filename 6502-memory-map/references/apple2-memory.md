# Apple II Memory Map, Soft Switches, and Banking

64K address space. The Apple II has no MMU in the modern sense; instead a wall
of *soft switches* in `$C000-$C0FF` toggle video modes, select memory banks, and
read hardware, all via plain LDA/STA (often the access itself is the action —
the data value is irrelevant).

## Overall layout (II / II+ / IIe)

| Range | Use |
|-------|-----|
| `$0000-$00FF` | zero page (see usage table below) |
| `$0100-$01FF` | 6502 stack |
| `$0200-$02FF` | GETLN keyboard input buffer |
| `$0300-$03CF` | small free area, often used for short routines |
| `$03D0-$03FF` | DOS 3.3 / Monitor vectors; BRK/reset/IRQ/NMI vectors (`$03F2` reset, `$03FB` NMI, `$03FE-$03FF` IRQ) |
| `$0400-$07FF` | text / lo-res **page 1** (interleaved; holds "screen holes" `$0478-$07F8` reserved for peripheral cards) |
| `$0800-$0BFF` | text / lo-res page 2; also default Applesoft program start (`$0801`) |
| `$0C00-$1FFF` | free RAM (Applesoft program / variables) |
| `$2000-$3FFF` | hi-res **page 1** (8 KB) |
| `$4000-$5FFF` | hi-res page 2 (8 KB) |
| `$6000-$95FF` | free RAM |
| `$9600-$BFFF` | DOS 3.3 lives here when loaded; ProDOS global page at `$BF00` |
| `$C000-$C0FF` | **soft switches & built-in I/O** (see below) |
| `$C100-$C7FF` | peripheral-card ROM, `$Cn00` for slot *n* |
| `$C800-$CFFF` | shared expansion ROM (`$CFFF` deselects) |
| `$D000-$DFFF` | ROM (Applesoft) **or** language-card RAM (two switchable 4K banks) |
| `$E000-$F7FF` | ROM (Applesoft / Integer BASIC) or language-card RAM |
| `$F800-$FFFF` | Monitor ROM (and `$FFFA-$FFFF` 6502 vectors) |

## Zero-page usage (who owns what)

Zero page is shared and contested. Rough conventional ownership:

| Range | Owner |
|-------|-------|
| `$00-$05` | Applesoft / scratch |
| `$06-$09` | usually safe for user programs |
| `$1A-$4F` | Monitor & Applesoft scratch (GBASL/H, etc.) |
| `$50-$66` | Applesoft scratch |
| `$67-$73` | **Applesoft program/variable pointers** (see apple2-rom-routines.md) |
| `$69-$8F` | Applesoft |
| `$9D-$A3` | **FAC** (floating-point accumulator) |
| `$A5-$AB` | **ARG** (floating-point argument) |
| `$B1-$C8` | CHRGET routine + TXTPTR (Applesoft) |
| `$CE-$CF` | sometimes free |
| `$D6-$F3` | Applesoft / state |
| `$F9-$FF` | Monitor / scratch |

The genuinely "safe for the user" bytes under DOS+Applesoft are few — commonly
cited safe spots are `$06-$09`, `$19-$1E`, `$CE-$CF`, `$FA-$FF` (verify against
the exact DOS/ProDOS in use). DOS 3.3 also uses `$3C-$3F` (MOVE), `$AA`–`$BF`
regions, and ProDOS reserves its own set.

## Soft switches `$C000-$C0FF`

Accessing the address performs the action; for paired switches the
even/odd address selects off/on. Read vs write matters only where noted.

### Video and keyboard

| Addr | Name | Action |
|------|------|--------|
| `$C000` | KBD | read: bit 7 = key available, bits 0-6 = ASCII |
| `$C010` | KBDSTRB | clear keyboard strobe (any access) |
| `$C030` | SPKR | toggle speaker (click) |
| `$C050` / `$C051` | TXTCLR / TXTSET | graphics / text |
| `$C052` / `$C053` | MIXCLR / MIXSET | full screen / mixed (4 text lines) |
| `$C054` / `$C055` | LOWSCR / HISCR | display page 1 / page 2 |
| `$C056` / `$C057` | LORES / HIRES | lo-res / hi-res |

### IIe / IIc auxiliary memory and 80-column (write to set)

| Addr | Name | Action |
|------|------|--------|
| `$C000`/`$C001` | 80STOREOFF/ON | enable PAGE2/HIRES to switch aux text/hires |
| `$C002`/`$C003` | RDMAINRAM/RDCARDRAM | read from main / aux 48K |
| `$C004`/`$C005` | WRMAINRAM/WRCARDRAM | write to main / aux 48K |
| `$C006`/`$C007` | SETSLOTCXROM/SETINTCXROM | `$C100-$CFFF` from slots / internal ROM |
| `$C008`/`$C009` | SETSTDZP/SETALTZP | main / aux zero page & stack |
| `$C00C`/`$C00D` | CLR80VID/SET80VID | 40 / 80 column |
| `$C00E`/`$C00F` | CLRALTCHAR/SETALTCHAR | primary / alternate character set |
| `$C011-$C01F` | status reads | bit 7 reflects the corresponding switch state |

### Annunciators and game I/O

| Addr | Action |
|------|--------|
| `$C058-$C05F` | annunciator outputs AN0-AN3 (off/on pairs) |
| `$C061-$C063` | switch inputs: open-apple, closed-apple, shift (bit 7) |
| `$C064-$C067` | paddle/joystick analog inputs PADDL0-3 (bit 7 while timing) |
| `$C070` | PTRIG: trigger paddle timers (then poll `$C064+`) |
| `$C020` | cassette output toggle; `$C060` cassette input |

## Language card / bank-switched `$D000-$FFFF` via `$C080-$C08F`

The 16K language card (standard on IIe and up) overlays RAM on the ROM region.
`$D000-$DFFF` has **two** 4K banks; `$E000-$FFFF` is shared.

| Addr | Read | Write | Bank |
|------|------|-------|------|
| `$C080` | RAM | (no write) | bank 2 |
| `$C081` | ROM | RAM (after 2 reads) | bank 2 |
| `$C082` | ROM | (no write) | bank 2 |
| `$C083` | RAM | RAM (after 2 reads) | bank 2 |
| `$C088` | RAM | (no write) | bank 1 |
| `$C089` | ROM | RAM (after 2 reads) | bank 1 |
| `$C08A` | ROM | (no write) | bank 1 |
| `$C08B` | RAM | RAM (after 2 reads) | bank 1 |

Write-enable requires **two consecutive reads** of the switch (a deliberate
guard against accidental writes). "Bank 1" vs "bank 2" selects which `$Dxxx`
RAM bank is visible.

## Screen memory addressing (the famous non-linearity)

Text/lo-res page 1 (`$0400`) and hi-res (`$2000`) are **interleaved**, not
linear. Text line *Y* does not start at `$0400 + 40*Y`; the 24 lines are
stored in three interleaved groups of 8, with 8 unused "screen hole" bytes per
block. Hi-res is worse: each line's base is a function of its Y split into
super-blocks / blocks / lines. Never assume `base + width*row`; use the Monitor
routines (BASCALC `$FBC1`, or HPOSN for hi-res) or a precomputed row-base table.

## ROM sizes per model (approximate)

| Model | CPU | System ROM |
|-------|-----|------------|
| Apple II | 6502 | 12K (`$D000-$FFFF`): Integer BASIC + Monitor; Applesoft on a plug-in ROM card |
| Apple II+ | 6502 | 12K: Applesoft + Monitor in ROM |
| Apple IIe | 6502 | 16K (CD + EF ROMs), bank-switched `$C100-$CFFF` internal ROM |
| Apple IIe enhanced | 65C02 | 16K, updated ROMs |
| Apple IIc | 65C02 | 16K+ built-in (plus ROM revisions for ports/disk) |
| Apple IIgs | 65816 | 128K (ROM 00/01) or 256K (ROM 03), with the toolbox and a 65C02-compatible classic-mode ROM |
