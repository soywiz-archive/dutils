module si_psd;

import si;
import std.string, std.stream, std.system;

struct Rect { int x, y, w, h; long area() { return w * h; } char[] toString() { return std.string.format("(%d,%d)-(%d,%d)", x, y, w, h); } }

class PSDReader : FilterStream {
	this(Stream s, bool big_endian = true) {
		if (big_endian) s = new EndianStream(s, Endian.BigEndian);
		super(s);
	}
	this(ubyte[] data) { this(new MemoryStream(data)); }
	
	alias source s;

	ubyte  readu1()    { ubyte  v; s.read(v); return v; }
	byte   reads1()    { byte   v; s.read(v); return v; }
	ushort readu2()    { ushort v; s.read(v); return v; }
	short  reads2()    { short  v; s.read(v); return v; }
	uint   readu4()    { uint   v; s.read(v); return v; }
	int    reads4()    { int    v; s.read(v); return v; }
	char[] reads ()    { return s.readString(readu2); }
	Rect   read_rect() { Rect r = void; r.y = reads4; r.x = reads4; r.h = reads4 - r.y; r.w = reads4 - r.x; return r; }
	void   readpad(int pad = 2) { while (s.position % pad) readu1; }
	ubyte[] readb(int l){ return cast(ubyte[])s.readString(l); }
	
	alias readu1 u1; alias reads1 s1;
	alias readu2 u2; alias reads2 s2;
	alias readu4 u4; alias reads4 s4;
	alias reads ss;
	alias read_rect rect;
	alias readString str;
	alias readb array;
	alias readpad pad;
	alias seekCur skip;
}

class SlicePSDReader : PSDReader {
	this(PSDReader s, long start, long length = 0) {
		super(new SliceStream(s.s, start, start + length), true);
	}
}

// http://www.pcpix.com/Photoshop/char.htm
// http://www.soft-gems.net:8080/browse/~raw,r=99/Library/GraphicEx/Source/GraphicEx.pas
// http://www.codeproject.com/KB/graphics/simplepsd.aspx
// http://www.codeproject.com/KB/graphics/PSDParser.aspx
class ImageFileFormat_PSD : ImageFileFormat {
	override char[] identifier() { return "psd"; }
	override int check(Stream s) { return (s.readString(4) == "8BPS") ? 10 : 0; }	

	enum ColorModes : ushort { Bitmap = 0, Grayscale = 1, Indexed = 2, RGB = 3, CMYK = 4, Multichannel = 7, Duotone = 8, Lab = 9 }
	enum Compression { None = 0, RLE, ZipNoPrediction, ZipPrediction, Jpeg }	

	override bool write(Image i, Stream s) {
		return false;
	}
	
	class Header {
		ushort ver;
		ushort channels, bpp;
		ushort width, height;
		
		this(PSDReader s) { read(s); }

		void read(PSDReader s) {
			assert(s.str(4) == "8BPS", "Not a PSD file");
			
			// Version
			ver = s.u2; assert(ver == 1, "Not a ver1 PSD");
			// ??
			s.str(6);
			// Channels
			channels = s.u2;
			// Height
			height = s.u4; assert(height < 16384);
			// Width
			width = s.u4; assert(width < 16384);
			// Bits per pixel
			bpp = s.u2;
			ColorModes cm = cast(ColorModes)s.u2;
		}
	}
	
	class Palette {
		RGBA[] colors;

		this(PSDReader s) { read(s); }
		
		void read(PSDReader s) {
			colors.length = s.u4;
			for (int n = 0; n < colors.length; n++) {
				colors[n] = RGBA(s.u1, s.u1, s.u1);
				//writefln(colors[n]);
			}		
		}
	}
	
	class Layer {
		int layer_id;
		Rect size;
		ushort num_channels;
		short usage;
		uint length;
		char[] blend;
		ubyte opacity, clipping, flags;
		uint extra_size;
		Image i;
		Mask mask;
		bool is_merged;
		
		this() { }
		
		this(int layer_id, PSDReader s) {
			this.layer_id = layer_id;
			read(s);
		}
		
		class Mask {
			Rect size, rect2;
			ubyte color;
			ubyte flags;
			ubyte flags2;
			ubyte maskbg;
			
