SECTION .data
newline db      0Ah

SECTION .bss
input   resb    4096

SECTION .text
global  _start

_start:
    ; parse shift value from argv[1]
    mov     rsi, [rsp+16]   ; argv[1]
    call    atoi
    mov     r12, rax        ; shift value

    ; read string from stdin
    mov     rax, 0
    mov     rdi, 0
    lea     rsi, [input]
    mov     rdx, 4096
    syscall

    mov     r13, rax        ; bytes read
    cmp     r13, 0
    jle     .print

    ; strip trailing newline
    dec     r13
    cmp     byte [input+r13], 0Ah
    je      .cipher_start
    inc     r13

.cipher_start:
    xor     rcx, rcx        ; index

.cipher_loop:
    cmp     rcx, r13
    jge     .print

    movzx   rax, byte [input+rcx]

    ; check if lowercase letter
    cmp     al, 'a'
    jb      .check_upper
    cmp     al, 'z'
    ja      .no_shift
    ; shift lowercase
    sub     al, 'a'
    add     rax, r12
    xor     rdx, rdx
    push    rcx
    mov     rcx, 26
    div     rcx             ; rax / 26, remainder in rdx
    pop     rcx
    add     dl, 'a'
    mov     [input+rcx], dl
    jmp     .next_char

.check_upper:
    cmp     al, 'A'
    jb      .no_shift
    cmp     al, 'Z'
    ja      .no_shift
    ; shift uppercase
    sub     al, 'A'
    add     rax, r12
    xor     rdx, rdx
    push    rcx
    mov     rcx, 26
    div     rcx
    pop     rcx
    add     dl, 'A'
    mov     [input+rcx], dl
    jmp     .next_char

.no_shift:
    ; non-letter, keep as is

.next_char:
    inc     rcx
    jmp     .cipher_loop

.print:
    ; write result
    mov     rax, 1
    mov     rdi, 1
    lea     rsi, [input]
    mov     rdx, r13
    syscall

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
