SECTION .data
newline db      0Ah

SECTION .bss
input   resb    4096

SECTION .text
global  _start

_start:
    ; read from stdin
    mov     rax, 0
    mov     rdi, 0
    lea     rsi, [input]
    mov     rdx, 4096
    syscall

    mov     rcx, rax        ; bytes read
    cmp     rcx, 0
    jle     .print_newline

    ; strip trailing newline
    dec     rcx
    cmp     byte [input+rcx], 0Ah
    je      .reverse_start
    inc     rcx

.reverse_start:
    ; reverse in place: swap input[i] and input[len-1-i]
    mov     rsi, 0          ; left index
    mov     rdi, rcx
    dec     rdi             ; right index

.reverse_loop:
    cmp     rsi, rdi
    jge     .print

    mov     al, [input+rsi]
    mov     bl, [input+rdi]
    mov     [input+rsi], bl
    mov     [input+rdi], al

    inc     rsi
    dec     rdi
    jmp     .reverse_loop

.print:
    ; write reversed string
    mov     rax, 1
    mov     rdi, 1
    lea     rsi, [input]
    mov     rdx, rcx
    syscall

.print_newline:
    ; write newline
    mov     rax, 1
    mov     rdi, 1
    lea     rsi, [newline]
    mov     rdx, 1
    syscall

    ; exit 0
    mov     rax, 60
    xor     rdi, rdi
    syscall
