module si_tga;

import si;
import std.string;

// http://local.wasp.uwa.edu.au/~pbourke/dataformats/tga/
class ImageFileFormat_TGA : ImageFileFormat {
	override char[] identifier() { return "tga"; }

	align(1) struct TGA_Header {
		ubyte idlength;           // 0
		ubyte colourmaptype;      // 1
		ubyte datatypecode;       // 2
		short colourmaporigin;    // 3-4
		short colourmaplength;    // 5-6
		ubyte colourmapdepth;     // 7
		short x_origin;           // 8-9
		short y_origin;           // 10-11
		short width;              // 12-13
		short height;             // 14-15
		ubyte bitsperpixel;       // 16
		ubyte imagedescriptor;    // 17
	   
		private alias imagedescriptor id;

		int  atr_bits()          { return Bit.EXT(id, 0, 3); }
		int  atr_bits(int v)     { id = Bit.INS(id, 0, 3, v); return atr_bits; }

		bool flip_y()            { return Bit.EXT(id, 5, 1) == 0; }
		bool flip_y(bool v)      { id = Bit.INS(id, 5, 1, !v); return flip_y; }

		int  interleaving()      { return Bit.EXT(id, 6, 2); }
		int  interleaving(int v) { id = Bit.INS(id, 6, 2, v); return interleaving; }
	}
	
	static assert (TGA_Header.sizeof == 18);

	override bool write(Image i, Stream s) {
		TGA_Header h;

		h.idlength = 0;
		h.x_origin = 0;
		h.y_origin = 0;
		h.width = i.width;
		h.height = i.height;
		//h.imagedescriptor = 0b_00_1_0_1000;
		h.flip_y = false;
		
		if (i.hasPalette) {
			h.colourmaptype = 1;
			h.datatypecode = 1;
			h.colourmaporigin = 0;
			h.colourmaplength = i.ncolor;
			h.colourmapdepth = 24;
			h.bitsperpixel = 8;
			
			h.imagedescriptor |= 8;
			//h.imagedescriptor = 8;
		} else {
			h.colourmaptype = 0;
			h.datatypecode = 2;
			h.colourmaplength = 0;
			h.colourmapdepth = 0;
			h.bitsperpixel = 32;
		}

		s.write(TA(h));
		
		// CLUT
		if (i.hasPalette) {
			for (int n = 0; n < h.colourmaplength; n++) {
				s.write(TA(RGBA.toBGRA(i.color(n)))[0..(h.colourmapdepth / 8)]);
			}
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
				*cast(uint *)ptr = RGBA.toBGRA(c).v;
				ptr += 4;
			}
		}

		s.write(data);
		
		s.write(cast(ubyte[])x"000000000000000054525545564953494F4E2D5846494C452E00");

		return false;
	}
	
	override Image read(Stream s) {
		TGA_Header h; s.read(TA(h));

		// Skips Id Length field
		s.seek(h.idlength, SeekPos.Current);
		
		assert (h.width <= 4096);
		assert (h.height <= 4096);
		
		assert (h.x_origin == 0);
		assert (h.y_origin == 0);

		RGBA readcol(int depth) {
			RGBA c;
			switch (depth) {
				case 16:
				break;
				case 24:
					s.read(TA(c)[0..3]);
					c = RGBA.toBGRA(c);
					c.a = 0xFF;					
				break;
				case 32:
					s.read(TA(c)[0..4]);
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
		TGA_Header h; s.read(TA(h));
		switch (h.datatypecode) {
			default: return 0;
			case 0, 1, 2, 3, 9, 10, 11, 32, 33: break;
		}

		if (h.width > 4096 || h.height > 4096) return 0;
		
		return 5;
	}	
}

static this() {
	ImageFileFormatProvider.registerFormat(new ImageFileFormat_TGA);
}