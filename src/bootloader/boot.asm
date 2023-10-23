[org 0x7c00]
;bits 16

%define ENDL 0x0D, 0x0A

; First three bytes should be short jump instructions followed by nop
; FAT12 Header
jmp short start
nop

; OEM Identifier, the first 8 bytes are the version of DOS used. (3-10), as the first three are used for defing the fat12 header.
; All of the mentioned are as per the wiki.osdev.org
bdb_oem:                    db 'MSWIN4.1' ; 8bytes
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880 ; ( 2880 * 512 = 1.44 MB )
bdb_media_descriptor_type:  db 0F0h
bdb_sectors_per_fat:        dw 9
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; Extended Boot Record.

ebr_drive_number:           db 0 ; 0x00 floppy, 0x80 hdd
                            db 0
ebr_signature:              db 29h
ebr_volume_id:              db 12h, 34h, 56h, 78h ; seriel number
ebr_volume_label:           db 'QUBE OS'
ebr_system_id:              db 'FAT12    '

;
; Code goes here
;


start:
    jmp main

; printing string to the scren
puts:
    push si
    push ax

.loop:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0e
    int 0x10
    jmp .loop


.done:
    pop ax
    pop si
    ret

main:
    ; Setting up data segmetns.
    mov ax, 0 ; Because can't write to es/ds directly.
    mov ds, ax
    mov es, ax

    ; setup stack
    mov ss, ax
    mov sp, 0x7c00 ; Our Code starts from here, where bios is loaded.

    ;
    ; Reading something from the disk.
    ;
    ; Start from setting dl to drive number
    mov dl, ebr_drive_number
    mov ax, 1                           ; LBA = 1, 2nd sector 
    mov cl, 1
    mov bx, 0x7c00
    call disk_read                      ; Data should be after bootloader.


    ;
    mov si, message
    call puts

    hlt

;
;Disk routines - This whole section is inpired by NBOS.
;

;
; We've to write the lba to chs as well, plus the disk routines. So bios expects parameters in ax, and ret in cx
; ax: LBA address
; Returns:
; - cx [bits 0-5]: sector number
; - cx [bits 6-15]: cylinder
; - dh: head
;
; We've 2 constants no of sector/track || /cylinder and 
; Sector = (LBA % sector per track) + 1
; Head = (LBA / sector per track ) % heads
; Cylinder = (LBA / sector per track ) / heads per cylinder
; Logical address block stored in ax
;

lba_to_chs:

    push ax
    push dx

    xor dx, dx
    div word [bdb_sectors_per_track] ; ax will store LBA / sector per track = Cylinder
                                        ; dx will store remainder LBA % sector per track = Sector - 1
    inc dx
    mov cx, dx

    xor dx, dx
    div word [bdb_heads]            ; ax = (LBA / Sector per track) / bdb_heads = 
                                    ; dx = (LBA / Sector per track) % bdb_heads =  Head
    mov dh, dl                      ; dh = head number
    mov ch, al                      ; ch (lower 8 bit of ax) = cylinder
    shl ah, 6                       ; shift al by 6 positions.
    or cl, ah                       ; put upper 2 bits of cylinder in cl
    
    pop ax
    mov dl, al
    pop ax


;
; Methods to read sectors from the disk
;Parameters :
;   ax : LBA address
;   cl : no of sectors to read
;   dl : drive number
;   es:bx: memory address where to store read data.

disk_read:

    push ax
    push bx
    push cx
    push dx
    push di
    push cx ; Function will overwrite our register so push it to stack.
    call lba_to_chs
    pop ax                          ; al = number of sectors to read.
    mov ah, 02h
    mov di, 3                       ; We may have to retry the operation atmost 3 times, it's due to how floppy disk works.


.retry:
    pusha                           ; Don't know how many registers will be overwrited, so pusha.
    stc                             ; some bios don't set it, so precautionary measures we had set it.

    int 13h                         ; If the operation is cleared the carry flag would be flagged.
    jnc .done
    popa    
    call disk_read

    dec di
    test di, di
    jnz .retry

.fail:
    jmp floppy_error

.done:
    popa
    
    push di
    push dx
    push cx
    push bx
    push ax
    ret

;
; Disk Resetting.
; Parameters -
;   dl: drive number
;   
;

disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h                 ; If the interrupt fail we will jump to the floppy disk error.
    jc floppy_error
    popa
    ret

;
; Error Handling
;

floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h                         ; wait for keypress
    jmp 0FFFFh:0                      ; Jump to begining of BIOS, or basically reboots.

.halt:
    cli                             ; disable interrupts , so can't get out of halt state.
    jmp .halt

message: db 'Hello world', 0
msg_read_failed: db 'Read from Disk failed !', 0

times 510-($-$$) db 0
dw 0xAA55
