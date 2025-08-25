unit PointerBIOS;

interface
uses Dos;

procedure PointerBIOS_Init(bmpPath: string);
procedure PointerBIOS_Remove;

implementation

var
  CursorX, CursorY: Word;
  OldX, OldY: Word;
  CursorW, CursorH: Word;
  PointerBIOS_Running: Boolean;
  CursorBitmap: array of LongWord;
  FrameBuffer: ^LongWord = Ptr($E0000000,0); // VESA framebuffer
  BMPBuffer: array of Byte;

procedure LoadBMP(bmpPath: string);
var
  f: File;
  size, pixOffset, x, y: LongWord;
  pix: ^LongWord;
begin
  Assign(f, bmpPath);
  Reset(f,1); // binary mode
  size := FileSize(f);
  SetLength(BMPBuffer, size);
  BlockRead(f, BMPBuffer[0], size);
  Close(f);

  CursorW := PLongWord(@BMPBuffer[18])^;
  CursorH := PLongWord(@BMPBuffer[22])^;
  pixOffset := PLongWord(@BMPBuffer[10])^;
  SetLength(CursorBitmap, CursorW*CursorH);
  pix := @BMPBuffer[pixOffset];

  // Copy pixels with vertical flip
  for y := 0 to CursorH-1 do
    for x := 0 to CursorW-1 do
      CursorBitmap[y*CursorW+x] := pix[(CursorH-1-y)*CursorW + x]; // flip vertically
end;

procedure DrawCursor;
var x,y: Integer; pix: LongWord;
begin
  for y := 0 to CursorH-1 do
    for x := 0 to CursorW-1 do
    begin
      pix := CursorBitmap[y*CursorW+x];
      if (pix shr 24) = 0 then Continue; // alpha=0 transparent
      FrameBuffer^[(CursorY+y)*1024 + (CursorX+x)] := pix;
    end;
end;

procedure EraseCursor;
var x,y: Integer;
begin
  for y := 0 to CursorH-1 do
    for x := 0 to CursorW-1 do
      FrameBuffer^[(OldY+y)*1024 + (OldX+x)] := 0;
end;

procedure PointerBIOS_Init(bmpPath: string);
var regs: Registers;
begin
  // Set VESA 1024x768x32
  regs.ax := $4F02;
  regs.bx := $118;
  Intr($10, regs);

  LoadBMP(bmpPath);
  PointerBIOS_Running := True;

  while PointerBIOS_Running do
  begin
    OldX := CursorX; OldY := CursorY;
    regs.ax := 3;
    Intr($33, regs);
    CursorX := regs.cx;
    CursorY := regs.dx;

    EraseCursor;
    DrawCursor;
  end;
end;

procedure PointerBIOS_Remove;
begin
  PointerBIOS_Running := False;
  EraseCursor;
end;

end.
