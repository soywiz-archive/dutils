import sfs;

import std.string, std.stdio, std.stream, std.path, std.file;
import std.zlib;

version (no_lzma) { } else {
	import lzma;
}

align(1) struct BaseHeader {
	char[2] PK = "PK";
	ushort kind;
}

align(1) struct LocalFileHeader {
	ushort _version;
	ushort flags;
	ushort method;
	ushort file_time;
	ushort file_date;
	uint   crc32;
	uint   compressed_size;
	uint   uncompressed_size;
	ushort name_length;
	ushort extra_length;
}

align(1) struct CentralDirectoryHeader {
	ushort _version_made;
	ushort _version_extract;
	ushort flags;
	ushort method;
	ushort file_time;
	ushort file_date;
	uint   crc32;
	uint   compressed_size;
	uint   uncompressed_size;
	ushort name_length;
	ushort extra_length;
	ushort comment_length;
	ushort disk_number_start;
	ushort attr_internal;
	uint   attr_external;
	uint   offset_relative;
}

align(1) struct EndCentralDirectoryRecord {
	ushort disk_number;
	ushort disk_number2;
	ushort nentries_disk;
	ushort nentries;
	uint   cd_size;
	uint   offset_;
	ushort comment_length;
}

class ZipEntry : FS_Entry {
	LocalFileHeader lfh;
	Stream slice;
	char[] extra;
	ZipEntry[char[]] _childs;
	ubyte[] uncomp_data;
	Stream uncomp_stream;
	FS_Entry[] childs() { return cast(FS_Entry[])_childs.values; }
	
	ZipEntry open_create_entry(char[] name) {
		if (name in _childs) return _childs[name];
		auto ze = new ZipEntry;
		ze.name = name;
		ze.parent = this;
		_childs[name] = ze;
		return ze;
	}

	ZipEntry create_path(char[] path) {
		int pos = find(path, "/");
		if (pos == path.length - 1) { pos = -1; path = path[0..path.length - 1]; }
		if (pos == -1) return open_create_entry(path);
		return create_path(path[0..pos]).create_path(path[pos+1..path.length]);
	}
	
	override Stream open(FileMode mode = FileMode.In, bool grow = false) {
		if (!uncomp_stream) {
			ubyte[] comp_data = new ubyte[slice.size]; scope (exit) delete comp_data;
			slice.position = 0; slice.read(comp_data);
			bool set = true;
			
			if (lfh.flags & (1 << 0)) throw(new Exception("Not supported encrypted files"));
			
			switch (lfh.method) {
				case 0x0: // NONE
					uncomp_data = comp_data.dup;
				break;
				case 0x8: // DEFLATE
					uncomp_data = cast(ubyte[])std.zlib.uncompress(cast(void[])comp_data, lfh.uncompressed_size, -15);
				break;
				version (no_lzma) { } else {
					case 0xE: // LZMA
						bool has_eos    = (lfh.flags & (1 << 1)) != 0;
						bool strong_enc = (lfh.flags & (1 << 6)) != 0;
						bool efs_utf8   = (lfh.flags & (1 << 11)) != 0;
						
						if (has_eos) throw(new Exception("Not supported EOS for LZMA"));
						if (strong_enc) throw(new Exception("Not supported Strong Encode for LZMA"));
						
						uncomp_data = lzma.decode(comp_data[4..comp_data.length], lfh.uncompressed_size);
					break;
				}
				default: set = false; break;
			}
			if (set) uncomp_stream = new MemoryStream(uncomp_data);
		}
		if (uncomp_stream) return uncomp_stream;
		throw(new Exception(std.string.format("Unknown method 0x%04X for file '%s'", lfh.method, path)));
	}
}

class ZipArchive : ZipEntry {
	Stream s;
	
	this(char[] name) {
		this(new BufferedFile(name));
	}
	
	this(Stream s) {
		this.s = s;
		process();
	}
	
	void process() {
		Stream s = new SliceStream(this.s, 0);
		while (!s.eof) {
			BaseHeader bh;
			s.read(TA(bh));
			assert (bh.PK == BaseHeader.init.PK);
			switch (bh.kind) {
				case 0x0605: { // End of Central Directory record
					EndCentralDirectoryRecord h;
					s.read(TA(h));
					s.seekCur(h.comment_length);
				} break;
				case 0x0403: { // Local File record
					LocalFileHeader h;
					s.read(TA(h));
					char[] name = s.readString(h.name_length);
					char[] extra = s.readString(h.extra_length);
					Stream slice = new SliceStream(s, s.position, s.position + h.compressed_size);
					s.seekCur(h.compressed_size);
					
					auto ze = create_path(name);
					ze.extra = extra;
					ze.slice = slice;
					ze.lfh = h;
					
					if (h.flags & (1 << 3)) s.seekCur(12);
				} break;
				case 0x0201: { // Central Directory record
					CentralDirectoryHeader h;
					s.read(TA(h));
					s.seekCur(h.name_length);
					s.seekCur(h.extra_length);
					s.seekCur(h.comment_length);
				} break;
				default: throw(new Exception(format("Unknown kind 0x%04X", bh.kind)));
			}
		}
	}
}

/*
void main() {
	auto zip = new ZipArchive("lzma.zip");
	//auto zip = new ZipArchive("deflate.zip");
	writefln(zip["test/prueba.txt"].read());
}
*/