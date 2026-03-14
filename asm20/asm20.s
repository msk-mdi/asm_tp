; asm20 - Multi-Client TCP Server
; TCP server on port 4242.
; Commands: PING->PONG, REVERSE <str>, EXIT->Goodbye!
; Uses fork() to handle multiple clients.

section .data
    ; sockaddr_in for 0.0.0.0:4242
    bind_addr:
        dw 2               ; AF_INET
        dw 0x9210           ; port 4242 in network byte order (htons(4242) = 0x1092 -> stored 10 92)
        dd 0x00000000       ; INADDR_ANY
        dq 0                ; padding

    msg_listen db "Listening on port 4242", 10, 0
    msg_pong db "PONG", 10, 0
    msg_goodbye db "Goodbye!", 10, 0

    optval dd 1

section .bss
    recvbuf resb 4096
    sendbuf resb 4096

section .text
    global _start

_start:
    ; Create TCP socket: socket(AF_INET=2, SOCK_STREAM=1, 0)
    mov rax, 41          ; sys_socket
    mov rdi, 2           ; AF_INET
    mov rsi, 1           ; SOCK_STREAM
    xor rdx, rdx
    syscall
    cmp rax, 0
    jl .error
    mov r12, rax         ; save listen socket fd

    ; Set SO_REUSEADDR
    mov rdi, r12
    mov rsi, 1           ; SOL_SOCKET
    mov rdx, 2           ; SO_REUSEADDR
    lea r10, [optval]
    mov r8, 4
    mov rax, 54          ; sys_setsockopt
    syscall

    ; Bind to port 4242
    mov rdi, r12
    lea rsi, [bind_addr]
    mov rdx, 16
    mov rax, 49          ; sys_bind
    syscall
    cmp rax, 0
    jl .error

    ; Listen with backlog 10
    mov rdi, r12
    mov rsi, 10
    mov rax, 50          ; sys_listen
    syscall
    cmp rax, 0
    jl .error

    ; Print "Listening on port 4242"
    lea rsi, [msg_listen]
    call .print_stdout

    ; Reap zombie children - set SIGCHLD to SIG_IGN
    ; sigaction(SIGCHLD=17, {sa_handler=SIG_IGN}, NULL)
    ; Actually, simpler: just use SA_NOCLDWAIT or ignore via signal
    ; We'll use a simpler approach: after fork, parent just loops

.accept_loop:
    ; Wait for zombies (non-blocking): waitpid(-1, NULL, WNOHANG=1)
    mov rax, 61          ; sys_wait4
    mov rdi, -1
    xor rsi, rsi         ; status = NULL
    mov rdx, 1           ; WNOHANG
    xor r10, r10         ; rusage = NULL
    syscall

    ; accept(listen_fd, NULL, NULL)
    mov rdi, r12         ; listen socket
    xor rsi, rsi         ; addr = NULL
    xor rdx, rdx         ; addrlen = NULL
    mov rax, 43          ; sys_accept
    syscall
    cmp rax, 0
    jl .accept_loop      ; retry on error
    mov r13, rax         ; save client socket fd

    ; Fork
    mov rax, 57          ; sys_fork
    syscall
    cmp rax, 0
    jl .close_client_accept  ; fork failed, close client
    jne .parent          ; parent: rax > 0

    ; === CHILD PROCESS ===
    ; Close listen socket
    mov rdi, r12
    mov rax, 3
    syscall

    ; Handle client commands
    mov r12, r13         ; r12 = client fd in child

.client_loop:
    ; Read from client
    mov rdi, r12         ; client fd
    lea rsi, [recvbuf]
    mov rdx, 4095
    mov rax, 0           ; sys_read
    syscall
    cmp rax, 0
    jle .client_exit     ; connection closed or error

    mov r14, rax         ; bytes received

    ; Strip trailing newline/CR
    lea rdi, [recvbuf]
.strip_trail:
    cmp r14, 0
    je .process_cmd
    mov al, [rdi + r14 - 1]
    cmp al, 10
    je .strip_one
    cmp al, 13
    je .strip_one
    jmp .process_cmd
