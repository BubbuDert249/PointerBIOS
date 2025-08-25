[BITS 16]
[ORG 0x7C00]

global PointerBIOS_Init
global PointerBIOS_Remove

section .data
PointerBIOS_Running db 0
CursorX dw 100
CursorY dw 100
OldX dw 100
OldY dw 100
CursorW dw 0
CursorH dw 0
FrameBuffer dd 0E0000000h
CursorBitmap times 64*64 dd 0
BMPBuffer times 32768 db 0
FileHandle db 0

section .text

; ------------------------------------------------------
; Open file using DOS
; Input: DS:DX = filename
; Output: AL=success (0=fail), FileHandle
; ------------------------------------------------------
DOS_OpenFile:
    mov ah,3Dh
    mov al,0         ; read-only
    int 21h
    jc DOS_OpenFail
    mov [FileHandle], al
    mov al,0
    ret
DOS_OpenFail:
    mov al,1
    ret

; ------------------------------------------------------
; Read file using DOS
; Input: BX = file handle, CX = size, DS:DX = buffer
; Output: AL=success/fail
; ------------------------------------------------------
DOS_ReadFile:
    mov ah,3Fh
    int 21h
    jc DOS_ReadFail
    mov al,0
    ret
DOS_ReadFail:
    mov al,1
    ret

; ------------------------------------------------------
; Close file
; Input: BX = file handle
; ------------------------------------------------------
DOS_CloseFile:
    mov ah,3Eh
    int 21h
    ret

; ------------------------------------------------------
; PointerBIOS_Init "filename" (DS:DX)
; ------------------------------------------------------
PointerBIOS_Init:
    ; Set VESA 1024x768x32
    mov ax, 4F02h
    mov bx, 118h
    int 10h

    push dx
    call DOS_OpenFile
    cmp al,1
    je InitFail
    mov bl,[FileHandle]

    mov cx, 32768
    call DOS_ReadFile
    cmp al,1
    je InitFail

    mov bl,[FileHandle]
    call DOS_CloseFile

    pop dx

    ; Parse BMP header
    mov si,BMPBuffer
    mov ax,[si+18]       ; width
    mov [CursorW], ax
    mov ax,[si+22]       ; height
    mov [CursorH], ax
    mov bx,[si+10]       ; pixel data offset
    add si,bx            ; SI -> pixel data start

    ; Copy pixels to CursorBitmap with vertical flip
    lea di, [CursorBitmap]
    mov cx,[CursorH]
y_loop:
    push cx
    mov cx,[CursorW]
x_loop:
    mov eax,[si]
    cmp al,0
    je skip_pixel
    mov [di],eax
skip_pixel:
    add si,4
    add di,4
    loop x_loop
    pop cx
    sub si,[CursorW]*4*2
    loop y_loop

    ; Start pointer loop
    mov byte [PointerBIOS_Running],1

PointerBIOS_Loop:
    cmp byte [PointerBIOS_Running],0
    je PointerBIOS_ExitLoop

    mov ax,[CursorX]
    mov [OldX],ax
    mov ax,[CursorY]
    mov [OldY],ax

    mov ax,3
    int 33h
    mov [CursorX],cx
    mov [CursorY],dx

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

InitFail:
    ret

; ------------------------------------------------------
; PointerBIOS_Remove
; ------------------------------------------------------
PointerBIOS_Remove:
    mov byte [PointerBIOS_Running],0
    ret
