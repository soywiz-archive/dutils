module simple_image_tm2;

import simple_image;

import std.stream;
import std.stdio;
import std.intrinsic;
import std.path;
import std.file;
import std.process;

align(1) struct TIM2Header {
	char[4]  FileId = "TIM2"; //  ID of the File (must be 'T', 'I', 'M' and '2')
	ubyte    FormatVersion; // Version number of the format
	ubyte    FormatId;      // ID of the format
	ushort   Pictures;      // Number of picture data
	ubyte[8] pad;           // Padding (must be 0x00)
}

align(1) struct TIM2EntryHeader {
	uint   TotalSize;   // Total size of the picture data in bytes
	uint   ClutSize;    // CLUT data size in bytes
	uint   ImageSize;   // Image data size in bytes
	ushort HeaderSize;  // Header size in bytes
	ushort ClutColors;  // Total color number in CLUT data
	ubyte  PictFormat;  // ID of the picture format (must be 0)
	ubyte  MipMapTexs;  // Number of MIPMAP texture
	ubyte  ClutType;    // Type of the CLUT data
	ubyte  ImageType;   // Type of the Image data
	ushort ImageWidth;  // Width of the picture
	ushort ImageHeight; // Height of the picture

	ubyte GsTex0[8];    // Data for GS TEX0 register
	ubyte GsTex1[8];    // Data for GS TEX1 register
	uint  GsRegs;       // Data for GS TEXA, FBA, PABE register
	uint  GsTexClut;    // Data for GS TEXCLUT register
}

align(1) struct TIM2MipMapHeader{
	ulong GsMiptbp1;
	ulong GsMiptbp2;
	uint  MMImageSize[0];
}

align(1) struct TIM2ExtHeader {
	ubyte[4] ExHeaderId = ['e', 'X', 't', 0];
	uint     UserSpaceSize;
	uint     UserDataSize;
	uint     Reserved;
}

//debug = tm2_stream;

class ImageFileFormat_TM2 : ImageFileFormat {
	override char[] identifier() { return "tm2"; }

	char[] header = "TIM2";
	
	override bool update(Image i, Stream s) {
		return false;
	}

	override Image read(Stream s) {
		Image ic = new Bitmap8(1, 1);
		TIM2Header h;
		
		s.read(TA(h));
		if (h.FileId != "TIM2") throw(new Exception("File isn't a TIM2 one"));
		
		int pcount = h.Pictures;
		while (pcount--) {
			ubyte[] palette;
			ubyte[] dimage;

			// Leemos el header
			TIM2EntryHeader teh; s.read(TA(teh));
			s.seek(teh.HeaderSize - teh.sizeof, SeekPos.Current);

			// Leemos la imagen
			dimage.length = teh.ImageSize; s.read(dimage);
			
			switch (teh.ImageType) {
				default: throw(new Exception(std.string.format("Unknown TIM2 Image Type 0x%02X", teh.ImageType)));
				case 0x05: // con paleta (4 bits) 8bpp
					Bitmap8 i = new Bitmap8(teh.ImageWidth, teh.ImageHeight);
					
					switch (teh.ClutType) {
						default: throw(new Exception(std.string.format("Unknown TIM2 Clut Type 0x%02X", teh.ClutType)));
						case 0x02: case 0x03:
							uint pbpp = (teh.ClutType + 1);
							//writefln("TYPE:", pbpp);
							//s.seek(teh.ClutSize - pbpp * 0x10, SeekPos.Current);

							// Leemos la paleta
							palette.length = teh.ClutSize; s.read(palette);

							//writefln("%d", teh.ClutColors);
							i.ncolor = teh.ClutColors;

							for (int y = 0, n = 0; y < teh.ImageHeight; y++) {
								for (int x = 0; x < teh.ImageWidth; x++, n++) {
									i.set(x, y, dimage[n]);
								}
							}

							for (int n = 0; n < i.ncolor; n++) {
								RGBA c = RGBA(palette[n * pbpp + 0], palette[n * pbpp + 1], palette[n * pbpp + 2]);
								if (pbpp > 3) c.a = palette[n * pbpp + 3];
								i.color(n, c);
							}
							
							// Unswizzle
							for (int n = 8; n < 256; n += 4 * 8) for (int m = 0; m < 8; m++) i.colorSwap(n + m, n + m + 8);
						break;
					}
					
					ic.childs ~= i;
				break;
				case 0x04: // con paleta (4 bits) 4bpp
					Bitmap8 i = new Bitmap8(teh.ImageWidth, teh.ImageHeight);

					switch (teh.ClutType) {
						default: throw(new Exception(std.string.format("Unknown TIM2 Clut Type 0x%02X", teh.ClutType)));
						case 0x02: case 0x03:
							uint pbpp = (teh.ClutType + 1);

							palette.length = teh.ClutSize; s.read(palette);

							i.ncolor = teh.ClutColors;
							for (int y = 0, n = 0; y < teh.ImageHeight; y++) {
								for (int x = 0; x < teh.ImageWidth; x += 2, n++) {
									i.set(x + 0, y, (dimage[n] & 0x0F) >> 0);
									i.set(x + 1, y, (dimage[n] & 0xF0) >> 4);
								}
							}

							for (int n = 0; n < i.ncolor; n++) {
								RGBA c = RGBA(palette[n * pbpp + 0], palette[n * pbpp + 1], palette[n * pbpp + 2]);
								if (pbpp > 3) c.a = palette[n * pbpp + 3];
								i.color(n, c);
							}
						break;
					}
					
					ic.childs ~= i;
				break;
				case 0x03: // a 32 bits
					Bitmap32 i = new Bitmap32(teh.ImageWidth, teh.ImageHeight);
					for (int y = 0, n = 0; y < teh.ImageHeight; y++) {
						for (int x = 0; x < teh.ImageWidth; x++, n += 4) {
							RGBA c = RGBA(dimage[n + 0], dimage[n + 1], dimage[n + 2], dimage[n + 3]);
							i.set(x, y, c.v);
						}
					}
					
					ic.childs ~= i;
				break;				
			}
			
		}
		
		return ic;
	}

	override bool check(Stream s) { return s.readString(header.length) == header; }
}

static this() {
	ImageFileFormatProvider.registerFormat(new ImageFileFormat_TM2);
}