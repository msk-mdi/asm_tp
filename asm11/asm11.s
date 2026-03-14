SECTION .data
newline db      0Ah

SECTION .bss
input   resb    4096
buf     resb    32

SECTION .text
global  _start

_start:
    ; read from stdin
    mov     rax, 0          ; sys_read
    mov     rdi, 0          ; stdin
    lea     rsi, [input]
    mov     rdx, 4096
    syscall

    mov     rcx, rax        ; bytes read
    lea     rsi, [input]
    xor     r12, r12        ; vowel count = 0

    ; strip trailing newline
    cmp     rcx, 0
    jle     .print
    dec     rcx
    cmp     byte [rsi+rcx], 0Ah
    je      .count_start
    inc     rcx             ; no newline, keep the byte

.count_start:
    xor     rdx, rdx        ; index

.count_loop:
    cmp     rdx, rcx
    jge     .print
    movzx   rax, byte [rsi+rdx]

    ; convert to lowercase for comparison
    cmp     al, 'A'
    jb      .next
    cmp     al, 'Z'
    ja      .check_lower
    or      al, 0x20        ; to lowercase

.check_lower:
    cmp     al, 'a'
    je      .is_vowel
    cmp     al, 'e'
    je      .is_vowel
    cmp     al, 'i'
    je      .is_vowel
    cmp     al, 'o'
    je      .is_vowel
    cmp     al, 'u'
    je      .is_vowel
    jmp     .next

.is_vowel:
    inc     r12

.next:
    inc     rdx
    jmp     .count_loop

.print:
    mov     rax, r12
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
