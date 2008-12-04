module si;

public import
	std.stream, 
	std.stdio, 
	std.intrinsic, 
	std.path,
	std.math,
	std.file,
	std.process,
	std.string
;

int imin(int a, int b) { return (a < b) ? a : b; }
int imax(int a, int b) { return (a > b) ? a : b; }
int iabs(int a) { return (a < 0) ? -a : a; }

template TA(T) { ubyte[] TA(inout T t) { return cast(ubyte[])(&t)[0..1]; } }

class Bit {
	final static uint MASK(ubyte size) {
		return ((1 << size) - 1);
	}
	
	final static uint INS(uint v, ubyte pos, ubyte size, int iv) {
		uint mask = MASK(size);
		return (v & ~(mask << pos)) | ((iv & mask) << pos);
	}
	
	final static uint EXT(uint v, ubyte pos, ubyte size) {
		return (v >> pos) & MASK(size);
	}
}

class ImageFileFormatProvider {
	static ImageFileFormat[char[]] list;

	static void registerFormat(ImageFileFormat iff) {
		list[iff.identifier] = iff;
	}

	static ImageFileFormat find(Stream s, int check_size = 1024) {
		auto cs = new MemoryStream();
		cs.copyFrom(new SliceStream(s, s.position, s.position + check_size));
	
		ImageFileFormat cff;
		int certain = 0;
		foreach (iff; list.values) {
			int c_certain = iff.check(new SliceStream(cs, 0));
			if (c_certain > certain) {
				cff = iff;
				certain = c_certain;
				if (certain >= 10) break;
			}
		}
		if (certain == 0) throw(new Exception("Unrecognized ImageFileFormat"));
		return cff;
	}

	static Image read(Stream s) { return find(s).read(s); }
	
	static Image read(char[] name) {
		Stream s = new BufferedFile(name);
		Image i = read(s);
		s.close();
		return i;
	}

	static ImageFileFormat opIndex(char[] idx) {
		if ((idx in list) is null) throw(new Exception(std.string.format("Unknown ImageFileFormat '%s'", idx)));
		return list[idx];
	}
}

// Abstract ImageFileFormat
abstract class ImageFileFormat {
	private this() { }
	
	bool update(Image i, Stream s) { throw(new Exception("Updating not implemented")); return false; }
	bool update(Image i, char[] name) { Stream s = new File(name, FileMode.OutNew); bool r = update(i, s); s.close(); return r; }
	
	bool write(Image i, Stream s) { throw(new Exception("Writing not implemented")); return false; }
	bool write(Image i, char[] name) { Stream s = new File(name, FileMode.OutNew); bool r = write(i, s); s.close(); return r; }
	
	Image read(Stream s) { throw(new Exception("Reading not implemented")); return null; }
	Image[] readMultiple(Stream s) { throw(new Exception("Multiple reading not implemented")); return null; }

	char[] identifier() { return "null"; }
	
	// 0 - impossible (discard)
	//
	// ... different levels of probability (uses the most probable)
	//
	// 10 - for sure (use this)
	int check(Stream s) { return 0; }
}

// TrueColor pixel
align(1) struct RGBA {
	union {
		struct { ubyte r; ubyte g; ubyte b; ubyte a; }
		struct { byte _r; byte _g; byte _b; byte _a; }
		ubyte[4] vv;
		uint v;
	}
	
	static RGBA opCall(ubyte r, ubyte g, ubyte b, ubyte a = 0xFF) {
		RGBA c = void;
		c.r = r;
		c.g = g;
		c.b = b;
		c.a = a;
		return c;
	}
	
	static RGBA opCall(uint v) {
		RGBA c = void;
		c.v = v;
		return c;
	}
	
	static RGBA toBGRA(RGBA c) {
		ubyte r = c.r;
		c.r = c.b;
		c.b = r;
		return c;
	}
	
	static int dist(RGBA a, RGBA b) {
		return (
			Math.abs(a._r - b._r) +
			Math.abs(a._g - b._g) +
			Math.abs(a._b - b._b) +
			Math.abs(a._a - b._a) +
		0);
	}
}

static assert (RGBA.sizeof == 4);

// Abstract Image
abstract class Image {
	char[] id;
	Image[] childs;

	// Info
	ubyte bpp();
	int width();
	int height();

	// Data
	void set(int x, int y, uint v);
	uint get(int x, int y);

	void set32(int x, int y, RGBA c) {
		if (bpp == 32) { return set(x, y, c.v); }
		throw(new Exception("Not implemented (set32)"));
	}

	RGBA get32(int x, int y) {
		if (bpp == 32) {
			RGBA c; c.v = get(x, y);
			return c;
		}
		throw(new Exception("Not implemented (get32)"));
	}

	RGBA getColor(int x, int y) {
		RGBA c;
		c.v = hasPalette ? color(get(x, y)).v : get(x, y);
		return c;
	}

