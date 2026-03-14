; asm15 - ELF x64 Detection
; Detect if a file is a valid ELF x64 binary.
; Exit 0 if yes, 1 if no.
; Checks: magic \x7fELF, class=2 (64-bit), machine=0x3E (x86-64)

section .bss
    buf resb 20          ; buffer to read ELF header (need at least 20 bytes)

section .text
    global _start

_start:
    ; Check argc >= 2
    mov rax, [rsp]       ; argc
    cmp rax, 2
    jl .not_elf

    ; Get argv[1] (filename)
    mov rdi, [rsp + 16]  ; argv[1]

    ; Open file: open(filename, O_RDONLY=0)
    mov rax, 2           ; sys_open
    xor rsi, rsi         ; O_RDONLY
    xor rdx, rdx         ; mode (unused for read)
    syscall
    cmp rax, 0
    jl .not_elf          ; open failed
    mov r12, rax         ; save fd

    ; Read 20 bytes from file
    mov rdi, r12         ; fd
    lea rsi, [buf]       ; buffer
    mov rdx, 20          ; count
    mov rax, 0           ; sys_read
    syscall
    cmp rax, 20
    jl .close_not_elf    ; file too small

    ; Close file
    mov rdi, r12
    mov rax, 3           ; sys_close
    syscall

    ; Check ELF magic: 0x7f 'E' 'L' 'F'
    cmp byte [buf], 0x7f
    jne .not_elf
    cmp byte [buf + 1], 'E'
    jne .not_elf
    cmp byte [buf + 2], 'L'
    jne .not_elf
    cmp byte [buf + 3], 'F'
    jne .not_elf

    ; Check class = 2 (64-bit) at offset 4
    cmp byte [buf + 4], 2
    jne .not_elf

    ; Check machine = 0x3E (x86-64) at offset 18 (little-endian 16-bit)
    cmp word [buf + 18], 0x3E
    jne .not_elf

    ; All checks passed - exit 0
    mov rax, 60
    xor rdi, rdi
    syscall

.close_not_elf:
    ; Close file then exit 1
    mov rdi, r12
    mov rax, 3           ; sys_close
    syscall

.not_elf:
    ; Exit 1
    mov rax, 60
    mov rdi, 1
    syscall
