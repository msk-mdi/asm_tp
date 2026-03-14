; asm22 - Binary Packer (Bonus)
; Pack and encrypt a binary. Generate _packed version that self-decrypts.
; Usage: ./asm22 <binary>
; Creates <binary>_packed which decrypts and executes the original.
;
; Strategy:
; 1. Read the input binary
; 2. XOR encrypt it with key 0x42
; 3. Generate an assembly source file <binary>_packed.s
; 4. Use fork+execve to run nasm and ld to build it
; 5. Clean up temp files
;
; The generated packed binary will:
; - XOR decrypt the embedded data
; - Write it to a memfd
; - execve the memfd via /proc/self/fd/<N>

section .data
    xor_key equ 0x42

    suffix db "_packed", 0
    suffix_s db "_packed.s", 0
    suffix_o db "_packed.o", 0

    ; Assembly template parts for the generated source
    tmpl_header db "section .data", 10
               db "    payload_len equ "
    tmpl_header_len equ $ - tmpl_header

    tmpl_mid1 db 10, "    payload:", 10, "        db "
    tmpl_mid1_len equ $ - tmpl_mid1

    tmpl_stub db 10, 10
        db "section .text", 10
        db "    global _start", 10, 10
        db "_start:", 10
        db "    ; XOR decrypt payload", 10
        db "    lea rsi, [payload]", 10
        db "    mov rcx, payload_len", 10
        db ".decrypt:", 10
        db "    xor byte [rsi], 0x42", 10
        db "    inc rsi", 10
        db "    dec rcx", 10
        db "    jnz .decrypt", 10, 10
        db "    ; memfd_create", 10
        db "    lea rdi, [payload]", 10
        db "    mov rsi, 0", 10
        db "    mov rax, 319", 10
        db "    syscall", 10
        db "    mov r12, rax", 10, 10
        db "    ; Write decrypted binary to memfd", 10
        db "    mov rdi, r12", 10
        db "    lea rsi, [payload]", 10
        db "    mov rdx, payload_len", 10
        db "    mov rax, 1", 10
        db "    syscall", 10, 10
        db "    ; Build /proc/self/fd/<N> path", 10
        db "    sub rsp, 64", 10
        db "    mov rdi, rsp", 10
        db "    ; Write /proc/self/fd/", 10
        db "    mov dword [rdi], '/pro'", 10
        db "    mov dword [rdi+4], 'c/se'", 10
        db "    mov dword [rdi+8], 'lf/f'", 10
        db "    mov word [rdi+12], 'd/'", 10
        db "    lea rdi, [rsp+14]", 10
        db "    mov rax, r12", 10
        db "    ; Convert fd number to string", 10
        db "    mov rcx, 10", 10
        db "    xor r8, r8", 10
        db "    lea r9, [rsp+48]", 10
        db ".itoa:", 10
        db "    xor rdx, rdx", 10
        db "    div rcx", 10
        db "    add dl, '0'", 10
        db "    dec r9", 10
        db "    mov [r9], dl", 10
        db "    inc r8", 10
        db "    test rax, rax", 10
        db "    jnz .itoa", 10
        db "    ; Copy digits", 10
        db ".copy_digits:", 10
        db "    mov al, [r9]", 10
        db "    mov [rdi], al", 10
        db "    inc r9", 10
        db "    inc rdi", 10
        db "    dec r8", 10
        db "    jnz .copy_digits", 10
        db "    mov byte [rdi], 0", 10, 10
        db "    ; execve(path, argv, envp)", 10
        db "    mov rdi, rsp", 10
        db "    xor rdx, rdx", 10
        db "    push rdx", 10
        db "    push rdi", 10
        db "    mov rsi, rsp", 10
        db "    mov rax, 59", 10
        db "    syscall", 10, 10
        db "    ; If execve fails, exit 1", 10
        db "    mov rax, 60", 10
        db "    mov rdi, 1", 10
        db "    syscall", 10
    tmpl_stub_len equ $ - tmpl_stub

    nasm_path db "/usr/bin/nasm", 0
    nasm_arg0 db "nasm", 0
    nasm_arg1 db "-f", 0
    nasm_arg2 db "elf64", 0
    nasm_arg3 db "-o", 0

    ld_path db "/usr/bin/ld", 0
    ld_arg0 db "ld", 0
    ld_arg1 db "-o", 0

    hex_chars db "0123456789abcdef"

section .bss
    input_buf resb 131072    ; 128KB for input binary
    name_buf resb 256        ; buffer for output filenames
    name_s_buf resb 256      ; <name>_packed.s
    name_o_buf resb 256      ; <name>_packed.o
    num_buf resb 32          ; number to string buffer
    line_buf resb 65536      ; line buffer for hex output
    argv_buf resb 64         ; argv array for execve (8 pointers)

section .text
    global _start

