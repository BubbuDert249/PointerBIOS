#ifndef POINTERBIOS_H
#define POINTERBIOS_H

#include <stdint.h>
#include <dos.h>
#include <conio.h>
#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

static uint16_t *framebuffer = (uint16_t*)0xE0000000; // placeholder LFB
static int CursorW=0, CursorH=0;
static uint32_t CursorBitmap[64*64];
static int CursorX=100, CursorY=100;
static int OldX=100, OldY=100;
static int PointerBIOS_Running=0;

// ---------------------------------------------------
// Load 32-bit BMP cursor from memory
// ---------------------------------------------------
static int PointerBIOS_LoadBMP(const char* path) {
    FILE *f = fopen(path,"rb");
    if (!f) return 0;

    fseek(f,0,2);
    int filesize = ftell(f);
    fseek(f,0,0);
    uint8_t *buffer = malloc(filesize);
    if (!buffer) { fclose(f); return 0; }
    fread(buffer,1,filesize,f);
    fclose(f);

    CursorW = *(uint32_t*)&buffer[18];
    CursorH = *(uint32_t*)&buffer[22];
    uint32_t *pix = (uint32_t*)(buffer + *(uint32_t*)&buffer[10]);
    for (int y=0;y<CursorH;y++)
        for (int x=0;x<CursorW;x++)
            CursorBitmap[y*CursorW+x] = pix[(CursorH-1-y)*CursorW+x];

    free(buffer);
    return 1;
}

// ---------------------------------------------------
// Internal function: draw BMP at x,y with alpha
// ---------------------------------------------------
static void PointerBIOS_Draw() {
    for(int y=0;y<CursorH;y++)
        for(int x=0;x<CursorW;x++){
            uint32_t pix = CursorBitmap[y*CursorW+x];
            if ((pix>>24)==0) continue;
            framebuffer[(CursorY+y)*1024+(CursorX+x)] = pix;
        }
}

// ---------------------------------------------------
// Internal function: erase old cursor
// ---------------------------------------------------
static void PointerBIOS_Erase() {
    for(int y=0;y<CursorH;y++)
        for(int x=0;x<CursorW;x++)
            framebuffer[(OldY+y)*1024+(OldX+x)] = 0; // black bg
}

// ---------------------------------------------------
// Internal: smooth mouse logic
// ---------------------------------------------------
static void PointerBIOS_RunLoop() {
    PointerBIOS_Running = 1;
    while(PointerBIOS_Running) {
        OldX = CursorX; OldY = CursorY;

        union REGS in,out;
        in.x.ax = 3; int86(0x33,&in,&out);
        CursorX = out.x.cx;
        CursorY = out.x.dx;

        PointerBIOS_Erase();
        PointerBIOS_Draw();
    }
}

// ---------------------------------------------------
// Public: initialize pointer BIOS
// ---------------------------------------------------
static inline int PointerBIOS_Init(const char* bmpPath) {
    __asm__ __volatile__(
        "mov $0x4F02, %%ax\n\t"
        "mov $0x118, %%bx\n\t"
        "int $0x10\n\t"
        :::"ax","bx"
    );

    if (!PointerBIOS_LoadBMP(bmpPath)) return 0;

    PointerBIOS_RunLoop();
    return 1;
}

// ---------------------------------------------------
// Public: stop pointer BIOS
// ---------------------------------------------------
static inline void PointerBIOS_Remove() {
    PointerBIOS_Running = 0;
    PointerBIOS_Erase();
}

#ifdef __cplusplus
}
#endif

#endif
