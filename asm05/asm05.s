SECTION .data
newline db      0Ah

SECTION .text
global  _start

_start:
    ; check argc >= 2
    mov     rdi, [rsp]      ; argc
    cmp     rdi, 2
    jl      .exit_ok

    ; get argv[1]
    mov     rsi, [rsp+16]   ; pointer to argv[1]

    ; calculate string length
    mov     rdi, rsi
    xor     rcx, rcx
.strlen:
    cmp     byte [rdi+rcx], 0
    je      .print
    inc     rcx
    jmp     .strlen

.print:
    ; write string
    mov     rax, 1          ; sys_write
    mov     rdi, 1          ; stdout
    ; rsi already points to string
    mov     rdx, rcx        ; length
    syscall

    ; write newline
    mov     rax, 1
    mov     rdi, 1
    lea     rsi, [newline]
    mov     rdx, 1
    syscall

.exit_ok:
    mov     rax, 60
    xor     rdi, rdi
    syscall
