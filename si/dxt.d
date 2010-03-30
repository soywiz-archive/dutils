import std.stdio, std.string, std.file, std.stream, std.bitarray;

static ulong mask(int count) { return (1 << count) - 1; }

align(1) struct RGBA {
	union {
		struct { ubyte r, g, b, a; }
		struct { ubyte vv[4]; }
		uint v;
	}
	
	static ubyte normalize(int c, int v) {
		return ((c & mask(v)) * 0xFF) / mask(v);
		//return ((c & mask(v)) * 0x100) / (mask(v) + 1);
	}

	void decode565(ushort v) {
		r = normalize((v >> 0 ), 5);
		g = normalize((v >> 5 ), 6);
		b = normalize((v >> 11), 5);
		a = 0xFF;
	}
	
	static RGBA mix(RGBA a, RGBA b, int div, int a_c, int b_c) {
		RGBA c = void;
		assert(a_c + b_c == div, format("%d+%d != %d", a_c, b_c, div));
		for (int n = 0; n < 4; n++) {
			c.vv[n] = ((a.vv[n] * a_c) + (b.vv[n] * b_c)) / div;
		}
		return c;
	}
	
	static RGBA opCall(int r, int g, int b, int a = 0) {
		RGBA c = void;
		c.r = r;
		c.g = g;
		c.b = b;
		c.a = a;
		return c;
	}
	
	char[] toString() { return format("#%02X%02X%02X%02X", r, g, b, a); }
};
static assert (RGBA.sizeof == 4);

class Image {
	RGBA[] data;
	int w, h;
	this(int w, int h, RGBA[] data = null) {
		this.data = (data is null) ? (new RGBA[w * h]) : data;
		this.w = w;
		this.h = h;
	}
	
	void put(int x, int y, RGBA c) {
		if (x <  0 || y <  0) return;
		if (x >= w || y >= h) return;
		data[y * w + x] = c;
	}
	
	void putImage(int x, int y, Image i) {
		for (int yy = 0, nn = 0; yy < i.h; yy++) {
			for (int xx = 0; xx < i.w; xx++, nn++) {
				put(x + xx, y + yy, i.data[nn]);
			}
		}
	}

	static align(1) struct TGA_Header {
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

	static assert(TGA_Header.sizeof == 18, "Invalid size for TGA.Header");
	
	void saveTGA(char[] name) {
		scope s = new File(name, FileMode.OutNew);
		saveTGA(s);
	}

	void saveTGA(Stream s) {
		TGA_Header header;

		// Defines the header.
		with (header) {
			idlength        = 0;
			x_origin        = 0;
			y_origin        = 0;
			width           = w;
			height          = h;
			colourmaporigin = 0;
			imagedescriptor = 0b_00_1_0_1000;

			colourmaptype   = 0;
			datatypecode    = 2;
			colourmaplength = 0;
			colourmapdepth  = 0;
			bitsperpixel    = 32;
		}

		// Writes the header.
		s.writeExact(&header, header.sizeof);
		// Then writes the data.
		s.write(cast(ubyte[])data);

	}
}

struct BitExtract {
	ulong v; int n;

	bool more() { return has(1); }
	bool has(int m) { return (n >= m); }
	void clear() { v = 0; n = 0; }

	void insert(ubyte[] vv) {
		//for (int n = vv.length - 1; n >= 0; n--) insert(vv[n], 8);
		foreach (v; vv) insert(v, 8);
	}
	void insert(ulong vv, int count) {
		v <<= count;
		v |= vv & mask(count);
		n += count;
	}
	ulong extract(int count) {
		scope (exit) { n -= count; v >>= count; }
		return v & mask(count);
	}
	
	char[] toString() {
		char[] r;
		for (int m = 0; m < n; m++) r ~= ((v >> m) & 1) ? '1' : '0'; 
		return r;
	}
}

align(1) struct DXT5 { // 4x4 pixels
	ubyte  a [2]; // 1 byte alpha
	ubyte  at[6]; // 3 bits per component
	ushort c [2]; // 565 RGB color
	ubyte  ct[4]; // 2 bits per component
	
	void decode(RGBA[16] o) {
		ubyte av[8] = void;
		RGBA  cv[4] = void;
		BitExtract be;
		RGBA[16] t;

		// Alpha table.
		if (a[0] > a[1]) {
			av[0] = a[0];
			av[1] = a[1];
			for (int n = 0; n < 6; n++) av[n + 2] = ((6 - n) * a[0] + (n + 1) * a[1]) / 7;
		} else {
			av[0] = a[0];
			av[1] = a[1];
			av[6] = 0;
			av[7] = 255;
			for (int n = 0; n < 4; n++) av[n + 2] = ((4 - n) * a[0] + (n + 1) * a[1]) / 5;
		}
		// Color table.
		cv[0].decode565(c[0]);
		cv[1].decode565(c[1]);
		if (c[0] > c[1]) {
			cv[2] = RGBA.mix(cv[0], cv[1], 3, 2, 1);
			cv[3] = RGBA.mix(cv[0], cv[1], 3, 1, 2);
		} else {
			cv[2] = RGBA.mix(cv[0], cv[1], 2, 1, 1);
			cv[3] = RGBA(0, 0, 0, 0);
		}
		//writefln(cv);

		be.clear(); be.insert(ct);
		for (int n = 0; n < 16; n++) {
			int cc = be.extract(2);
			//writefln(cc);
			t[n] = cv[cc];
		}

		be.clear(); be.insert(at);
		for (int n = 0; n < 16; n++) {
			int cc = be.extract(3);
			t[n].a = av[cc];
		}
		for (int n = 0; n < 4; n++) {
			o[n * 4 + 0..n * 4 + 4] = t[(3 - n) * 4 + 0..(3 - n) * 4 + 4];
		}
	}

	void encode(RGBA[16] i) { assert(0, "Not implemented"); }
}
static assert (DXT5.sizeof == 0x10);

void main() {
	RGBA[16] block;
	auto data = std.file.read("test.dds");
	auto dxt5 = cast(DXT5 *)(data.ptr + 0x80);
	auto i = new Image(250, 256);
	auto b = new Image(4, 4, block);
	try {
		for (int y = 0; y < 281 / 4; y++) {
			for (int x = 0; x < 252 / 4; x++, dxt5++) {
				dxt5.decode(block);
				i.putImage(x * 4, y * 4, b);
			}
		}
	} catch (Exception e) {
	}
	writefln(block);
	i.saveTGA("test.tga");
}