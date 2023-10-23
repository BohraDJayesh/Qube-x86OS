[org 0x7c00]
bits 16

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
    mov si, message
    call puts

    hlt

.halt:
    jmp .halt

message: db 'Hello world', 0


times 510-($-$$) db 0
dw 0xAA55
