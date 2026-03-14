; asm21 - Shellcode Loader
; Load and execute shellcode from argument.
; argv[1] contains raw shellcode bytes.
; Uses mmap to allocate RWX memory, copies shellcode there, executes it.
; Uses fork: child executes shellcode, parent waits and returns exit code.
; If shellcode crashes (signal), parent exits with 1.

section .text
    global _start

_start:
    ; Check argc >= 2
    mov rax, [rsp]       ; argc
    cmp rax, 2
    jl .exit_error

    ; Get argv[1] pointer and compute its length
    mov r12, [rsp + 16]  ; argv[1] = shellcode string
    
    ; Calculate length of argv[1]
    mov rdi, r12
    xor rcx, rcx
.strlen:
    cmp byte [rdi + rcx], 0
    je .strlen_done
    inc rcx
    jmp .strlen
.strlen_done:
    mov r13, rcx         ; r13 = shellcode length
    cmp r13, 0
    je .exit_error       ; empty shellcode

    ; mmap(NULL, len, PROT_READ|PROT_WRITE|PROT_EXEC=7, MAP_PRIVATE|MAP_ANONYMOUS=0x22, -1, 0)
    mov rax, 9           ; sys_mmap
    xor rdi, rdi         ; addr = NULL
    mov rsi, r13         ; length
    mov rdx, 7           ; PROT_READ | PROT_WRITE | PROT_EXEC
    mov r10, 0x22        ; MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1           ; fd = -1
    xor r9, r9           ; offset = 0
    syscall
    cmp rax, -1
    je .exit_error
    mov r14, rax         ; r14 = mmap'd address

    ; Copy shellcode to executable memory
    mov rsi, r12         ; source = argv[1]
    mov rdi, r14         ; dest = mmap'd region
    mov rcx, r13         ; count
.copy:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jnz .copy

    ; Fork: child executes shellcode, parent waits
    mov rax, 57          ; sys_fork
    syscall
    cmp rax, 0
    jl .exit_error       ; fork failed
    jne .parent          ; parent (rax = child pid)

    ; === CHILD: execute shellcode ===
    call r14             ; jump to shellcode
    ; If shellcode returns (unlikely), exit 0
    mov rax, 60
    xor rdi, rdi
    syscall

.parent:
    ; Parent: wait for child
    mov r15, rax         ; save child pid
    
    ; wait4(pid, &status, 0, NULL)
    ; Use stack for status
    sub rsp, 8
    mov rdi, r15         ; pid
    mov rsi, rsp         ; &status
    xor rdx, rdx         ; options = 0
    xor r10, r10         ; rusage = NULL
    mov rax, 61          ; sys_wait4
    syscall
    
    ; Get status
    mov eax, [rsp]       ; status word
    add rsp, 8

    ; Check if child exited normally (WIFEXITED: status & 0x7f == 0)
    mov ecx, eax
    and ecx, 0x7f
    jnz .exit_signal     ; killed by signal

    ; WEXITSTATUS: (status >> 8) & 0xff
    shr eax, 8
    and eax, 0xff
    mov rdi, rax
    mov rax, 60
    syscall

.exit_signal:
    ; Child was killed by a signal -> exit 1
    mov rax, 60
    mov rdi, 1
    syscall

.exit_error:
    mov rax, 60
    mov rdi, 1
    syscall
