; asm19 - UDP Server
; Listen on UDP port 1337 and log messages to 'messages' file.
; Prints "Listening on port 1337" then receives messages in a loop,
; appending each to the 'messages' file.

section .data
    ; sockaddr_in for 0.0.0.0:1337
    bind_addr:
        dw 2               ; AF_INET
        dw 0x3905           ; port 1337 in network byte order
        dd 0x00000000       ; INADDR_ANY (0.0.0.0)
        dq 0                ; padding

    msg_listen db "Listening on port 1337", 10, 0
    filename db "messages", 0

    ; SO_REUSEADDR option value
    optval dd 1

section .bss
    recvbuf resb 4096

section .text
    global _start

_start:
    ; Create UDP socket: socket(AF_INET=2, SOCK_DGRAM=2, 0)
    mov rax, 41          ; sys_socket
    mov rdi, 2           ; AF_INET
    mov rsi, 2           ; SOCK_DGRAM
    xor rdx, rdx         ; protocol = 0
    syscall
    cmp rax, 0
    jl .error
    mov r12, rax         ; save socket fd

    ; Set SO_REUSEADDR: setsockopt(fd, SOL_SOCKET=1, SO_REUSEADDR=2, &val, 4)
    mov rdi, r12
    mov rsi, 1           ; SOL_SOCKET
    mov rdx, 2           ; SO_REUSEADDR
    lea r10, [optval]
    mov r8, 4
    mov rax, 54          ; sys_setsockopt
    syscall

    ; Bind to port 1337: bind(fd, &addr, 16)
    mov rdi, r12
    lea rsi, [bind_addr]
    mov rdx, 16
    mov rax, 49          ; sys_bind
    syscall
    cmp rax, 0
    jl .error

    ; Print "Listening on port 1337"
    lea rsi, [msg_listen]
    call .print_string

    ; Open/create 'messages' file for appending
    ; open("messages", O_WRONLY|O_CREAT|O_APPEND, 0644)
    ; O_WRONLY=1, O_CREAT=64, O_APPEND=1024 -> 1|64|1024 = 1089
    lea rdi, [filename]
    mov rsi, 1089        ; O_WRONLY | O_CREAT | O_APPEND
    mov rdx, 0644o       ; permissions
    mov rax, 2           ; sys_open
    syscall
    cmp rax, 0
    jl .error
    mov r13, rax         ; save file fd

.recv_loop:
    ; recvfrom(sockfd, buf, buflen, flags, NULL, NULL)
    mov rdi, r12         ; socket fd
    lea rsi, [recvbuf]   ; buffer
    mov rdx, 4095        ; max bytes
    xor r10, r10         ; flags = 0
    xor r8, r8           ; src_addr = NULL
    xor r9, r9           ; addrlen = NULL
    mov rax, 45          ; sys_recvfrom
    syscall
    cmp rax, 0
    jle .recv_loop       ; on error or 0 bytes, keep trying
    mov r14, rax         ; bytes received

    ; Write received data to messages file
    mov rdi, r13         ; file fd
    lea rsi, [recvbuf]   ; buffer
    mov rdx, r14         ; bytes to write
    mov rax, 1           ; sys_write
    syscall

    jmp .recv_loop       ; loop forever

.error:
    mov rax, 60
    mov rdi, 1
    syscall

; Helper: print null-terminated string at rsi to stdout
.print_string:
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
