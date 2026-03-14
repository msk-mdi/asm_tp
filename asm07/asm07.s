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

    ; parse number
    lea     rsi, [buf]
    xor     rax, rax
.parse:
    movzx   rcx, byte [rsi]
    cmp     cl, '0'
    jb      .parse_done
    cmp     cl, '9'
    ja      .parse_done
    sub     cl, '0'
    imul    rax, 10
    add     rax, rcx
    inc     rsi
    jmp     .parse
.parse_done:

    ; rax = number to test
    ; 0 and 1 are not prime
    cmp     rax, 2
    jl      .not_prime
    je      .is_prime

    ; check if even
    test    rax, 1
    jz      .not_prime

    ; try divisors from 3 to sqrt(n)
    mov     rbx, rax        ; rbx = n
    mov     rcx, 3          ; rcx = divisor

.check_loop:
    mov     rax, rcx
    imul    rax, rcx        ; rax = divisor^2
    cmp     rax, rbx
    jg      .is_prime       ; if divisor^2 > n, it's prime

    mov     rax, rbx
    xor     rdx, rdx
    div     rcx             ; n / divisor
    test    rdx, rdx
    jz      .not_prime      ; if remainder == 0, not prime

    add     rcx, 2          ; next odd divisor
    jmp     .check_loop

.is_prime:
    mov     rax, 60
    xor     rdi, rdi        ; exit 0
    syscall

.not_prime:
    mov     rax, 60
    mov     rdi, 1          ; exit 1
    syscall
