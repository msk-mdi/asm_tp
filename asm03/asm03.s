SECTION .data
msg     db      '1337', 0Ah

SECTION .text
global  _start

_start:
    ; argc is at [rsp], argv[0] at [rsp+8], argv[1] at [rsp+16], etc.
    mov     rdi, [rsp]      ; argc
    cmp     rdi, 2          ; must be exactly 2 (program + one arg)
    jne     .fail

    ; get argv[1]
    mov     rsi, [rsp+16]   ; pointer to argv[1]

    ; check it's "42\0" (exactly 3 bytes)
    cmp     byte [rsi], '4'
    jne     .fail
    cmp     byte [rsi+1], '2'
    jne     .fail
    cmp     byte [rsi+2], 0
    jne     .fail

    ; print "1337\n"
    mov     rax, 1          ; sys_write
    mov     rdi, 1          ; stdout
    lea     rsi, [msg]
    mov     rdx, 5
    syscall

    ; exit 0
    mov     rax, 60
    xor     rdi, rdi
    syscall

.fail:
    mov     rax, 60
    mov     rdi, 1
    syscall