_start:
    ; Check argc >= 2
    mov rax, [rsp]
    cmp rax, 2
    jl .error

    mov r12, [rsp + 16]  ; argv[1] = input binary name

    ; Build output filenames
    ; Copy input name to name_buf, name_s_buf, name_o_buf
    mov rsi, r12
    lea rdi, [name_buf]
    call .strcpy
    mov rsi, r12
    lea rdi, [name_s_buf]
    call .strcpy
    mov rsi, r12
    lea rdi, [name_o_buf]
    call .strcpy

    ; Append "_packed" to name_buf
    lea rdi, [name_buf]
    call .strlen_rdi
    lea rdi, [name_buf + rax]
    lea rsi, [suffix]
    call .strcpy

    ; Append "_packed.s" to name_s_buf
    lea rdi, [name_s_buf]
    call .strlen_rdi
    lea rdi, [name_s_buf + rax]
    lea rsi, [suffix_s]
    call .strcpy

    ; Append "_packed.o" to name_o_buf
    lea rdi, [name_o_buf]
    call .strlen_rdi
    lea rdi, [name_o_buf + rax]
    lea rsi, [suffix_o]
    call .strcpy

    ; Open input binary for reading
    mov rdi, r12
    xor rsi, rsi         ; O_RDONLY
    xor rdx, rdx
    mov rax, 2           ; sys_open
    syscall
    cmp rax, 0
    jl .error
    mov r13, rax         ; input fd

    ; Read entire input binary
    mov rdi, r13
    lea rsi, [input_buf]
    mov rdx, 131072
    mov rax, 0           ; sys_read
    syscall
    cmp rax, 0
    jle .error
    mov r14, rax         ; r14 = input size

    ; Close input
    mov rdi, r13
    mov rax, 3
    syscall

    ; XOR encrypt the input buffer
    lea rsi, [input_buf]
    mov rcx, r14
.encrypt:
    xor byte [rsi], xor_key
    inc rsi
    dec rcx
    jnz .encrypt

    ; Create output .s file
    lea rdi, [name_s_buf]
    mov rsi, 0x241       ; O_WRONLY | O_CREAT | O_TRUNC (1 | 64 | 512)
    mov rdx, 0644o
    mov rax, 2
    syscall
    cmp rax, 0
    jl .error
    mov r13, rax         ; output .s fd

    ; Write header: "section .data\n    payload_len equ "
    mov rdi, r13
    lea rsi, [tmpl_header]
    mov rdx, tmpl_header_len
    mov rax, 1
    syscall

    ; Write the payload length as decimal string
    mov rax, r14
    lea rdi, [num_buf]
    call .itoa            ; rdi points to start, rax = length
    mov rdx, rax
    mov rsi, rdi
    mov rdi, r13
    mov rax, 1
    syscall

    ; Write mid1: "\n    payload:\n        db "
    mov rdi, r13
    lea rsi, [tmpl_mid1]
    mov rdx, tmpl_mid1_len
    mov rax, 1
    syscall

    ; Write payload bytes as hex: 0xHH,0xHH,...
    ; Write 16 bytes per line for readability
    lea rbx, [input_buf]
    mov r15, r14          ; bytes remaining
    xor rbp, rbp          ; column counter

.write_bytes:
    cmp r15, 0
    je .write_stub

    ; Get byte
    movzx eax, byte [rbx]
    inc rbx
    dec r15

    ; Convert to "0xHH" in line_buf
    lea rdi, [line_buf]
    mov byte [rdi], '0'
    mov byte [rdi + 1], 'x'
    
    mov ecx, eax
    shr ecx, 4
    and ecx, 0xf
    lea rsi, [hex_chars]
    mov cl, [rsi + rcx]
    mov [rdi + 2], cl
    
    mov ecx, eax
    and ecx, 0xf
    mov cl, [rsi + rcx]
    mov [rdi + 3], cl

    mov rdx, 4           ; "0xHH" = 4 chars
    
    ; Add comma if not last byte
    cmp r15, 0
    je .no_comma
    mov byte [rdi + 4], ','
    inc rdx
.no_comma:

    ; Check if we need a newline (every 16 bytes)
    inc rbp
    cmp rbp, 16
    jne .write_hex
    xor rbp, rbp
    cmp r15, 0
    je .write_hex
    ; Add newline + "        db "
    mov byte [rdi + rdx], 10
    inc rdx
    mov dword [rdi + rdx], '    '
    add rdx, 4
    mov dword [rdi + rdx], '    '
    add rdx, 4
    mov word [rdi + rdx], 'db'
    add rdx, 2
    mov byte [rdi + rdx], ' '
    inc rdx

.write_hex:
    push rbx
    push r15
    push rbp
    mov rsi, rdi
    mov rdi, r13         ; fd
    mov rax, 1
    syscall
    pop rbp
    pop r15
    pop rbx
    jmp .write_bytes

