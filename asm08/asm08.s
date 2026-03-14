SECTION .data
newline db      0Ah

SECTION .bss
buf     resb    32

SECTION .text
global  _start

_start:
    ; parse argv[1]
    mov     rsi, [rsp+16]   ; argv[1]
    call    atoi
    ; rax = N

    ; sum = 0, i = 1
    mov     rcx, rax        ; rcx = N
    xor     rax, rax        ; sum = 0
    mov     rbx, 1          ; i = 1

.sum_loop:
    cmp     rbx, rcx
    jge     .done
    add     rax, rbx
    inc     rbx
    jmp     .sum_loop

.done:
    ; print sum
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

; Convert ASCII string at rsi to integer in rax
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

; Print number in rax to stdout
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
