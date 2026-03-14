SECTION .data
newline db      0Ah

SECTION .bss
buf     resb    32

SECTION .text
global  _start

_start:
    ; parse argv[1] -> number
    mov     rsi, [rsp+16]   ; argv[1]
    call    atoi
    mov     rbx, rax        ; save first number

    ; parse argv[2] -> number
    mov     rsi, [rsp+24]   ; argv[2]
    call    atoi

    ; add them
    add     rax, rbx

    ; convert result to string and print
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
    lea     rdi, [buf+31]   ; end of buffer
    mov     byte [rdi], 0   ; null terminator
    mov     rcx, 10
    test    rax, rax
    jnz     .convert
    ; handle 0
    dec     rdi
    mov     byte [rdi], '0'
    jmp     .do_print

.convert:
    test    rax, rax
    jz      .do_print
    xor     rdx, rdx
    div     rcx             ; rax / 10, remainder in rdx
    add     dl, '0'
    dec     rdi
    mov     [rdi], dl
    jmp     .convert

.do_print:
    ; calculate length
    lea     rsi, [buf+31]
    sub     rsi, rdi        ; rsi = length
    mov     rdx, rsi        ; rdx = length
    mov     rsi, rdi        ; rsi = pointer to string
    mov     rax, 1          ; sys_write
    mov     rdi, 1          ; stdout
    syscall
    ret