	// Palette
	bool hasPalette() { return (bpp <= 8); }
	int ncolor() { return 0; }
	int ncolor(int n) { return ncolor; }
	RGBA color(int idx) { RGBA c; return c; }
	RGBA color(int idx, RGBA c) { return color(idx); }
	RGBA[] colors() {
		RGBA[] cc;
		for (int n = 0; n < ncolor; n++) cc ~= color(n);
		return cc;
	}

	static uint colorDist(RGBA c1, RGBA c2) {
		return (
			(
				iabs(c1.r * c1.a - c2.r * c2.a) +
				iabs(c1.g * c1.a - c2.g * c2.a) +
				iabs(c1.b * c1.a - c2.b * c2.a) +
				iabs(c1.a * c1.a - c2.a * c2.a) +
			0)
		);
	}

	RGBA[] createPalette(int count) {
		throw(new Exception("Not implemented: createPalette"));
	}

	uint matchColor(RGBA c) {
		uint mdist = 0xFFFFFFFF;
		uint idx;
		for (int n = 0; n < ncolor; n++) {
			uint cdist = colorDist(color(n), c);
			if (cdist < mdist) {
				mdist = cdist;
				idx = n;
			}
		}
		return idx;
	}

	void copyFrom(Image i, bool convertPalette = false) {
		int mw = imin(width, i.width);
		int mh = imin(height, i.height);

		//if (bpp != i.bpp) throw(new Exception(std.string.format("BPP mismatch copying image (%d != %d)", bpp, i.bpp)));

		if (i.hasPalette) {
			ncolor = i.ncolor;
			for (int n = 0; n < ncolor; n++) color(n, i.color(n));
		}

		/*if (hasPalette && !i.hasPalette) {
			i = toColorIndex(i);
		}*/

		if (convertPalette && hasPalette && !i.hasPalette) {
			foreach (idx, c; i.createPalette(ncolor)) color(idx, c);
		}

		if (hasPalette && i.hasPalette) {
			for (int y = 0; y < i.height; y++) for (int x = 0; x < i.width; x++) set(x, y, get(x, y));
		} else if (hasPalette) {
			for (int y = 0; y < i.height; y++) for (int x = 0; x < i.width; x++) set(x, y, matchColor(i.get32(x, y)));
		} else {
			for (int y = 0; y < i.height; y++) for (int x = 0; x < i.width; x++) set32(x, y, i.get32(x, y));
		}
	}
	
	static Image composite(Image color, Image alpha) {
		Image r = new Bitmap32(color.width, color.height);
		for (int y = 0; y < color.height; y++) {
			for (int x = 0; x < color.width; x++) {
				RGBA c = color.get32(x, y);
				RGBA a = alpha.get32(x, y);
				c.a = a.r;
				r.set32(x, y, c);
			}
		}
		return r;
	}
	
	void setChroma(RGBA c) {
		if (hasPalette) {
			foreach (idx, cc; colors) {
				if (cc == c) color(idx, RGBA(0, 0, 0, 0));
			}
		} else {
			for (int y = 0; y < height; y++) {
				for (int x = 0; x < width; x++) {
					if (get32(x, y) == c) set32(x, y, RGBA(0, 0, 0, 0));
				}
			}
		}
	}
	
	void write(char[] file, char[] format = null) {
		if (format is null) format = getExt(file);
		ImageFileFormatProvider[format].write(this, file);
	}
	void write(Stream file, char[] format) { ImageFileFormatProvider[format].write(this, file); }
}

// TrueColor Bitmap
class Bitmap32 : Image {
	RGBA[] data;
	int _width, _height;

	ubyte bpp() { return 32; }
	int width() { return _width; }
	int height() { return _height; }

	void set(int x, int y, uint v) { data[y * _width + x].v = v; }
	uint get(int x, int y) { return data[y * _width + x].v; }

	this(int w, int h) {
		_width = w;
		_height = h;
		data.length = w * h;
	}
}

// Palletized Bitmap
class Bitmap8 : Image {
	RGBA[] palette;
	ubyte[] data;
	int _width, _height;

	override ubyte bpp() { return 8; }
	int width() { return _width; }
	int height() { return _height; }

	void set(int x, int y, uint v) { data[y * _width + x] = v; }
	uint get(int x, int y) { return data[y * _width + x]; }

	override RGBA get32(int x, int y) {
		return palette[get(x, y) % palette.length];		
	}
	
	override int ncolor() { return palette.length;}
	override int ncolor(int s) { palette.length = s; return s; }
	RGBA color(int idx) { return palette[idx]; }
	RGBA color(int idx, RGBA col) { return palette[idx] = col; }
	void colorSwap(int i1, int i2) {
		if (i1 >= palette.length || i2 >= palette.length) return;
		RGBA ct = palette[i1];
		palette[i1] = palette[i2];
		palette[i2] = ct;
	}

	this(int w, int h) {
		_width = w;
		_height = h;
		data.length = w * h;
	}
}