			this(PSDReader s) { read(s); }
			
			void read(PSDReader s) {
				int nlength = s.u4; if (!nlength) return;
				
				int pos = s.position;
				
				size = s.rect;
				color = s.u1;
				flags = s.u1;
				
				if (nlength == 20) {
					s.u2;
				} else if (nlength == 36) {
					flags2 = s.u1; //same flags as above according to docs!?!?
					maskbg = s.u1; //Real user mask background. Only 0 or 255 - ie bool?!?
					rect2  = s.rect; //new Rectangle(reader).ToERectangle(); //same as above rectangle according to docs?!?!
				}
				
				s.position = pos + nlength;
			}
		}
		
		class Channel {
			short usage;
			uint length;
		
			this(PSDReader s) { read(s); }
			
			void read(PSDReader s) {
				usage = s.s2;
				length = s.u4;			
			}
		}
		
		Channel[short] channels;
	
		void read(PSDReader s) {
			size = s.rect;
			
			//writefln("layer:%d (%s)", layer_id, size);
			
			num_channels = s.u2;
			for (int n = 0; n < num_channels; n++) {
				auto ch = new Channel(s);
				if (ch.usage == -2) continue;
				channels[ch.usage] = ch;
			}

			//writefln(": %d (%s)", nchan, size);

			char[] magic = s.str(4); assert(magic == "8BIM", "Invalid image layer header");
			blend = s.str(4); // 'levl'=Levels 'curv'=Curves 'brit'=Brightness/contrast 'blnc'=Color balance 'hue '=Old Hue/saturation, Photoshop 4.0 'hue2'=New Hue/saturation, Photoshop 5.0 'selc'=Selective color 'thrs'=Threshold 'nvrt'=Invert 'post'=Posterize
			
            opacity = s.u1;
			clipping = s.u1;
			flags = s.u1;
			s.u1;
			
			auto ss = new PSDReader(s.array(extra_size = s.u4));
			
			mask = new Mask(ss);
		}
		
		int decodeRLE(PSDReader s, ubyte[] data, int pos) {
			int len = s.u1;
			int count = 0;
			
			if (len == 128) return 0;

			if (len < 128) {
				len++;
				count += len;

				for (;len > 0; len--) data[pos++] = s.u1;
			} else {
				len = cast(ubyte)(len ^ 0xFF) + 2;
				count += len;
				
				for (ubyte v = s.u1; len > 0; len--) data[pos++] = v;
			}
			
			return count;
		}
		
		ubyte[] readPixelsChannel(PSDReader s, Compression compression) {
            int Bpc = header.bpp / 8;
            int bytesPerRow = size.w * Bpc;

            ubyte[] r = new ubyte[bytesPerRow * size.h];

            switch (compression) {
                case Compression.None:
					s.read(r);
				break;
                case Compression.RLE:
                    for (int i = 0; i < size.h; i++) {
                        int offset = i * bytesPerRow;
                        int numChunks = 0;
						int numDecodedBytes = 0;
                        while (numDecodedBytes < bytesPerRow) {
							numDecodedBytes += decodeRLE(s, r, offset + numDecodedBytes);
							numChunks++;
                        }
                    }
				break;
                case Compression.ZipNoPrediction: throw (new Exception("ZIP without prediction, no specification"));
                case Compression.ZipPrediction: throw (new Exception("ZIP with prediction, no specification"));
                default: throw (new Exception(format("Compression not defined: %d", compression)));
            }
			
			//writefln("bpp: %d", r);

			return r;
		}
		
		class PixelData {
			ubyte[][] channels;
			
			this(PSDReader s, int num_channels = 1, bool is_merged = false) {
				channels.length = num_channels;
				read(s);
			}
			
			void read(PSDReader s) {
				Compression compression;
				
				//writefln("is_merged:%d", is_merged);
				
				if (is_merged) {
					compression = cast(Compression)s.u2;
					for (int n = 0; n < channels.length; n++) s.skip(size.h * 2);
				}
			
				for (int n = 0; n < channels.length; n++) {
					//writefln("layer:%d channel:%d/%d", layer_id, n, channels.length);
					
					//(new File(format("layer_%d_channel_%d.data", layer_id, n), FileMode.OutNew)).copyFrom(new SliceStream(s, s.position));
					if (!is_merged) {
						compression = cast(Compression)s.u2;
						s.skip(size.h * 2);
					}
					channels[n] = readPixelsChannel(s, compression);
				}
			}
			
