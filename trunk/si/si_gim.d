module si_gim;

import si;

import std.stream;
import std.stdio;
import std.intrinsic;
import std.path;
import std.file;
import std.process;
import std.system;

align(1) struct GIM_IHeader {
	uint _u1;
	ushort type; ushort _u2;
	ushort width, height;
	ushort bpp;
	ushort xbs, ybs;

	ushort[0x17] _u5;
	
	static GIM_IHeader read(Stream s, Endian endian = Endian.LittleEndian) {
		GIM_IHeader header;
		s.read(TA(header));
		
		cendian(header._u1, endian);
		cendian(header.type, endian);
		cendian(header._u2, endian);
		cendian(header.width, endian);
		cendian(header.height, endian);
		cendian(header.bpp, endian);
		cendian(header.xbs, endian);
		cendian(header.ybs, endian);
		for (int n = 0; n < _u5.length; n++) cendian(header._u5[n], endian);
		
		foreach (v; header._u5) {
			//writefln("v:%d", v);
		}
		
		return header;
	}
}

class GIM_Image : Image {
	Stream dstream;
	GIM_IHeader header;
	GIM_Image clut;
	uint[] data;
	Endian endian;

	ubyte bpp() { return header.bpp; }
	int width() { return header.width; }
	int height() { return header.height; }

	int ncolor() {
		if (clut is null) return 0;
		return clut.header.width * clut.header.height;
	}

	RGBA color(int idx) {
		RGBA c;

		if (clut is null) {
			c.r = c.g = c.b = c.a = (idx * 255) / (1 << header.bpp);
		} else {
			c.v = clut.get(idx, 0);
		}

		return c;
	}

	RGBA color(int idx, RGBA c) {
		if (clut !is null) clut.set(idx, 0, c.v);
		return c;
	}

	void readHeader(Stream s, Endian endian = Endian.LittleEndian) {
		header = GIM_IHeader.read(s, endian);
		data = new uint[header.width * header.height];
	}

	bool check(int x, int y) {
		return (x >= 0 && y >= 0 && x < header.width && y < header.height);
	}

	void set(int x, int y, uint v) {
		if (!check(x, y)) return;
		data[y * header.width + x] = v;
	}

	uint get(int x, int y) {
		if (!check(x, y)) return 0;
		return data[y * header.width + x];
	}

	override void set32(int x, int y, RGBA c) {
		//printf("%02X%02X%02X%02X:", c.r, c.g, c.b, c.a);
		if (bpp == 16) { set(x, y, c.v); return; }
		Image.set32(x, y, c);
	}

	void transferBlock(int sx, int sy, void[] data, bool read) {
		//writefln("%d, %d", sx, sy);
		switch (header.bpp) {
			case 32: {
				uint[] d4 = cast(uint[])data;
				for (int y = 0, n = 0; y < header.ybs; y++) for (int x = 0; x < header.xbs; x++, n++) {
					if (read) d4[n] = get(sx + x, sy + y);
					else set(sx + x, sy + y, d4[n]);
				}
			} break;
			case 16: {
				ushort[] d2 = cast(ushort[])data;
				for (int y = 0, n = 0; y < header.ybs; y++) for (int x = 0; x < header.xbs; x++, n++) {
					if (read) d2[n] = get32(sx + x, sy + y).decode(RGBA_5650);
					else set32(sx + x, sy + y, RGBA(RGBA_5650, d2[n]));
				}
			} break;
			case 8: {
				ubyte[] d1 = cast(ubyte[])data;
				for (int y = 0, n = 0; y < header.ybs; y++) for (int x = 0; x < header.xbs; x++, n++) {
					if (read) d1[n] = get(sx + x, sy + y);
					else set(sx + x, sy + y, d1[n]);
				}
			} break;
			case 4: {
				ubyte[] d1 = cast(ubyte[])data;
				for (int y = 0, n = 0; y < header.ybs; y++) for (int x = 0; x < header.xbs; x += 2, n++) {
					if (read) {
						d1[n] = ((get(sx + x + 0, sy + y)) & 0xF) | (((get(sx + x + 1, sy + y)) & 0xF) << 4);
					} else {
						set(sx + x + 0, sy + y, (d1[n] >> 0) & 0xF);
						set(sx + x + 1, sy + y, (d1[n] >> 4) & 0xF);
					}
				}
			} break;
			default: {
				throw(new Exception(std.string.format("Unprocessed BPP (%d)", header.bpp)));
			} break;
		}
	}

