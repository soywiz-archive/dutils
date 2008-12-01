module si_bmp;

import si;

class ImageFileFormat_BMP : ImageFileFormat {
	align(1) struct BITMAPFILEHEADER {
		char[2] bfType;
		uint    bfSize;
		ushort  bfReserved1;
		ushort  bfReserved2;
		uint    bfOffBits;
	}
	
	align(1) struct BITMAPINFOHEADER {
		uint   biSize;
		int    biWidth;
		int    biHeight;
		ushort biPlanes;
		ushort biBitCount;
		uint   biCompression;
		uint   biSizeImage;
		int    biXPelsPerMeter;
		int    biYPelsPerMeter;
		uint   biClrUsed;
		uint   biClrImportant;
	}
	
	struct RGBQUAD {
		ubyte rgbBlue;
		ubyte rgbGreen;
		ubyte rgbRed;
		ubyte rgbReserved;
	}

	override char[] identifier() { return "bmp"; }
	
	Image read(Stream s) {
		Image i;
		BITMAPFILEHEADER h;
		BITMAPINFOHEADER ih;
		s.read(TA(h));
		s.read(TA(ih));
		
		if (ih.biCompression) throw(new Exception("BMP compression not supported"));
		if (ih.biPlanes > 1) throw(new Exception("Only supported 1 bitplane"));
		
		switch (ih.biBitCount) {
			default: case 4: throw(new Exception(std.string.format("BPP %d not supported", ih.biBitCount)));
			case 8:
				i = new Bitmap8(ih.biWidth, ih.biHeight);
				i.ncolor = ih.biClrUsed ? ih.biClrUsed : (1 << ih.biBitCount);
				for (int n = 0; n < i.ncolor; n++) {
					//RGBQUAD c;
					RGBA c;
					s.read(TA(c));
					c = RGBA.toBGRA(c);
					c.a = 0xFF;
					i.color(n, c);
				}
				ubyte[] data;
				data.length = ih.biWidth * ih.biHeight;
				
				s.position = h.bfOffBits;
				s.read(data);
				
				for (int y = ih.biHeight - 1, n = 0; y >= 0; y--) {
					for (int x = 0; x < ih.biWidth; x++, n++) {
						i.set(x, y, data[n]);
					}
				}
			break;
			case 24:
				i = new Bitmap32(ih.biWidth, ih.biHeight);
				ubyte[] data;
				data.length = ih.biWidth * ih.biHeight * 3;
				s.position = h.bfOffBits;
				s.read(data);
				for (int y = ih.biHeight - 1, n = 0; y >= 0; y--) {
					for (int x = 0; x < ih.biWidth; x++, n += 3) {
						RGBA c = *cast(RGBA *)(data.ptr + n);
						c.a = 0xFF;
						c = RGBA.toBGRA(c);
						i.set32(x, y, c);
					}
				}				
			break;
		}
		
		return i;
	}
	
	override int check(Stream s) {
		BITMAPFILEHEADER h;
		s.read(TA(h));
		return (h.bfType == "BM") ? 10 : 0;
	}
}

static this() {
	ImageFileFormatProvider.registerFormat(new ImageFileFormat_BMP);
}