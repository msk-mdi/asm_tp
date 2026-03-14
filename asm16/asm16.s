; asm16 - Binary Patching
; Patch asm01 binary to print 'H4CK' instead of '1337'.
; Opens file from argv[1], finds "1337" bytes, replaces with "H4CK".

section .data
    search db '1337'       ; 4 bytes to search for
    replace db 'H4CK'     ; 4 bytes to replace with

section .bss
    buf resb 65536         ; 64KB buffer for reading the binary

section .text
    global _start

_start:
    ; Check argc >= 2
    mov rax, [rsp]
    cmp rax, 2
    jl .error

    ; Open file with O_RDWR (2)
    mov rdi, [rsp + 16]   ; argv[1] = filename
    mov rax, 2            ; sys_open
    mov rsi, 2            ; O_RDWR
    xor rdx, rdx
    syscall
    cmp rax, 0
    jl .error
    mov r12, rax          ; save fd

    ; Read entire file into buffer
    mov rdi, r12          ; fd
    lea rsi, [buf]        ; buffer
    mov rdx, 65536        ; max bytes
    mov rax, 0            ; sys_read
    syscall
    cmp rax, 0
    jle .close_error
    mov r13, rax          ; r13 = file size (bytes read)

    ; Search for "1337" in buffer
    lea rsi, [buf]        ; pointer to buffer
    mov rcx, r13          ; bytes to scan
    sub rcx, 3            ; need at least 4 bytes remaining
    jle .close_error      ; file too small

.search_loop:
    cmp byte [rsi], '1'
    jne .next
    cmp byte [rsi + 1], '3'
    jne .next
    cmp byte [rsi + 2], '3'
    jne .next
    cmp byte [rsi + 3], '7'
    je .found
.next:
    inc rsi
    dec rcx
    jnz .search_loop
    jmp .close_error      ; not found

.found:
    ; Calculate offset from start of buffer
    lea rax, [buf]
    sub rsi, rax          ; rsi = offset of "1337" in file
    mov r14, rsi          ; save offset

    ; Seek to offset: lseek(fd, offset, SEEK_SET=0)
    mov rdi, r12          ; fd
    mov rsi, r14          ; offset
    xor rdx, rdx          ; SEEK_SET = 0
    mov rax, 8            ; sys_lseek
    syscall
    cmp rax, 0
    jl .close_error

    ; Write "H4CK" at that position
    mov rdi, r12          ; fd
    lea rsi, [replace]    ; "H4CK"
    mov rdx, 4            ; 4 bytes
    mov rax, 1            ; sys_write
    syscall
    cmp rax, 4
    jne .close_error

    ; Close file
    mov rdi, r12
    mov rax, 3            ; sys_close
    syscall

    ; Exit 0
    mov rax, 60
    xor rdi, rdi
    syscall

.close_error:
    mov rdi, r12
    mov rax, 3
    syscall

.error:
    mov rax, 60
    mov rdi, 1
    syscall