.write_stub:
    ; Write the assembly stub
    mov rdi, r13
    lea rsi, [tmpl_stub]
    mov rdx, tmpl_stub_len
    mov rax, 1
    syscall

    ; Close .s file
    mov rdi, r13
    mov rax, 3
    syscall

    ; Run nasm -f elf64 <name>_packed.s -o <name>_packed.o
    mov rax, 57          ; fork
    syscall
    cmp rax, 0
    jl .error
    jne .wait_nasm

    ; Child: execve nasm
    ; Build argv: ["nasm", "-f", "elf64", "-o", "<name>_packed.o", "<name>_packed.s", NULL]
    lea rdi, [argv_buf]
    lea rax, [nasm_arg0]
    mov [rdi], rax
    lea rax, [nasm_arg1]
    mov [rdi + 8], rax
    lea rax, [nasm_arg2]
    mov [rdi + 16], rax
    lea rax, [nasm_arg3]
    mov [rdi + 24], rax
    lea rax, [name_o_buf]
    mov [rdi + 32], rax
    lea rax, [name_s_buf]
    mov [rdi + 40], rax
    mov qword [rdi + 48], 0   ; NULL terminator

    lea rdi, [nasm_path]
    lea rsi, [argv_buf]
    xor rdx, rdx         ; envp = NULL
    mov rax, 59          ; execve
    syscall
    ; If exec fails, exit 1
    mov rax, 60
    mov rdi, 1
    syscall

.wait_nasm:
    ; Parent: wait for nasm
    mov rdi, rax         ; child pid
    sub rsp, 8
    mov rsi, rsp         ; &status
    xor rdx, rdx
    xor r10, r10
    mov rax, 61          ; wait4
    syscall
    mov eax, [rsp]
    add rsp, 8
    ; Check exit status
    mov ecx, eax
    and ecx, 0x7f
    jnz .error           ; nasm crashed
    shr eax, 8
    and eax, 0xff
    cmp eax, 0
    jne .error           ; nasm returned error

    ; Run ld -o <name>_packed <name>_packed.o
    mov rax, 57          ; fork
    syscall
    cmp rax, 0
    jl .error
    jne .wait_ld

    ; Child: execve ld
    lea rdi, [argv_buf]
    lea rax, [ld_arg0]
    mov [rdi], rax
    lea rax, [ld_arg1]
    mov [rdi + 8], rax
    lea rax, [name_buf]
    mov [rdi + 16], rax
    lea rax, [name_o_buf]
    mov [rdi + 24], rax
    mov qword [rdi + 32], 0

    lea rdi, [ld_path]
    lea rsi, [argv_buf]
    xor rdx, rdx
    mov rax, 59
    syscall
    mov rax, 60
    mov rdi, 1
    syscall

.wait_ld:
    ; Parent: wait for ld
    mov rdi, rax
    sub rsp, 8
    mov rsi, rsp
    xor rdx, rdx
    xor r10, r10
    mov rax, 61
    syscall
    mov eax, [rsp]
    add rsp, 8
    mov ecx, eax
    and ecx, 0x7f
    jnz .error
    shr eax, 8
    and eax, 0xff
    cmp eax, 0
    jne .error

    ; Clean up: delete .s and .o files
    lea rdi, [name_s_buf]
    mov rax, 87          ; sys_unlink
    syscall
    lea rdi, [name_o_buf]
    mov rax, 87
    syscall

    ; chmod the packed binary to be executable (0755)
    lea rdi, [name_buf]
    mov rsi, 0755o
    mov rax, 90          ; sys_chmod
    syscall

    ; Exit 0
    mov rax, 60
    xor rdi, rdi
    syscall

.error:
    mov rax, 60
    mov rdi, 1
    syscall

; === Helper functions ===

; Copy null-terminated string from rsi to rdi
.strcpy:
    push rax
.strcpy_loop:
    lodsb
    stosb
    test al, al
    jnz .strcpy_loop
    pop rax
    ret

; Get length of null-terminated string at rdi, result in rax
.strlen_rdi:
    push rcx
    push rdi
    xor rcx, rcx
.strlen_rdi_loop:
    cmp byte [rdi + rcx], 0
    je .strlen_rdi_done
    inc rcx
    jmp .strlen_rdi_loop
.strlen_rdi_done:
    mov rax, rcx
    pop rdi
    pop rcx
    ret

; Convert integer in rax to decimal string at rdi
; Returns: rdi = pointer to start of string, rax = length
.itoa:
    push rbx
    push rcx
    push rdx
    lea rbx, [num_buf + 30]  ; work from end
    mov byte [rbx + 1], 0
    mov rcx, 10
    test rax, rax
    jnz .itoa_loop
    ; Handle 0
    mov byte [rbx], '0'
    mov rdi, rbx
    mov rax, 1
    pop rdx
    pop rcx
    pop rbx
    ret
.itoa_loop:
    test rax, rax
    jz .itoa_done
    xor rdx, rdx
    div rcx
    add dl, '0'
    mov [rbx], dl
    dec rbx
    jmp .itoa_loop
.itoa_done:
    inc rbx
    mov rdi, rbx
    ; Calculate length
    lea rax, [num_buf + 31]
    sub rax, rbx
    pop rdx
    pop rcx
    pop rbx
    ret
