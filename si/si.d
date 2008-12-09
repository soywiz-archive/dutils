module si;

public import
	std.stream, 
	std.stdio, 
	std.intrinsic, 
	std.path,
	std.math,
	std.file,
	std.process,
	std.string,
	std.system
;

int imin(int a, int b) { return (a < b) ? a : b; }
int imax(int a, int b) { return (a > b) ? a : b; }
int iabs(int a) { return (a < 0) ? -a : a; }

void cendian(ref ushort v, Endian endian) { if (endian != std.system.endian) v = (bswap(v) >> 16); }
void cendian(ref uint   v, Endian endian) { if (endian != std.system.endian) v = bswap(v); }

template TA(T) { ubyte[] TA(inout T t) { return cast(ubyte[])(&t)[0..1]; } }

class Bit {
	final static ulong MASK(ubyte size) {
		return ((1 << size) - 1);
	}
	
	final static ulong INS(ulong v, ubyte pos, ubyte size, int iv) {
		ulong mask = MASK(size);
		return (v & ~(mask << pos)) | ((iv & mask) << pos);
	}
	
	final static ulong EXT(ulong v, ubyte pos, ubyte size) {
		return (v >> pos) & MASK(size);
	}
	
	static long div_mult_ceil (long v, long mult, long div) { return cast(long)std.math.ceil (cast(real)(v * mult) / cast(real)div); }
	static long div_mult_round(long v, long mult, long div) { return cast(long)std.math.round(cast(real)(v * mult) / cast(real)div); }
	static long div_mult_floor(long v, long mult, long div) { return (v * mult) / div; }
	alias div_mult_floor div_mult;

	//////////////////////////

	final static ulong INS2(ulong v, ubyte pos, ubyte size, int iv, int base) {
		ulong mask = MASK(size);

		/*
		writefln("%d", iv);
		writefln("%d", mask);
		writefln("%d", base);
		writefln("--------");
		*/
	
		return INS(v, pos, size, div_mult_ceil(iv, mask, base));
	}

	final static ulong EXT2(ulong v, ubyte pos, ubyte size, int base) {
		ulong mask = MASK(size);
		if (mask == 0) return 0;
		
		/*
		writefln("%d", EXT(v, pos, size));
		writefln("%d", base);
		writefln("%d", mask);
		writefln("--------");
		*/
		
		return div_mult_ceil(EXT(v, pos, size), base, mask);
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

align(1) struct ColorFormat {
	align(1) struct Set {
		union {
			struct { ubyte r, g, b, a; }
			ubyte[4] vv;
		}
	}
	Set pos, len;
}

ColorFormat RGBA_8888 = { {0, 8, 16, 24}, {8, 8, 8, 8} };
ColorFormat RGBA_5551 = { {0, 5, 10, 15}, {5, 5, 5, 1} };
ColorFormat RGBA_5650 = { {0, 5, 11, 26}, {5, 6, 5, 0} };

// TrueColor pixel
align(1) struct RGBA {
	union {
		struct { ubyte r; ubyte g; ubyte b; ubyte a; }
		struct { byte _r; byte _g; byte _b; byte _a; }
		ubyte[4] vv;
		uint v;
		alias r R;
		alias g G;
		alias b B;
		alias a A;
	}
	
	ulong decode(ColorFormat format) {
		ulong rr;
		for (int n = 0; n < 4; n++) rr = Bit.INS2(rr, format.pos.vv[n], format.len.vv[n], vv[n], 0xFF);
		return rr;
	}
	
	static RGBA opCall(ColorFormat format, ulong data) {
		RGBA c = void;
		for (int n = 0; n < 4; n++) c.vv[n] = Bit.EXT2(data, format.pos.vv[n], format.len.vv[n], 0xFF);
		return c;
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
		alias std.math.abs abs;
		return (
			abs(a._r - b._r) +
			abs(a._g - b._g) +
			abs(a._b - b._b) +
			abs(a._a - b._a) +
		0);
	}
	
	char[] toString() {
		return std.string.format("RGBA(%02X,%02X,%02X,%02X)", r, g, b, a);
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
	
	static Bitmap32 convert(Image i) {
		auto r = new Bitmap32(i.width, i.height);
		for (int y = 0; y < r._height; y++) for (int x = 0; x < r._width; x++) r.set32(x, y, i.get32(x, y));
		return r;
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