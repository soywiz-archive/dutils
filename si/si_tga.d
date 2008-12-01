module si_tga;

import si;
import std.string;

// http://local.wasp.uwa.edu.au/~pbourke/dataformats/tga/
class ImageFileFormat_TGA : ImageFileFormat {
	align(1) struct TGA_Header {
		ubyte idlength;
		ubyte colourmaptype;
		ubyte datatypecode;
		short colourmaporigin;
		short colourmaplength;
		ubyte colourmapdepth;
		short x_origin;
		short y_origin;
		short width;
		short height;
		ubyte bitsperpixel;
		ubyte imagedescriptor;
	   
		int  atr_bits()     { return ((imagedescriptor >> 0) & 0b111) != 0; }
		bool flip_y()       { return !((imagedescriptor >> 5) & 0b1  ) != 0; }
		int  interleaving() { return ((imagedescriptor >> 6) & 0b11 ) != 0; }
	}

	override char[] identifier() { return "tga"; }

	RGBA RGBA_BGRA(RGBA ic) {
		RGBA oc;
		oc.vv[0] = ic.vv[2]; oc.vv[1] = ic.vv[1];
		oc.vv[2] = ic.vv[0]; oc.vv[3] = ic.vv[3];
		return oc;
	}

	override bool write(Image i, Stream s) {
		TGA_Header h;

		h.idlength = 0;
		h.x_origin = 0;
		h.y_origin = 0;
		h.width = i.width;
		h.height = i.height;
		h.colourmaporigin = 0;
		h.imagedescriptor = 0b_00_1_0_1000;

		if (i.hasPalette) {
			h.colourmaptype = 1;
			h.datatypecode = 1;
			h.colourmaplength = i.ncolor;
			h.colourmapdepth = 32;
			h.bitsperpixel = 8;
		} else {
			h.colourmaptype = 0;
			h.datatypecode = 2;
			h.colourmaplength = 0;
			h.colourmapdepth = 0;
			h.bitsperpixel = 32;
		}

		s.writeExact(&h, h.sizeof);

		// CLUT
		if (i.hasPalette) {
			for (int n = 0; n < i.ncolor; n++) s.write(RGBA_BGRA(i.color(n)).v);
		}

		ubyte[] data;
		data.length = h.width * h.height * (i.hasPalette ? 1 : 4);
		//writef("(%dx%d)", h.width, h.height);

		ubyte *ptr = data.ptr;
		if (i.hasPalette) {
			for (int y = 0; y < h.height; y++) for (int x = 0; x < h.width; x++) {
				*ptr = cast(ubyte)i.get(x, y);
				ptr++;
			}
		} else {
			for (int y = 0; y < h.height; y++) for (int x = 0; x < h.width; x++) {
				RGBA c; c.v = i.get(x, y);
				*cast(uint *)ptr = RGBA_BGRA(c).v;
				ptr += 4;
			}
		}

		s.write(data);

		return false;
	}
	
	override Image read(Stream s) {
		TGA_Header h; s.read(cast(ubyte[])(&h)[0..1]);

		// Skips Id Length field
		s.seek(h.idlength, SeekPos.Current);
		
		assert (h.width <= 4096);
		assert (h.height <= 4096);

		RGBA readcol(int depth) {
			RGBA c;
			switch (depth) {
				case 16:
				break;
				case 24:
					s.read((cast(ubyte[])(&c)[0..1])[0..3]);
					c = RGBA.toBGRA(c);
					c.a = 0xFF;					
				break;
				case 32:
					s.read((cast(ubyte[])(&c)[0..1])[0..4]);
					c = RGBA.toBGRA(c);
				break;
				default: throw(new Exception(format("Invalid TGA Color Map Depth %d", h.colourmapdepth)));
			}
			return c;
		}
		
		int readcols(RGBA[] r, int depth) {
			for (int n = 0; n < r.length; n++) {
				r[n] = readcol(depth);
			}
			return r.length;
		}

		int y_from, y_to, y_inc;
			
		if (h.flip_y) {
			y_from = h.height - 1;
			y_to = -1;
			y_inc = -1;
		} else {
			y_from = 0;
			y_to = h.height;
			y_inc = 1;
		}		
		
		switch (h.datatypecode) {
			case 0: // No image data included.
			{
				return null;
			}
			break;
			case 1: // Uncompressed, color-mapped images.
			{
				auto i = new Bitmap8(h.width, h.height);
				
				if (h.colourmaporigin + h.colourmaplength > 0x100) {
					throw(new Exception("Not implemented multibyte mapped images"));
				}
				
				i.ncolor = h.colourmaporigin + h.colourmaplength;
				
				for (int n = 0; n < h.colourmaplength; n++) {
					i.color(n + h.colourmaporigin, readcol(h.colourmapdepth));
				}

				auto row = new ubyte[h.width];

				for (int y = y_from; y != y_to; y += y_inc) {
					s.read(row);
					for (int x = 0; x < h.width; x++) {
						i.set(x, y, row[x]);
					}
				}
				
				return i;
			}
			break;
			case 2: // Uncompressed, RGB images.
			{
				auto i = new Bitmap32(h.width, h.height);
				
				auto row = new RGBA[h.width];
				for (int y = y_from; y != y_to; y += y_inc) {
					readcols(row, h.bitsperpixel);
					for (int x = 0; x < h.width; x++) {
						i.set32(x, y, row[x]);
					}
				}
				//writefln(h.bitsperpixel);
				
				return i;
			}
			break;
			case  3:  // Uncompressed, black and white images.
			case  9:  // Runlength encoded color-mapped images.
			case 10:  // Runlength encoded RGB images.
			case 11:  // Compressed, black and white images.
			case 32:  // Compressed color-mapped data, using Huffman, Delta, and runlength encoding.
			case 33:  // Compressed color-mapped data, using Huffman, Delta, and runlength encoding.  4-pass quadtree-type process.
			break;
			default: throw(new Exception(format("Invalid tga colour map type: %d", h.datatypecode)));
		}

		throw(new Exception(format("Unimplemented tga colour map type: %d", h.datatypecode)));
		return null;
	}
	
	override int check(Stream s) {
		TGA_Header h; s.read(cast(ubyte[])(&h)[0..1]);
		switch (h.datatypecode) {
			default: return 0;
			case 0, 1, 2, 3, 9, 10, 11, 32, 33: break;
		}
		
		return 5;
	}	
}

static this() {
	ImageFileFormatProvider.registerFormat(new ImageFileFormat_TGA);
}