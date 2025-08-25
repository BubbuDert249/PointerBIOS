#ifndef POINTERBIOS_H
#define POINTERBIOS_H

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <dos.h>

#ifdef __cplusplus
extern "C" {
#endif

// -------------------------------------------
// Public API
// -------------------------------------------
int PointerBIOS_Init(const char* bmpPath);
void PointerBIOS_Remove(void);

// -------------------------------------------
// Internal state
// -------------------------------------------
static uint16_t CursorW=0, CursorH=0;
static int CursorX=100, CursorY=100;
static int OldX=100, OldY=100;
static uint32_t *CursorBitmap=NULL;
static uint32_t *FrameBuffer=(uint32_t*)0xE0000000; // Linear framebuffer
static int PointerBIOS_Running=0;

// -------------------------------------------
// Internal functions
// -------------------------------------------
static int LoadBMP(const char* path) {
    FILE *f = fopen(path, "rb");
    if (!f) return 0;

    fseek(f, 0, SEEK_END);
    long filesize = ftell(f);
    fseek(f, 0, SEEK_SET);

    uint8_t *buffer = malloc(filesize);
    if (!buffer) { fclose(f); return 0; }

    fread(buffer, 1, filesize, f);
    fclose(f);

    CursorW = *(uint32_t*)&buffer[18];
    CursorH = *(uint32_t*)&buffer[22];
    long pixOffset = *(uint32_t*)&buffer[10];

    if(CursorBitmap) free(CursorBitmap);
    CursorBitmap = malloc(sizeof(uint32_t)*CursorW*CursorH);
    if (!CursorBitmap) { free(buffer); return 0; }

    uint32_t *pix = (uint32_t*)(buffer + pixOffset);
    for(int y=0;y<CursorH;y++)
        for(int x=0;x<CursorW;x++)
            CursorBitmap[y*CursorW + x] = pix[(CursorH-1-y)*CursorW + x]; // flip vertically

    free(buffer);
    return 1;
}

static void DrawCursor() {
    for(int y=0;y<CursorH;y++)
        for(int x=0;x<CursorW;x++){
            uint32_t pix = CursorBitmap[y*CursorW + x];
            if ((pix>>24)==0) continue; // alpha=0 = transparent
            FrameBuffer[(CursorY+y)*1024 + (CursorX+x)] = pix;
        }
}

static void EraseCursor() {
    for(int y=0;y<CursorH;y++)
        for(int x=0;x<CursorW;x++)
            FrameBuffer[(OldY+y)*1024 + (OldX+x)] = 0; // black background
}

static void PointerBIOS_RunLoop() {
    PointerBIOS_Running = 1;
    union REGS in,out;

    while(PointerBIOS_Running){
        OldX = CursorX; OldY = CursorY;

        in.x.ax = 3; // mouse position
        int86(0x33, &in, &out);
        CursorX = out.x.cx;
        CursorY = out.x.dx;

        EraseCursor();
        DrawCursor();
    }
}

// -------------------------------------------
// Public API
// -------------------------------------------
static inline int PointerBIOS_Init(const char* bmpPath) {
    // Set VESA 1024x768x32
    __asm__ __volatile__ (
        "mov $0x4F02, %%ax\n\t"
        "mov $0x118, %%bx\n\t"
        "int $0x10\n\t"
        :::"ax","bx"
    );

    if(!LoadBMP(bmpPath)) return 0;

    PointerBIOS_RunLoop();
    return 1;
}

static inline void PointerBIOS_Remove(void){
    PointerBIOS_Running = 0;
    EraseCursor();
    if(CursorBitmap){ free(CursorBitmap); CursorBitmap=NULL; }
}

#ifdef __cplusplus
}
#endif
#endif