			void store(Bitmap32 i) {
				assert (channels.length >= 4, format("channels.length(%d) < 4", channels.length));
				int l = i.data.length; alias channels c;
				ubyte[] r, g, b, a;
				if (is_merged) {
					a = c[3]; r = c[0]; g = c[1]; b = c[2];
				} else {
					a = c[0]; r = c[1]; g = c[2]; b = c[3];
				}
				for (int n = 0; n < l; n++) i.data[n] = RGBA(r[n], g[n], b[n], a[n]);
			}
		}

		void readPixels(PSDReader s) {
			//Compression compression = cast(Compression)s.u2; assert (compression == Compression.Rle, "Unprocessed compression");
			
			//(new File(format("layer_%d.data", layer_id), FileMode.OutNew)).copyFrom(new SliceStream(s, s.position));
			
			i = new Bitmap32(size.w, size.h);
			
			auto pd = new PixelData(s, num_channels, is_merged); pd.store(cast(Bitmap32)i);
			//writefln("aaaaa");
			
			foreach (ch; channels) {
                if (ch.usage == -2) continue;
				//ch.Data = px.GetChannelData(i++);
            }

			//writefln("area:", mask.size.area);
			if (mask && mask.size.area) {
				auto pd2 = new PixelData(s, 1);
			}

			//foreach (n, c; i.data) i.data[n] = RGBA.toBGRA(c);
			
			//writefln("out");
			//i.write("out2.png");
		}
	}
	
	Header header;
	Palette pal;
	Layer[] layers;
	
	class Resource {
		ushort id;
		char[] name;
		ubyte[] data;
	
		this(PSDReader s) { read(s); }
		
		void read(PSDReader s) {
			char[] magic = s.readString(4);
			
			assert(magic == "8BIM", "Invalid Resource");
			
			id = s.u2;
			name = s.ss;
			ubyte[] data;
			data.length = s.u4;
			s.read(data);
		}
	}
	
	void ReadResources(PSDReader ss) {
		int res_length = ss.u4;
		auto s = new SlicePSDReader(ss, ss.position, res_length); ss.skip(res_length);
		
		while (!s.eof) {
			new Resource(s);
			s.pad(2);
		}
	}
	
	void ReadLayers1(PSDReader ss) {
		uint size = ss.u4;
		//writefln("size:%d", size);
		
		auto s = new SlicePSDReader(ss, ss.position, size); ss.skip(size);

		if (false)
		{
			int num_layers = s.s2;
			bool skip_first_alpha = true;
			
			if (num_layers < 0) {
				skip_first_alpha = false;
				num_layers = -num_layers;
			}
			
			layers.length = num_layers;
			
			for (int n = 0; n < layers.length; n++) layers[n] = new Layer(n, s);
			for (int n = 0; n < layers.length; n++) layers[n].readPixels(s);
		}
	}
	
	void ReadLayers(PSDReader ss) {
		uint total_layers_size = ss.u4;
		//writefln("total_layers_size:%d", total_layers_size);
		
		auto s = new SlicePSDReader(ss, ss.position, total_layers_size); ss.skip(total_layers_size);
		
		ReadLayers1(s);

		// Mask
		int mask_length = s.u4;
		s.skip(mask_length);
		//writefln(mask_length);
		
		//writefln(s.position);
		
		//(new File(format("out3.bin"), FileMode.OutNew)).copyFrom(new SliceStream(s, s.position));
	}
	
	override Image read(Stream _s) {
		auto s = new PSDReader(_s);
		
		header = new Header(s);
		pal = new Palette(s);
		ReadResources(s);
		ReadLayers(s);
		
		//writefln(s.position);
		
		Layer l = new Layer();
		l.is_merged = true;
		l.size = Rect(0, 0, header.width, header.height);
		l.num_channels = header.channels;
		l.readPixels(s);
		
		return l.i;
	}
}

static this() {
	ImageFileFormatProvider.registerFormat(new ImageFileFormat_PSD);
}