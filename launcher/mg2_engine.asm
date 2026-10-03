;==============================================================================
; mg2_engine.asm — rewrite MG2's 64KB save sector (READ-MODIFY-WRITE).
;------------------------------------------------------------------------------
; MG2 has exactly THREE save files (SNAK1/2/3). They share ONE 64KB sector at
; fixed offsets: slot i's record lives at window 0xA000 + i*0x100.
;   Record = [marker 0xA5 | len(2, LE) | data(len)].   marker != 0xA5 = empty.
; Flash can only flip 1->0, so to change one slot we must erase the whole 64KB
; sector and rewrite all three. The driver stages the three records in RAM
; (STAGE) first (the two unchanged ones read back from flash, the changed one
; built from MG2's buffer); this engine then erases the sector and reprograms
; each present record. NO append, NO accumulation — always exactly 3 files.
;
; Runs from RAM (0xE500): during AMD erase/program the whole flash reads as
; status, so nothing may execute from the cartridge. Entered with DI. The save
; sector is relative to MG2 and reached with MG2's own OFFR (no OFFR change);
; we only toggle WREN.  A = 0 ok / 0xFF fail (driver ignores A; MG2 sees A=0).
;
; Build: pasmo --bin mg2_engine.asm mg2_engine.bin   (org 0xE500)
;==============================================================================

YAMA_ENAR    equ 0x7FFF
ENAR_WREN    equ 0x10
SCC_REG_A000 equ 0xB000     ; bank register for the 0xA000-0xBFFF window
SAVE_BANK    equ 0x48       ; the game's 64KB save sector (first bank)
STAGE        equ 0xE5D0     ; 3 staged records, 118 bytes apart (built by driver)
STRIDE       equ 118        ; 3 (marker+len) + 115 data

    org 0xE500

engine:
    ld   a, SAVE_BANK
    ld   (SCC_REG_A000), a  ; map the sector (BEFORE WREN: banking freezes)
    ld   a, ENAR_WREN
    ld   (YAMA_ENAR), a
    call erase_sector
    jr   c, e_fail
    ld   hl, STAGE
    ld   de, 0xA000
    call prog_record
    jr   c, e_fail
    ld   hl, STAGE + STRIDE
    ld   de, 0xA100
    call prog_record
    jr   c, e_fail
    ld   hl, STAGE + 2*STRIDE
    ld   de, 0xA200
    call prog_record
    jr   c, e_fail
e_ok:
    xor  a
    ld   (YAMA_ENAR), a
    ret
e_fail:
    xor  a
    ld   (YAMA_ENAR), a
    ld   a, 0xFF
    ret

; --- erase the 64KB sector (bank mapped, WREN on). Carry set on timeout. ------
erase_sector:
    ld   a, 0xAA
    ld   (0xAAAA), a
    ld   a, 0x55
    ld   (0xA555), a
    ld   a, 0x80
    ld   (0xAAAA), a
    ld   a, 0xAA
    ld   (0xAAAA), a
    ld   a, 0x55
    ld   (0xA555), a
    ld   a, 0x30
    ld   (0xA000), a        ; sector erase (any address inside the sector)
    ld   bc, 0
er_poll:
    ld   a, (0xA000)
    cp   0xFF
    jr   z, er_done
    ld   d, 8
er_dly:
    dec  d
    jr   nz, er_dly
    dec  bc
    ld   a, b
    or   c
    jr   nz, er_poll
    scf                     ; timeout
    ret
er_done:
    or   a                  ; clear carry
    ret

; --- program one staged record. HL = staged record, DE = window dest. ---------
; marker != 0xA5 -> skip (leave erased 0xFF). Carry set on program failure.
prog_record:
    ld   a, (hl)
    cp   0xA5
    jr   z, pr_present
    or   a                  ; absent: clear carry and skip
    ret
pr_present:
    push hl
    inc  hl
    ld   c, (hl)            ; len_lo
    inc  hl
    ld   b, (hl)            ; len_hi
    pop  hl                 ; HL = record start
    inc  bc
    inc  bc
    inc  bc                 ; BC = 3 + len (bytes to program)
pr_loop:
    ld   a, b
    or   c
    jr   z, pr_done
    push bc
    ld   a, (hl)
    ld   c, a
    call pgm
    pop  bc
    ret  c                  ; propagate failure
    inc  hl
    inc  de
    dec  bc
    jr   pr_loop
pr_done:
    or   a
    ret

; --- program one byte: (DE) = C. WREN on. Carry set on failure. ---------------
pgm:
    ld   a, 0xAA
    ld   (0xAAAA), a
    ld   a, 0x55
    ld   (0xA555), a
    ld   a, 0xA0
    ld   (0xAAAA), a
    ld   a, c
    ld   (de), a
    push bc
    ld   b, 0
pg_poll:
    ld   a, (de)
    cp   c
    jr   z, pg_ok
    djnz pg_poll
    pop  bc
    scf
    ret
pg_ok:
    pop  bc
    or   a
    ret
engine_end:
    end
