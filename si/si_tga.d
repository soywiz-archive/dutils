module si_tga;

import si;

// http://local.wasp.uwa.edu.au/~pbourke/dataformats/tga/
class ImageFileFormat_TGA : ImageFileFormat {
	align(1) struct TGA_Header {
	   char  idlength;
	   char  colourmaptype;
	   char  datatypecode;
	   short colourmaporigin;
	   short colourmaplength;
	   char  colourmapdepth;
	   short x_origin;
	   short y_origin;
	   short width;
	   short height;
	   char  bitsperpixel;
	   char  imagedescriptor;
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
}

static this() {
	ImageFileFormatProvider.registerFormat(new ImageFileFormat_TGA);
}