.strip_one:
    dec r14
    jmp .strip_trail

.process_cmd:
    ; Null-terminate
    mov byte [recvbuf + r14], 0

    ; Check for "PING"
    cmp r14, 4
    jne .check_reverse
    cmp byte [recvbuf], 'P'
    jne .check_reverse
    cmp byte [recvbuf + 1], 'I'
    jne .check_reverse
    cmp byte [recvbuf + 2], 'N'
    jne .check_reverse
    cmp byte [recvbuf + 3], 'G'
    jne .check_reverse

    ; Send "PONG\n"
    mov rdi, r12
    lea rsi, [msg_pong]
    mov rdx, 5           ; "PONG\n"
    mov rax, 1           ; sys_write
    syscall
    jmp .client_loop

.check_reverse:
    ; Check if starts with "REVERSE "
    cmp r14, 8
    jl .check_exit
    cmp byte [recvbuf], 'R'
    jne .check_exit
    cmp byte [recvbuf + 1], 'E'
    jne .check_exit
    cmp byte [recvbuf + 2], 'V'
    jne .check_exit
    cmp byte [recvbuf + 3], 'E'
    jne .check_exit
    cmp byte [recvbuf + 4], 'R'
    jne .check_exit
    cmp byte [recvbuf + 5], 'S'
    jne .check_exit
    cmp byte [recvbuf + 6], 'E'
    jne .check_exit
    cmp byte [recvbuf + 7], ' '
    jne .check_exit

    ; Reverse the string after "REVERSE "
    lea rsi, [recvbuf + 8]    ; start of string to reverse
    mov rcx, r14
    sub rcx, 8                ; length of string to reverse

    ; Reverse into sendbuf
    lea rdi, [sendbuf]
    mov rbx, rcx              ; save length
    dec rcx                   ; index of last char

.reverse_loop:
    cmp rcx, 0
    jl .reverse_done
    mov al, [rsi + rcx]
    mov [rdi], al
    inc rdi
    dec rcx
    jmp .reverse_loop

.reverse_done:
    ; Add newline
    mov byte [sendbuf + rbx], 10

    ; Send reversed string
    mov rdi, r12
    lea rsi, [sendbuf]
    lea rdx, [rbx + 1]  ; length + newline
    mov rax, 1           ; sys_write
    syscall
    jmp .client_loop

.check_exit:
    ; Check for "EXIT"
    cmp r14, 4
    jne .client_loop     ; unknown command, ignore
    cmp byte [recvbuf], 'E'
    jne .client_loop
    cmp byte [recvbuf + 1], 'X'
    jne .client_loop
    cmp byte [recvbuf + 2], 'I'
    jne .client_loop
    cmp byte [recvbuf + 3], 'T'
    jne .client_loop

    ; Send "Goodbye!\n"
    mov rdi, r12
    lea rsi, [msg_goodbye]
    mov rdx, 9           ; "Goodbye!\n"
    mov rax, 1           ; sys_write
    syscall

.client_exit:
    ; Close client socket
    mov rdi, r12
    mov rax, 3
    syscall
    ; Exit child
    mov rax, 60
    xor rdi, rdi
    syscall

    ; === PARENT PROCESS ===
.parent:
    ; Close client socket in parent
    mov rdi, r13
    mov rax, 3
    syscall
    jmp .accept_loop

.close_client_accept:
    mov rdi, r13
    mov rax, 3
    syscall
    jmp .accept_loop

.error:
    mov rax, 60
    mov rdi, 1
    syscall

; Helper: print null-terminated string at rsi to stdout
.print_stdout:
    push rsi
    mov rdi, rsi
    xor rcx, rcx
.strlen:
    cmp byte [rdi + rcx], 0
    je .strlen_done
    inc rcx
    jmp .strlen
.strlen_done:
    mov rdx, rcx
    pop rsi
    mov rdi, 1           ; stdout
    mov rax, 1           ; sys_write
    syscall
    ret
