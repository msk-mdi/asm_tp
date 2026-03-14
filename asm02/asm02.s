SECTION .data
msg     db      '1337', 0Ah

SECTION .bss
buf     resb    16

SECTION .text
global  _start

_start:
    ; read from stdin
    mov     rax, 0          ; sys_read
    mov     rdi, 0          ; stdin
    lea     rsi, [buf]
    mov     rdx, 16
    syscall

    ; rax = number of bytes read
    ; We expect "42\n" (3 bytes) or "42" (2 bytes)
    cmp     rax, 3
    je      .check3
    cmp     rax, 2
    je      .check2
    jmp     .fail

.check3:
    ; check that 3rd byte is newline
    cmp     byte [buf+2], 0Ah
    jne     .fail

.check2:
    ; check "42"
    cmp     byte [buf], '4'
    jne     .fail
    cmp     byte [buf+1], '2'
    jne     .fail

    ; print "1337\n"
    mov     rax, 1          ; sys_write
    mov     rdi, 1          ; stdout
    lea     rsi, [msg]
    mov     rdx, 5
    syscall

    ; exit 0
    mov     rax, 60         ; sys_exit
    xor     rdi, rdi
    syscall

.fail:
    ; exit 1
    mov     rax, 60
    mov     rdi, 1
    syscall
