[BITS 16]
[ORG 0x7C00]

global PointerBIOS_Init
global PointerBIOS_Remove
global PointerBIOS_GetButton

section .data
PointerBIOS_Running db 0
CursorX dw 100
CursorY dw 100
OldX dw 100
OldY dw 100
CursorW dw 0
CursorH dw 0
FrameBuffer dd 0E0000000h
CursorBitmap dd 64*64 dup(0)
MouseButtons dw 0

section .text

; ------------------------------------------------------
; PointerBIOS_Init
; BMP already loaded for simplicity
; ------------------------------------------------------
PointerBIOS_Init:
    ; Set VESA 1024x768x32
    mov ax, 4F02h
    mov bx, 118h
    int 10h

    ; Start pointer loop
    mov byte [PointerBIOS_Running], 1

PointerBIOS_Loop:
    cmp byte [PointerBIOS_Running],0
    je PointerBIOS_ExitLoop

    ; Save old position
    mov ax,[CursorX]
    mov [OldX],ax
    mov ax,[CursorY]
    mov [OldY],ax

    ; Read mouse position and buttons
    mov ax,3
    int 33h
    mov [CursorX],cx
    mov [CursorY],dx
    mov [MouseButtons],bx

    ; Draw cursor with alpha
    mov cx,[CursorH]
    mov bx,[CursorW]
    lea si,[CursorBitmap]
    lea di,[FrameBuffer]

DrawRow:
    push cx
    mov cx,bx
DrawCol:
    mov eax,[si]
    cmp al,0
    je SkipPix
    mov [di],eax
SkipPix:
    add si,4
    add di,4
    loop DrawCol
    pop cx
    add di,(1024*4)-(bx*4)
    loop DrawRow

    jmp PointerBIOS_Loop

PointerBIOS_ExitLoop:
    ret

; ------------------------------------------------------
; PointerBIOS_Remove
; ------------------------------------------------------
PointerBIOS_Remove:
    mov byte [PointerBIOS_Running],0
    ret

; ------------------------------------------------------
; PointerBIOS_GetButton
; Returns in AL: 1=left, 2=middle, 3=right, 0=none
; ------------------------------------------------------
PointerBIOS_GetButton:
    mov ax,[MouseButtons]
    test ax,1
    jnz LeftButton
    test ax,4
    jnz MiddleButton
    test ax,2
    jnz RightButton
    xor al,al
    ret
LeftButton:
    mov al,1
    ret
MiddleButton:
    mov al,2
    ret
RightButton:
    mov al,3
    ret
