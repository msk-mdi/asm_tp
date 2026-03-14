SECTION .data
msg     db      'Hello Universe!', 0Ah
msg_len equ     $ - msg

SECTION .text
global  _start

_start:
    ; open file (argv[1]) for writing
    ; sys_open = 2, flags: O_WRONLY|O_CREAT|O_TRUNC = 0x241, mode = 0644
    mov     rax, 2          ; sys_open
    mov     rdi, [rsp+16]   ; argv[1] = filename
    mov     rsi, 0x241      ; O_WRONLY | O_CREAT | O_TRUNC
    mov     rdx, 0644o      ; permissions
    syscall

    ; rax = file descriptor
    cmp     rax, 0
    jl      .fail

    mov     r12, rax        ; save fd

    ; write message to file
    mov     rax, 1          ; sys_write
    mov     rdi, r12        ; fd
    lea     rsi, [msg]
    mov     rdx, msg_len
    syscall

    ; close file
    mov     rax, 3          ; sys_close
    mov     rdi, r12
    syscall

    ; exit 0
    mov     rax, 60
    xor     rdi, rdi
    syscall

.fail:
    mov     rax, 60
    mov     rdi, 1
    syscall
