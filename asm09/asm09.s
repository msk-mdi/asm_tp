SECTION .data
hex_chars   db  '0123456789ABCDEF'
newline     db  0Ah

SECTION .bss
buf         resb    128

SECTION .text
global  _start

_start:
    mov     r12, [rsp]      ; argc
    ; Check if first arg is "-b"
    cmp     r12, 3
    je      .check_binary_flag

    ; Default: hex mode, argv[1] is the number
    mov     rsi, [rsp+16]   ; argv[1]
    call    atoi
    mov     r13, rax        ; save number
    jmp     .do_hex

.check_binary_flag:
    mov     rsi, [rsp+16]   ; argv[1]
    cmp     byte [rsi], '-'
    jne     .do_hex_arg2
    cmp     byte [rsi+1], 'b'
    jne     .do_hex_arg2
    cmp     byte [rsi+2], 0
    jne     .do_hex_arg2

    ; Binary mode, number is argv[2]
    mov     rsi, [rsp+24]   ; argv[2]
    call    atoi
    mov     r13, rax
    jmp     .do_binary

.do_hex_arg2:
    mov     rsi, [rsp+16]
    call    atoi
    mov     r13, rax

.do_hex:
    ; Convert r13 to hex string
    lea     rdi, [buf+127]
    mov     byte [rdi], 0
    mov     rax, r13

    test    rax, rax
    jnz     .hex_loop
    ; handle 0
    dec     rdi
    mov     byte [rdi], '0'
    jmp     .print_result

.hex_loop:
    test    rax, rax
    jz      .print_result
    mov     rcx, rax
    and     rcx, 0Fh        ; lower 4 bits
    lea     rsi, [hex_chars]
    mov     cl, [rsi+rcx]
    dec     rdi
    mov     [rdi], cl
    shr     rax, 4
    jmp     .hex_loop

.do_binary:
    ; Convert r13 to binary string
    lea     rdi, [buf+127]
    mov     byte [rdi], 0
    mov     rax, r13

    test    rax, rax
    jnz     .bin_loop
    ; handle 0
    dec     rdi
    mov     byte [rdi], '0'
    jmp     .print_result

.bin_loop:
    test    rax, rax
    jz      .print_result
    mov     rcx, rax
    and     rcx, 1
    add     cl, '0'
    dec     rdi
    mov     [rdi], cl
    shr     rax, 1
    jmp     .bin_loop

.print_result:
    ; Calculate length
    lea     rsi, [buf+127]
    sub     rsi, rdi
    mov     rdx, rsi        ; length
    mov     rsi, rdi        ; pointer
    mov     rax, 1          ; sys_write
    mov     rdi, 1          ; stdout
    syscall

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
