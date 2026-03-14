; asm18 - UDP Client
; Send UDP request to 127.0.0.1:1337 and print response.
; Timeout after 1 second.
; On success: prints message: "<response>" and exits 0
; On timeout: prints "Timeout: no response from server" and exits 1

section .data
    ; sockaddr_in for 127.0.0.1:1337
    ; struct sockaddr_in { sa_family=AF_INET(2), port=htons(1337)=0x3905, addr=0x0100007f }
    addr:
        dw 2               ; AF_INET
        dw 0x3905           ; port 1337 in network byte order (htons(1337) = 0x0539 -> stored as 05 39)
        dd 0x0100007f       ; 127.0.0.1 in network byte order
        dq 0                ; padding

    ; Timeout struct: timeval { tv_sec=1, tv_usec=0 }
    timeout:
        dq 1                ; tv_sec = 1
        dq 0                ; tv_usec = 0

    msg_hello db "hello", 0
    msg_prefix db 'message: "', 0
    msg_suffix db '"', 10, 0
    msg_timeout db "Timeout: no response from server", 10, 0

section .bss
    recvbuf resb 1024

section .text
    global _start

_start:
    ; Create UDP socket: socket(AF_INET=2, SOCK_DGRAM=2, IPPROTO_UDP=17)
    mov rax, 41          ; sys_socket
    mov rdi, 2           ; AF_INET
    mov rsi, 2           ; SOCK_DGRAM
    mov rdx, 17          ; IPPROTO_UDP
    syscall
    cmp rax, 0
    jl .timeout_exit
    mov r12, rax         ; save socket fd

    ; Set receive timeout: setsockopt(fd, SOL_SOCKET=1, SO_RCVTIMEO=20, &timeout, 16)
    mov rdi, r12         ; fd
    mov rsi, 1           ; SOL_SOCKET
    mov rdx, 20          ; SO_RCVTIMEO
    lea r10, [timeout]   ; timeval struct
    mov r8, 16           ; sizeof(timeval)
    mov rax, 54          ; sys_setsockopt
    syscall

    ; Send "hello" to 127.0.0.1:1337
    ; sendto(fd, buf, len, flags, addr, addrlen)
    mov rdi, r12         ; fd
    lea rsi, [msg_hello] ; buffer
    mov rdx, 5           ; len ("hello")
    xor r10, r10         ; flags = 0
    lea r8, [addr]       ; sockaddr
    mov r9, 16           ; addrlen
    mov rax, 44          ; sys_sendto
    syscall
    cmp rax, 0
    jl .timeout_exit

    ; Receive response: recvfrom(fd, buf, buflen, flags, NULL, NULL)
    mov rdi, r12         ; fd
    lea rsi, [recvbuf]   ; buffer
    mov rdx, 1023        ; max bytes
    xor r10, r10         ; flags = 0
    xor r8, r8           ; src_addr = NULL
    xor r9, r9           ; addrlen = NULL
    mov rax, 45          ; sys_recvfrom
    syscall
    cmp rax, 0
    jle .timeout_exit
    mov r13, rax         ; save bytes received

    ; Null-terminate received data
    mov byte [recvbuf + r13], 0

    ; Strip trailing newline if present
    cmp r13, 0
    je .print_msg
    dec r13
    cmp byte [recvbuf + r13], 10
    je .stripped
    inc r13              ; no newline, restore length
    jmp .print_msg
.stripped:
    mov byte [recvbuf + r13], 0

.print_msg:
    ; Print 'message: "'
    lea rsi, [msg_prefix]
    call .print_string

    ; Print received message
    lea rsi, [recvbuf]
    mov rdx, r13
    mov rdi, 1           ; stdout
    mov rax, 1           ; sys_write
    syscall

    ; Print '"' + newline
    lea rsi, [msg_suffix]
    call .print_string

    ; Close socket
    mov rdi, r12
    mov rax, 3
    syscall

    ; Exit 0
    mov rax, 60
    xor rdi, rdi
    syscall

.timeout_exit:
    ; Print timeout message
    lea rsi, [msg_timeout]
    call .print_string

    ; Close socket if we have one
    cmp r12, 0
    jle .exit_1
    mov rdi, r12
    mov rax, 3
    syscall

.exit_1:
    mov rax, 60
    mov rdi, 1
    syscall

; Helper: print null-terminated string at rsi to stdout
.print_string:
    push rsi
    ; Calculate string length
    mov rdi, rsi
    xor rcx, rcx
.strlen:
    cmp byte [rdi + rcx], 0
    je .strlen_done
    inc rcx
    jmp .strlen
.strlen_done:
    mov rdx, rcx         ; length
    pop rsi              ; buffer
    mov rdi, 1           ; stdout
    mov rax, 1           ; sys_write
    syscall
    ret
