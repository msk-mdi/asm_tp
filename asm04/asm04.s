SECTION .bss
buf     resb    32

SECTION .text
global  _start

_start:
    ; read from stdin
    mov     rax, 0          ; sys_read
    mov     rdi, 0          ; stdin
    lea     rsi, [buf]
    mov     rdx, 32
    syscall

    ; rax = bytes read
    cmp     rax, 0
    jle     .error          ; no input -> exit 2

    ; parse ASCII number to integer
    lea     rsi, [buf]
    xor     rcx, rcx        ; result = 0
    xor     rdx, rdx        ; index

.parse:
    movzx   rax, byte [rsi+rdx]
    cmp     al, 0Ah         ; newline
    je      .done_parse
    cmp     al, 0           ; null
    je      .done_parse
    cmp     al, '0'
    jb      .error
    cmp     al, '9'
    ja      .error
    sub     al, '0'
    imul    rcx, 10
    add     rcx, rax
    inc     rdx
    jmp     .parse

.done_parse:
    ; check if we parsed at least one digit
    cmp     rdx, 0
    je      .error

    ; check if even: test bit 0
    test    rcx, 1
    jnz     .odd

    ; even -> exit 0
    mov     rax, 60
    xor     rdi, rdi
    syscall

.odd:
    ; odd -> exit 1
    mov     rax, 60
    mov     rdi, 1
    syscall

.error:
    ; error -> exit 2
    mov     rax, 60
    mov     rdi, 2
    syscall
