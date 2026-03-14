SECTION .data
newline db      0Ah

SECTION .bss
buf     resb    32

SECTION .text
global  _start

_start:
    ; parse argv[1]
    mov     rsi, [rsp+16]
    call    atoi
    mov     r12, rax        ; a

    ; parse argv[2]
    mov     rsi, [rsp+24]
    call    atoi
    mov     r13, rax        ; b

    ; parse argv[3]
    mov     rsi, [rsp+32]
    call    atoi
    mov     r14, rax        ; c

    ; find max
    mov     rax, r12        ; max = a
    cmp     r13, rax
    cmovg   rax, r13        ; if b > max, max = b
    cmp     r14, rax
    cmovg   rax, r14        ; if c > max, max = c

    ; print max
    call    print_num

    ; print newline
    mov     rax, 1
    mov     rdi, 1
    lea     rsi, [newline]
    mov     rdx, 1
    syscall

    ; exit 0
    mov     rax, 60
    xor     rdi, rdi
    syscall

atoi:
    xor     rax, rax
.atoi_loop:
    movzx   rcx, byte [rsi]
    cmp     cl, 0
    je      .atoi_done
    cmp     cl, '0'
    jb      .atoi_done
    cmp     cl, '9'
    ja      .atoi_done
    sub     cl, '0'
    imul    rax, 10
    add     rax, rcx
    inc     rsi
    jmp     .atoi_loop
.atoi_done:
    ret

print_num:
    lea     rdi, [buf+31]
    mov     byte [rdi], 0
    mov     rcx, 10
    test    rax, rax
    jnz     .convert
    dec     rdi
    mov     byte [rdi], '0'
    jmp     .do_print
.convert:
    test    rax, rax
    jz      .do_print
    xor     rdx, rdx
    div     rcx
    add     dl, '0'
    dec     rdi
    mov     [rdi], dl
    jmp     .convert
.do_print:
    lea     rsi, [buf+31]
    sub     rsi, rdi
    mov     rdx, rsi
    mov     rsi, rdi
    mov     rax, 1
    mov     rdi, 1
    syscall
    ret
