;==============================================================================
; mg2_driver.asm — micro save-driver for Metal Gear 2: Solid Snake (Yamanooto)
;------------------------------------------------------------------------------
; MG2 saves through Game Master 2's SRAM-disk API: it maps a companion driver
; bank into the 0x8000 window and does CALL 0x8000 with C = function code and
; DE -> a parameter block (C3B0: name[5], +0D/0E buffer ptr = 0xC700, +0F/10
; length = 115). We do NOT embed GM2 — THIS bank is the "GM2" MG2 talks to.
;
; VERIFIED (RE of MG2's save module): MG2 decides success/failure ONLY from the
; returned A register (it never re-reads the param block), and its call wrapper
; (0x66F5) retries with delete(0x06) then prints "SRAM ERROR" whenever a call
; returns A != 0. So EVERY function here MUST return A = 0.
;
; SAVE MODEL — read-modify-write of ONE 64KB sector. MG2 has exactly THREE save
; files (SNAK1/2/3). They live at fixed offsets in a single 64KB sector at
; relative bank 0x48: slot i's record at window 0xA000 + i*0x100, format
;   [marker 0xA5 | len(2, LE) | data(len)].   marker != 0xA5 = empty slot.
; Flash can only flip 1->0, so to change one file we ERASE the whole 64KB sector
; and rewrite all three. On write we stage the three records in RAM (the two
; unchanged ones read back from flash, the changed one built from MG2's buffer),
; then the RAM engine erases the sector and reprograms them. No accumulation:
; always exactly the 3 current files. (Was 3x64KB dedicated sectors before.)
;
; This bank is embedded as relative bank 0x40 and mapped into 0x8000 by the
; patched MG2 helper (SCC register 0x9000; the patch preserves the driver's A).
; The save sector is reached through the 0xA000 window (SCC register 0xB000; MG2
; shadow at 0xC383) with MG2's own OFFR — no OFFR change. Reads run here (flash
; is readable); AMD erase/program runs from RAM (mg2_engine at 0xE500). MG2 calls
; us with DI + H.KEYI stubbed.
;
; Build: pasmo --bin mg2_driver.asm mg2_driver.bin   (org 0x8000, one 8KB bank)
;==============================================================================

SCC_REG_A000 equ 0xB000     ; bank register for the 0xA000-0xBFFF window
MG2_SHADOW3  equ 0xC383     ; MG2's shadow of the 0xA000-window bank register
SAVE_BANK    equ 0x48       ; the game's single 64KB save sector (first bank)
ENG_RAM      equ 0xE500
STAGE        equ 0xE5D0     ; 3 staged records, 118 bytes apart (must match engine)
STRIDE       equ 118        ; 3 (marker+len) + 115 data

; driver scratch (MG2-free RAM, below STAGE; the engine copied to 0xE500 stops
; well short of here, so these survive run_engine)
SC_SLOT      equ 0xE5C0     ; target slot 0/1/2
SC_BUF       equ 0xE5C1     ; u16: read dest / write data source (0xC700)
SC_LEN       equ 0xE5C3     ; u16: length

    org 0x8000

entry:
    ld   a, c
    cp   0x08
    jp   z, fn_read
    cp   0x09
    jp   z, fn_write
    xor  a                  ; create/open/close/delete/unknown -> A=0 (success)
    ret

; --- name[4] ('1'..'3') -> A = slot 0..2 -------------------------------------
get_slot:
    push hl
    ld   hl, 4
    add  hl, de
    ld   a, (hl)
    sub  '1'
    and  0x03
    pop  hl
    ret

map_save:                   ; map SAVE_BANK into the 0xA000 window
    ld   a, SAVE_BANK
    ld   (SCC_REG_A000), a
    ret
unmap_save:                 ; restore MG2's bank in the 0xA000 window
    ld   a, (MG2_SHADOW3)
    ld   (SCC_REG_A000), a
    ret

; read a word from (param + C) -> HL. Preserves DE.
pword:
    ld   l, c
    ld   h, 0
    add  hl, de
    ld   a, (hl)
    inc  hl
    ld   h, (hl)
    ld   l, a
    ret

;------------------------------------------------------------------------------
; C=0x08 READ — copy slot N's data to the caller's buffer, or zero-fill if the
; slot is empty. A=0 always.
;------------------------------------------------------------------------------
fn_read:
    call get_slot
    ld   (SC_SLOT), a
    ld   c, 13
    call pword              ; HL = dest buffer
    ld   (SC_BUF), hl
    ld   c, 15
    call pword              ; HL = requested length
    ld   (SC_LEN), hl

    call map_save
    ld   a, (SC_SLOT)
    add  a, 0xA0
    ld   h, a
    ld   l, 0               ; HL = 0xA000 + slot*0x100
    ld   a, (hl)
    cp   0xA5
    jr   nz, rd_empty
    inc  hl
    inc  hl
    inc  hl                 ; HL = data (skip marker + len)
    ld   de, (SC_BUF)
    ld   bc, (SC_LEN)
    ldir
    jr   rd_ret
rd_empty:
    ld   hl, (SC_BUF)
    ld   bc, (SC_LEN)
    ld   a, b
    or   c
    jr   z, rd_ret          ; length 0
    ld   (hl), 0
    dec  bc
    ld   a, b
    or   c
    jr   z, rd_ret          ; length 1
    ld   e, l
    ld   d, h
    inc  de
    ldir
rd_ret:
    call unmap_save
    xor  a
    ret

;------------------------------------------------------------------------------
; C=0x09 WRITE — read-modify-write the 64KB sector: stage the 3 records in RAM
; (this slot from MG2's buffer, the other two read back from flash), then erase
; the sector and reprogram all three. A=0 always.
;------------------------------------------------------------------------------
fn_write:
    call get_slot
    ld   (SC_SLOT), a
    ld   c, 13
    call pword              ; HL = data buffer (0xC700)
    ld   (SC_BUF), hl
    ld   c, 15
    call pword              ; HL = length
    ld   (SC_LEN), hl

    call map_save
    ld   b, 0
    call stage_one
    ld   b, 1
    call stage_one
    ld   b, 2
    call stage_one
    call run_engine         ; erase + reprogram the 3 records from STAGE
    call unmap_save
    xor  a
    ret

;------------------------------------------------------------------------------
; stage slot B (0..2) into STAGE + B*STRIDE.
;   B == current slot -> build [0xA5 | len | data-from-0xC700].
;   otherwise         -> copy the record straight from flash (0xA000 + B*0x100).
;------------------------------------------------------------------------------
stage_one:
    ld   hl, STAGE
    ld   a, b
    or   a
    jr   z, so_ready
    ld   de, STRIDE
so_add:
    add  hl, de
    dec  a
    jr   nz, so_add
so_ready:
    push hl                 ; STAGE dest
    ld   a, (SC_SLOT)
    cp   b
    jr   z, so_current
    ; other slot: copy STRIDE bytes from flash window 0xA000 + B*0x100
    ld   a, 0xA0
    add  a, b
    ld   d, a
    ld   e, 0               ; DE = flash src
    pop  hl                 ; HL = STAGE dest
    ex   de, hl             ; HL = src, DE = dest
    ld   bc, STRIDE
    ldir
    ret
so_current:
    pop  hl                 ; HL = STAGE dest
    ld   (hl), 0xA5         ; marker
    inc  hl
    ld   a, (SC_LEN)
    ld   (hl), a            ; len_lo
    inc  hl
    ld   a, (SC_LEN + 1)
    ld   (hl), a            ; len_hi
    inc  hl                 ; HL = dest + 3 (data area)
    ld   de, (SC_BUF)       ; 0xC700
    ex   de, hl             ; HL = 0xC700, DE = dest+3
    ld   bc, (SC_LEN)
    ldir
    ret

;------------------------------------------------------------------------------
; copy the flash engine to RAM and run it.
;------------------------------------------------------------------------------
run_engine:
    ld   hl, engine_blob
    ld   de, ENG_RAM
    ld   bc, engine_blob_end - engine_blob
    ldir
    call ENG_RAM
    ret

engine_blob:
    incbin "mg2_engine.bin"
engine_blob_end:

    ds   0x2000 - ($ - 0x8000), 0xFF
    end