	void read() {
		ubyte[] block;
		block.length = header.xbs * header.ybs * header.bpp / 8;

		dstream.position = 0;

		for (int y = 0; y < header.height; y += header.ybs) for (int x = 0; x < header.width; x += header.xbs) {
			//for (int n = 0; n < block.length; n++) block[n] = 0;
			dstream.read(block);
			transferBlock(x, y, block, false);
		}
	}

	void write() {
		ubyte[] block;
		block.length = header.xbs * header.ybs * header.bpp / 8;

		dstream.position = 0;

		for (int y = 0; y < header.height; y += header.ybs) for (int x = 0; x < header.width; x += header.xbs) {
			//for (int n = 0; n < block.length; n++) block[n] = 0;
			transferBlock(x, y, block, true);
			dstream.write(block);
		}

		if (clut) clut.write();
	}
}

class ImageFileFormat_GIM : ImageFileFormat {
	override char[] identifier() { return "gim"; }

	char[] header_le = "MIG.00.1PSP\0\0\0\0\0";
	char[] header_be = ".GIM1.00\0PSP\0\0\0\0";
	Endian endian;

	Image[] imgs;

	void processStream(Stream s, int level = 0) {
		ushort unk0, type;
		uint len, unk1, unk2;
		Stream cs;

		debug(gim_stream) { char[] pad; for (int n = 0; n < level; n++) pad ~= " "; }

		GIM_Image img, clut;

		while (!s.eof) {
			int start = s.position;

			s.read(type);
			s.read(unk0);
			s.read(len);
			s.read(unk1);
			s.read(unk2);
			
			cendian(type, endian);
			cendian(len, endian);
			cendian(unk1, endian);
			cendian(unk2, endian);

			cs = new SliceStream(s, start + 0x10, start + len);

			debug(gim_stream) writefln(pad ~ "type: %04X (%04X)", type, len);

			switch (type) {
				case 0x02: // GimContainer
					processStream(cs, level + 1);
				break;
				case 0x03: // Image
					processStream(cs, level + 1);
				break;
				case 0x04: // ImagePixels
				case 0x05: // ImagePalette
				{
					// 0x40 bytes header
					GIM_Image i = new GIM_Image;
					i.readHeader(cs, endian);

					//writefln("POS: %08X", cs.position);

					//i.header.bpp = 8;

					debug(gim_stream) writefln(pad ~ " [%d] [%2d] (%dx%d) (%dx%d)", i.header.type, i.header.bpp, i.header.width, i.header.height, i.header.xbs, i.header.ybs);

					//i.header.xbs = (1 << (i.header.type - 1));
					switch (i.header.type) {
						case 0x00: i.header.xbs =  8; break;
						case 0x03: i.header.xbs =  4; break;
						case 0x05: i.header.xbs = 16; break;
						case 0x04: i.header.xbs = 32; break;
						default: throw(new Exception(std.string.format("Unknown image type (%d)", i.header.type)));
					}

					//i.header.xbs = 256 / (i.header.ybs * i.header.bpp / 8);
					//writefln(i.header.xbs);

					i.dstream = new SliceStream(cs, GIM_IHeader.sizeof, len);

					i.read();

					if (type == 0x04) img = i; else clut = i;
				} break;
				case 0xFF: // Comments
					writefln(cs.size);
				break;
				default:
				//throw(new Exception(std.string.format("Invalid GIM unknown chunk type:%04X", type)));
			}

			s.position = start + len;
		}

		if (img && clut) img.clut = clut;
		//writefln("%08X, %08X", cast(void *)img, cast(void *)clut);

		if (img) imgs ~= img;
	}

	Image[] readMultiple(Stream s) {
		if (!check(s)) throw(new Exception("Not a GIM file"));

		imgs.length = 0;
		processStream(s);

		return imgs;
	}

	override Image read(Stream s) {
		Image[] imgs = readMultiple(s);
		if (!imgs.length) throw(new Exception("Not found images in GIM file"));
		return imgs[0];
	}

	override bool write(Image i, Stream s) {
		GIM_Image ri = cast(GIM_Image)read(s);
		//writefln("%08X", i.get32(0, 0).v);
		ri.copyFrom(i);
		ri.write();
		return true;
	}

	override int check(Stream s) {
		auto cheader = s.readString(0x10);
		if (cheader == header_be) { endian = Endian.BigEndian   ; return 10; }
		if (cheader == header_le) { endian = Endian.LittleEndian; return 10; }
		return 0;
	}
}

static this() {
	ImageFileFormatProvider.registerFormat(new ImageFileFormat_GIM);
}