module cso;

import std.stream, std.stdio, std.string, std.file, std.path;
import etc.c.zlib;

template TA(T) { ubyte[] TA(inout T t) { return (cast(ubyte *)&t)[0..T.sizeof]; } }

class CSOStream : Stream {
	struct Header {
		ubyte magic[4];    // +00 : 'C','I','S','O'
		uint  header_size; // +04 : header size (==0x18)
		ulong total_bytes; // +08 : number of original data size
		uint  block_size;  // +10 : number of compressed block size
		ubyte ver;         // +14 : version 01
		ubyte _align;      // +15 : align of index value
		ubyte rsv_06[2];   // +16 : reserved
	}
	
	Header h;
	uint[] blockData;
	uint bufferBlock;
	ubyte[] buffer;
	Stream s;
	z_stream z;
	long position = 0;
	
	int blocks() { return blockData.length - 1; }
	
	this(Stream s) {
		this.s = s;
		
		s.read(TA(h));
		
		if (h.magic != cast(ubyte[])"CISO") throw(new Exception("Not a CSO file"));
		if (h.ver != 1) throw(new Exception("Not a CSO ver1"));
		//if (h.header_size != h.sizeof) throw(new Exception(std.string.format("Invalid header size %d!=%d", h.header_size, h.sizeof)));
		
		blockData.length = h.total_bytes / h.block_size + 1;
		s.readExact(blockData.ptr, 4 * blockData.length);
		
		buffer.length = h.block_size;
		
		seekable = true;
		writeable = false;
		readable = true;
	}
	
	void readSector(uint sector) {
		if (bufferBlock == sector) return;

		if (sector >= blockData.length - 1) throw(new Exception("Invalid CSO sector"));
		
		bufferBlock = sector;
		
		bool getCompressed(uint sector) { return (blockData[sector] & (1 << 31)) == 0; }
		uint getPosition(uint sector) { return blockData[sector] & ~(1 << 31); }
		
		uint start = getPosition(sector);
		uint len = getPosition(sector + 1) - start;
		bool compressed = getCompressed(sector);
		
		s.position = start;
		
		if (!compressed) {
			s.readExact(buffer.ptr, len);
			return;
		}
		
		ubyte[] data = cast(ubyte[])s.readString(len);
		if (data.length != len) throw(new Exception(std.string.format("block=%d : read error", sector)));
	
		if (inflateInit2(&z, -15) != Z_OK) throw(new Exception(std.string.format("defalteInit : %s", z.msg)));
		try {
			z.next_out  = buffer.ptr;
			z.avail_out = buffer.length;
			z.next_in   = data.ptr;
			z.avail_in  = data.length;
			int status  = inflate(&z, Z_FULL_FLUSH);
			if (status != Z_STREAM_END) throw(new Exception(std.string.format("block %d:inflate : %s[%d]\n", sector, z.msg, status)));
		} finally {
			inflateEnd(&z);
		}
	}
	
	override uint readBlock(void* _data, uint size) {
		ubyte *data = cast(ubyte*)_data;
		uint _size = size;
		while (true) {
			uint sec = position / h.block_size;
			uint pos = position % h.block_size;
			uint rem = h.block_size - pos;
			
			readSector(sec);
			
			if (size > rem) {
				data[0..rem] = buffer[pos..pos + rem];
				data += rem;
				size -= rem;
				position += rem;
			} else {
				data[0..size] = buffer[pos..pos + size];
				data += size;
				position += size;
				size = 0;
				break;
			}
		}
		
		return _size;
	}

	override uint writeBlock(void* buffer, uint size) { throw(new Exception("Not implemented")); }
	
	override ulong seek(long offset, SeekPos whence) {
		switch (whence) {
			default:
			case SeekPos.Set:     return position = offset;
			case SeekPos.End:     return position = h.total_bytes + offset;
			case SeekPos.Current: return position += offset;
		}
	}
	
	static void create(Stream sin, Stream sout, int level = 9) {
		sin.position = 0;
		Header h;
		h.magic[0..4] = cast(ubyte[])"CISO";
		h.header_size = 0;
		h.total_bytes = sin.size;
		//h.block_size  = 0x8000;
		h.block_size  = 0x800;
		h.ver = 1;
		sout.write(TA(h));
		
		uint[] plist = new uint[sin.size / h.block_size + 1];
		sout.write(cast(ubyte[])plist);
		
		ubyte[] buf = new ubyte[h.block_size];
		ubyte[] buf2 = new ubyte[h.block_size * 2];

		z_stream z;

		// init zlib
		z.zalloc = null;
		z.zfree  = null;
		z.opaque = null;
		
		long n = 0;
		for (; n < plist.length - 1; n++) {
			int readed = sin.read(buf);
			assert (readed == buf.length);

			plist[n] = sout.position;
			
			if (deflateInit2(&z, level, Z_DEFLATED, -15, 8, Z_DEFAULT_STRATEGY) != Z_OK) throw(new Exception("Error deflateInit"));
			
			// read buffer
			z.next_out  = buf2.ptr;
			z.avail_out = buf2.length;
			z.next_in   = buf.ptr;
			z.avail_in  = buf.length;
			
			if (deflate(&z, Z_FINISH) != Z_STREAM_END) throw(new Exception("Error deflate"));
			
			int cmp_size = buf2.length - z.avail_out;
			
			if (cmp_size >= h.block_size) {
				plist[n] |= 0x80000000;
				sout.write(buf);
			} else {
				sout.write(buf2[0..cmp_size]);
			}
			
			deflateEnd(&z);
		}
		
		plist[n] = sout.position;
		
		sout.position = h.sizeof;
		sout.write(cast(ubyte[])plist);
	}
}

/*
void main() {
	auto sin  = new BufferedFile("test.iso");
	auto sout = new File("test.cso", FileMode.OutNew);
	CSOStream.create(sin, sout, 9);
	sout.close();
	sin.close();
}
*/
