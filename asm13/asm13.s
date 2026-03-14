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
    jle     .is_palindrome

    ; strip trailing newline
    dec     rcx
    cmp     byte [input+rcx], 0Ah
    je      .check_start
    inc     rcx

.check_start:
    ; compare input[left] with input[right]
    mov     rsi, 0          ; left
    mov     rdi, rcx
    dec     rdi             ; right

.check_loop:
    cmp     rsi, rdi
    jge     .is_palindrome

    mov     al, [input+rsi]
    cmp     al, [input+rdi]
    jne     .not_palindrome

    inc     rsi
    dec     rdi
    jmp     .check_loop

.is_palindrome:
    mov     rax, 60
    xor     rdi, rdi        ; exit 0
    syscall

.not_palindrome:
    mov     rax, 60
    mov     rdi, 1          ; exit 1
    syscall
