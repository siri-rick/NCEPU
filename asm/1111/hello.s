.model small
.stack
.data
    str db 'hello, world!!$'

.code
main proc
    mov ax, @data
    mov ds, ax

    b equ [bp+8]
    mov ax, b

    mov dx, offset str
    mov ah, 9h
    int 21h

    mov ah, 4ch
    int 21h
main endp
end main