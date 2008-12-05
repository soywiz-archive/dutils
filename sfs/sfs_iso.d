module sfs_iso;
import sfs;

import std.stream, std.stdio, std.string, std.file, std.path, std.date, std.intrinsic, std.traits, std.utf;
import etc.c.zlib;

template TA(T) { ubyte[] TA(inout T t) { return (cast(ubyte *)&t)[0..T.sizeof]; } }
template TA2(T) { ubyte[] TA2(T t) { return cast(ubyte[])(t[0..T.length]); } }

// Types
// Signed
alias byte  s8;
alias short s16;
alias int   s32;
alias long  s64;
// Unsigned
alias ubyte  u8;
alias ushort u16;
alias uint   u32;
alias ulong  u64;
// Both Byte Order Types
align(1) struct u16b { u16 l, b; void opAssign(u16 v) { l = v; b = bswap(v) >> 16; } alias l v; }
align(1) struct u32b { u32 l, b; void opAssign(u32 v) { l = v; b = bswap(v); } alias l v; }

static void s_pad_write(u8[] v, char[] text) {
	int len = (text.length > v.length) ? v.length : text.length;
	v[0..len] = cast(ubyte[])text[0..len];
	for (int n = len; n < v.length; n++) v[n] = 0x20;
}

template pad_string(int t) {
	align(1) struct pad_string {
		u8[t] s;
		void opAssign(char[] ss) { s_pad_write(s[0..s.length], ss); }
		char[] toString() { return std.string.format("%s", s); }
	}
}

// XA (eXtended Attributes) - http://www.gnu.org/software/libcdio/doxygen/xa_8h.html
align(1) struct ISO9660_XA {
	enum Attr : u16 {
		XA_PERM_RSYS         = 0x0001,
		XA_PERM_XSYS         = 0x0004,
		XA_PERM_RUSR         = 0x0010,
		XA_PERM_XUSR         = 0x0040,
		XA_PERM_RGRP         = 0x0100,
		XA_PERM_XGRP         = 0x0400,	
		XA_PERM_ROTH         = 0x1000,
		XA_PERM_XOTH         = 0x4000,

		XA_PERM_ALL_READ     = (XA_PERM_RUSR | XA_PERM_RSYS | XA_PERM_RGRP),
		XA_PERM_ALL_EXEC     = (XA_PERM_XUSR | XA_PERM_XSYS | XA_PERM_XGRP),
		XA_PERM_ALL_ALL      = (XA_PERM_ALL_READ | XA_PERM_ALL_EXEC),

		XA_ATTR_MODE2FORM1   = (1 << 11),
		XA_ATTR_MODE2FORM2   = (1 << 12),
		XA_ATTR_INTERLEAVED  = (1 << 13),
		XA_ATTR_CDDA         = (1 << 14),
		XA_ATTR_DIRECTORY    = (1 << 15),

		XA_FORM1_DIR         = (XA_ATTR_DIRECTORY  | XA_ATTR_MODE2FORM1 | XA_PERM_ALL_ALL),
		XA_FORM1_FILE        = (XA_ATTR_MODE2FORM1 | XA_PERM_ALL_ALL),
		XA_FORM2_FILE        = (XA_ATTR_MODE2FORM2 | XA_PERM_ALL_ALL),
		
		XA_GENERAL_DIRECTORY = 0x558D,
		XA_GENERAL_FILE = 0x550D,
	}

	static const uint   ISO_XA_MARKER_OFFSET = 0x400;
	static const char[] ISO_XA_MARKER_STRING = "CD-XA001";

	u16  group_id;      // ?
	u16  user_id;       // ?
	Attr attributes;    // ?
	char signature[2];  // XA
	u8   filenum;       // -
	u8   reserved[5];   // -
}

// 9.1 Format of a Directory Record
align (1) struct DirectoryRecord
{
	align(1) struct Date {
		union {
			struct { u8 year, month, day, hour, minute, second, offset; }
			u8[7] v;
		}
		
		void opAssign(d_time t) {
			std.date.Date date;
			date.parse(std.date.toUTCString(t));
			year   = date.year - 1900;
			month  = date.month;
			day    = date.day;
			hour   = date.hour;
			minute = date.minute;
			second = date.second;
			offset = 0;				
		}
	}
	
	enum Flag : u8 {
		Empty           = 0,
		Existence       = (1 << 0),
		Directory       = (1 << 1),
		Associated_File = (1 << 2),
		Record          = (1 << 3),
		Protection      = (1 << 4),
		Reserved_0      = (1 << 5),
		Reserved_1      = (1 << 6),
		Multi_Extent    = (1 << 7),
	}

	u8   Length;                   // 1      | Length of Directory Record (LEN_DR) | numerical value  | 9.1.1  Length of Directory Record (LEN_DR) (BP 1)
	u8   ExtAttrLength;            // 2      | Extended Attribute Record Length    | numerical value  | 9.1.2  Extended Attribute Record Length (BP 2)
	u32b Extent;                   // 3-10   | Location of Extent                  | numerical value  | 9.1.3  Location of Extent (BP 3 to 10
	u32b Size;                     // 11-18  | Data Length                         | numerical value  | 9.1.4  Data Length (BP 11 to 18)
	Date date;                     // 19-25  | Recording Date and Time             | numerical values | 9.1.5  Recording Date and Time (BP 19 to 25)
	Flag flags;                    // 26     | File Flags                          | 8 bits           | 9.1.6  File Flags (BP 26)
	u8   FileUnitSize;             // 27     | File Unit Size                      | numerical value  | 9.1.7  File Unit Size (BP 27)
	u8   Interleave;               // 28     | Interleave Gap Size                 | numerical value  | 9.1.8  Interleave Gap Size (BP 28)
	u16b VolumeSequenceNumber;     // 29-32  | Volume Sequence Number              | numerical value  | 9.1.9  Volume Sequence Number (BP 29 to 32)
	u8   NameLength;               // 33     | Length of File Identifier (LEN_FI)  | numerical value  | 9.1.10 Length of File Identifier (LEN_FI) (BP 33)
	                               // 34-(33+L_FI)   | File Identifier             | d-characters...  | 9.1.11 File Identifier [BP 34 to (33 + LEN-FI)]
								   // 34+(LEN_FI)    | Padding Field               | (00) byte        | 9.1.12 Padding Field [BP (34 + LEN_FI)
								   // (LEN_DR-L_SU+1)-LEN_DR | System Use          | LEN_SU bytes     | 9.1.13 System Use [BP (LEN_DR - LEN_SU + 1) to LEN_DR)
	
}

// 8 Volume Descriptors
align (1) struct VolumeDescriptor
{
	enum Type : u8 {
		BootRecord                    = 0x00, // 8.2 Boot Record
		VolumePartitionSetTerminator  = 0xFF, // 8.3 Volume Descriptor Set Terminator
		PrimaryVolumeDescriptor       = 0x01, // 8.4 Primary Volume Descriptor
		SupplementaryVolumeDescriptor = 0x02, // 8.5 Supplementary Volume Descriptor
		VolumePartitionDescriptor     = 0x03, // 8.6 Volume Partition Descriptor
	}

	const static u8[5] ID = cast(u8[5])"CD001";
	
	Type type;
	u8   id[5] = ID;
	u8   ver = 1;
	u8   data[2041];
}

// 8.4 Primary Volume Descriptor
align (1) struct PrimaryVolumeDescriptor
{
	// 8.4.26 Volume Creation Date and Time (BP 814 to 830)
	align (1) struct Date
	{
		union {
			struct {
				char year[4]    = "0000"; // 1-4   | Year from 1 to 9999                | Digits
				char month[2]   = "00";   // 5-6   | Month of the year from 1 to 12     | Digits
				char day[2]     = "00";   // 7-8   | Day of the month from 1 to 31      | Digits
				char hour[2]    = "00";   // 9-10  | Hour of the day from 0 to 23       | Digits
				char minute[2]  = "00";   // 11-12 | Minute of the hour from 0 to 59    | Digits
				char second[2]  = "00";   // 13-14 | Second of the minute from 0 to 59  | Digits
				char hsecond[2] = "00";   // 15-16 | Hundredths of a second             | Digits
				s8   offset     = 0;      // 17    | Offset from Greenwich Mean Time in number of 15 min intervals from -48 (West) to +52 (East) recorded according to 7.1.2 // numerical value
			}
			u8 v[17];
		}
		
		void opAssign(d_time t) {
			static void clean(ubyte[] d) { for (int n = 0; n < d.length; n++) d[n] = 0; }
			std.date.Date date; clean(TA(date));
			if (t > 0) date.parse(std.date.toUTCString(t));
			year   [0..4] = std.string.format("%04d", date.year)[0..4];
			month  [0..2] = std.string.format("%02d", date.month)[0..2];
			day    [0..2] = std.string.format("%02d", date.day)[0..2];
			hour   [0..2] = std.string.format("%02d", date.hour)[0..2];
			minute [0..2] = std.string.format("%02d", date.minute)[0..2];
			second [0..2] = std.string.format("%02d", date.second)[0..2];
			hsecond[0..2] = std.string.format("%02d", 0)[0..2];
			offset = 0;				
		}		
	}
	
	VolumeDescriptor.Type type = VolumeDescriptor.Type.PrimaryVolumeDescriptor;    // 1         | Volume Descriptor Type
	u8 id[5] = VolumeDescriptor.ID;// 2-6       | Standard Identifier
	u8 ver = 1;                    // 7         | Volume Descriptor Version
	
	alias pad_string ps;
	u8   _1;                       // 8         | Unused Field                 | (00) byte
	ps!(0x20) SystemId;            // 9-40      | System Identifier            | a-characters
	ps!(0x20) VolumeId;            // 41-72     | Volume Identifier            | d-characters
	u64  _2;                       // 73-80     | Unused Field                 | (00) bytes
	u32b VolumeSpaceSize;          // 81-88     | Volume Space Size            | numerical value
	u64  _3[4];                    // 89-120    | Unused Field                 | (00) bytes
	u32  VolumeSetSize;            // 121-124   | Volume Set Size              | numerical value
	u32  VolumeSequenceNumber;     // 125-128   | Volume Sequence Number       | numerical value
	u16b LogicalBlockSize;         // 129-132   | Logical Block Size           | numerical value
	u32b PathTableSize;            // 133-140   | Path Table Size              | numerical value
	u32  TypeLPathTable;           // 141-144   | Location of Occurrence of Type L Path Table | numerical value
	u32  Type1PathTableOpt;        // 145-148   | Location of Optional Occurrence of Type L Path Table | numerical value
	u32  TypeMPathTable;           // 149-152   | Location of Occurrence of Type M Path Table | numerical value
	u32  TypeMPathTableOpt;        // 153-156   | Location of Optional Occurrence of Type M Path Table | numerical value
	
	DirectoryRecord dr;            // 157-190   | Directory Record for Root Directory | 34 bytes
	
	u8   _4;
	ps!(0x80) VolumeSetId;         // 191-318   | Volume Set Identifier         | d-characters
	ps!(0x80) PublisherId;         // 319-446   | Publisher Identifier          | a-characters
	ps!(0x80) PreparerId;          // 447-574   | Data Preparer Identifier      | a-characters
	ps!(0x80) ApplicationId;       // 575-702   | Application Identifier        | a-characters
	ps!(37)   CopyrightFileId;     // 703-739   | Copyright File Identifier     | d-characters, SEPARATOR 1, SEPARATOR 2
	ps!(37)   AbstractFileId;      // 740-776   | Abstract File Identifier      | d-characters, SEPARATOR 1, SEPARATOR 2
	ps!(37)   BibliographicFileId; // 777-813   | Bibliographic File Identifier | d-characters, SEPARATOR 1, SEPARATOR 2
	
	Date CreationDate;             // 814-830   | Volume Creation Date and Time         | Digit(s), numerical value
	Date ModificationDate;         // 831-847   | Volume Modification Date and Time     | Digit(s), numerical value
	Date ExpirationDate;           // 848-864   | Volume Expiration Date and Time       | Digit(s), numerical value
	Date EffectiveDate;            // 865-881   | Volume Effective Date and Time        | Digit(s), numerical value
	u8   FileStructureVersion;     // 882       | File Structure Version                | numerical value
	u8   _5;                       // 883       | (Reserved for future standardization) | (00) byte
	
	struct XAPVD {
		ps!(0x8D) game;
		ps!(0x73) magic;
		u8 data[0x100];
	}
	
	XAPVD ApplicationData;
	//u8   ApplicationData[0x200];   // 884-1395  | Application Use                       | not specified
	u8   _6[653];                  // 1396-2048 | (Reserved for future standardization) | (00) bytes
}

// Asserts
static assert (DirectoryRecord.sizeof == 33);
static assert (VolumeDescriptor.sizeof == 0x800);
static assert (PrimaryVolumeDescriptor.sizeof == 0x800);
static assert (ISO9660_XA.sizeof == 14);

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


abstract class StreamLatent : Stream
{
	private Stream s;
	
	abstract Stream open();
	
	void check() {
		if (s) return;
		s = open;
	}

	size_t readBlock(void* buffer, size_t size) {
		check();
		return s.readBlock(buffer, size);
	}
	
	size_t writeBlock(void* buffer, size_t size) {
		check();
		return s.writeBlock(buffer, size);
	}
	
	ulong seek(long offset, SeekPos whence) {
		check();
		return s.seek(offset, whence);
	}
	
	void close() {
		if (s) s.close();
		Stream.close();
	}
}

class FileLatent : StreamLatent
{
	char[] file;

	this(char[] file) {
		this.file      = file;
		this.readable  = true;
		this.writeable = false;
		this.seekable  = true;
	}
	
	Stream open() {
		return new File(file);
	}
}

static int do_pad(int pos, int size = 0x800) {
	if ((pos % size) != 0) return size - (pos % size);
	return 0;
}

static int do_pad_if_exceeds(int start, int len, int size = 0x800) {
	if ((start / size) != ((start + len) / size)) {
		//writefln("do_pad_if_exceeds!");
		return size - (start % size);
	}
	return 0;
}

void write_dummy(Stream s, int length) {
	if (length <= 0) return;
	s.write(new ubyte[length]);
}

long sector_chunks_size(int pos, long[] vv, int size = 0x800) {
	int l = 0;
	long sum = 0;
	foreach (v; vv) {
		sum += v;
		l += do_pad_if_exceeds(l, v, size);
		l += v;
		//writefln(":: %04X: %04X, %04X", v, sum, l);
	}
	return l;
}

class Entry : FS_Entry
{
	struct Info
	{
		u16 user_id, group_id;
		bool at_hidden, at_system;
		d_time time;
		Stream s;
		Entry linked; // Could cause loops
		long length;
	}

	public DirectoryRecord dr;
	protected ISO9660_XA xa;
	bool folder = false;
	
	Iso iso;
	static Iso last_iso;	
	
	protected Entry prev, next;
	
	protected Entry parent;
	protected Entry[] _childs, folders, files;
	//public char[] name;
	
	override FS_Entry[] childs() { return cast(FS_Entry[])_childs; }

	long num = 1;
	long num_folder;
	
	this(char[] name, Iso iso, DirectoryRecord dr, ISO9660_XA xa = xa.init) {
		init(name, iso);
		this.dr = dr;
		this.xa = xa;
	}
	
	override Stream open(FileMode mode = FileMode.In, bool grow = false) {
		return iso.open(dr, mode, grow);
	}
	
	void init(char[] name, Iso iso) {
		if (iso is null) iso = last_iso;
		assert(iso !is null);
		this.iso = iso;
		this.name = name;
		this.prev = iso.last;
		if (iso.last) {
			iso.last.next = this;
			num = iso.last.num + 1;
		}
		iso.last = this;
		last_iso = iso;
		
		iso.entries ~= this;
		if (folder) {
			iso.folders ~= this;
		} else {
			iso.files ~= this;
		}
	}
	
	this(char[] name = "", Iso iso = null) {
		init(name, iso);
	}

	long _length = -1;
	long length(int level = 0) {
		assert(level < 0x10, "Detected loop at starts_at. linked");
		
		if (folder) {
			long[] ll;
			
			ll ~= parent_self.dr_size(1);
			ll ~= this.dr_size(2);
			foreach (child; _childs) ll ~= child.dr_size(0);
			
			//_length = sector_chunks_size(0, ll);
			return sectors_for(sector_chunks_size(0, ll)) * 0x800;
		} else {
			if (info.linked) {
				return info.linked.length(level + 1);
			} else {
				return info.length;
			}
		}
	}
	
	long length_sec() { return sectors_for(length) * 0x800; }
	
	void writeSelf(Stream _s) {
		Stream s = new SliceStream(_s, _s.position);
		//writefln("writing: %s", name);
		
		if (folder) {
			this.write_dr(s, 1);
			parent_self.write_dr(s, 2);
			
			foreach (child; _childs) {
				write_dummy(s, do_pad_if_exceeds(s.position, child.dr_size(0)));
				child.write_dr(s, 0);
			}
		} else {
			if (info.s) {
				static ubyte[] temp;
				if (!temp.length) temp = new ubyte[0x1000000];;
				auto ss = new SliceStream(info.s, 0);
				long cw, w = 0;
				while (!ss.eof) {
					s.write(temp[0..cw = ss.read(temp)]);
					w += cw;
				}
				writefln("data (%s) : %d", name, w);
				//delete temp; temp = null;
			} else {
				writefln("no data (%s)", name);
			}
			//return info.length;
		}
		
		assert(s.position <= length, format("entry exceeded its expected size %d <- %d (%s)", length, s.position, path));
		write_dummy(s, length_sec - s.position);
	}
	
	static long sectors_for(long v, long size = 0x800) {
		return (v / size) + ((v % size) ? 1 : 0);
	}
	
	protected bool hasInfo;
	protected Info _info;
	Info info() {
		if (folder) return _info;
		
		if (!hasInfo && (iso.set_info !is null)) {
			iso.set_info(this, _info);
			hasInfo = true;
		}

		return _info;
	}
	
	// Recursive
	long _starts_at = -1;
	long _starts_at_nobase = -1;
	long starts_at(int level = 0) {
		if (_starts_at_nobase != -1) return _starts_at_nobase + (iso.start_dr_lba * 0x800);
		assert(_starts_at_nobase != -1);
	}

	long starts_at_sector() {
		long r = starts_at;
		assert((r % 0x800) == 0);
		return r / 0x800;
	}
	
	long ends_at() { return starts_at + length_sec; }
	
	void prepare_dr(int type = 0) {
		//writefln(" - %d", starts_at_sector);
		dr.Length = dr_size(type);
		dr.ExtAttrLength = 0;
		dr.NameLength = (type == 0) ? name.length : 1;
		dr.Extent = starts_at_sector;
		dr.Size = length;
		dr.date = info.time;
		//dr.VolumeSequenceNumber = num;
		dr.VolumeSequenceNumber = 1;

		dr.flags = DirectoryRecord.Flag.Empty;
		if (folder || is_root || type != 0) dr.flags |= DirectoryRecord.Flag.Directory;
	}
	
	long dr_size(int type = 0) {
		long r = dr.sizeof;
		int len = (type == 0) ? name.length : 1;
		r += len;
		if (iso.xa) {
			if ((len % 2) == 0) r += 1;
			r += xa.sizeof;
		}
		return r;
	}
	
	void write_dr(Stream s, int type = 0) {
		long spos = s.position;
		
		prepare_dr(type);
		
		// DR
		s.write(TA(dr));
		
		// Name
		int len;
		switch (type) {
			case 0: s.writeString(name); len = name.length; break;
			case 1: s.write(cast(ubyte)0x00); len = 1; break;
			case 2: s.write(cast(ubyte)0x01); len = 1; break;
		}
		
		// XA
		if (iso.xa) {
			xa.signature[0..2] = "XA";
			if (folder) {
				xa.attributes = ISO9660_XA.Attr.XA_GENERAL_DIRECTORY;
			} else {
				xa.attributes = ISO9660_XA.Attr.XA_GENERAL_FILE;
			}
			if ((len % 2) == 0) s.write(cast(ubyte)0);
			s.write(TA(xa));
		}

		assert(((s.position - spos) == dr_size(type)), format("write_dr: %s (%d) <- (%d)", path, dr_size(type), s.position - spos));
	}
	
	long folder_type_length() {
		if (is_root) return 9;
		return 8 + name.length;
	}
	
	void folder_type_write(Stream s, int type = 0) {
		ushort l = name.length;
		if (is_root) l = 1;
		s.write(l);
		if (type == 0) {
			s.write(cast(uint)starts_at_sector);
			s.write(cast(ushort)parent_self.num_folder);
		} else {
			s.write(cast(uint)bswap(starts_at_sector));
			s.write(cast(ushort)(bswap(parent_self.num_folder) >> 16));
		}
		if (is_root) {
			s.write(cast(ubyte)0);
		} else {
			s.writeString(name);
		}
	}
	
	bool is_root() { return iso.root is this; }
	
	void opCatAssign(Entry e) {
		assert(e.parent is null);
		e.parent = this; _childs ~= e;
		if (e.folder) folders ~= e; else files ~= e;
	}
	
	override bool is_file() { return !folder; }
	override bool is_dir() { return folder; }
}

class Folder : Entry
{
	this(char[] name = "", Iso iso = null) { folder = true; super(name, iso); }
}

class Iso : FS_Entry {
	void delegate(Entry e, ref Entry.Info i) set_info;
	Entry root, last;
	long start_dr_lba;
	bool xa = true;
	PrimaryVolumeDescriptor pvd;
	Entry[] entries, folders, files;
	
	char[] SystemId = "PSP GAME";
	char[] VolumeId = "";
	char[] VolumeSetId = "";
	char[] PublisherId = "";
	char[] PreparerId = "";
	char[] ApplicationId = "PSP GAME";
	char[] CopyrightFileId = "";
	char[] AbstractFileId = "";
	char[] BibliographicFileId = "";
	char[] GameId = "";
	
	override FS_Entry opIndex(char[] path) { return root[path]; }
	override FS_Entry[] childs() { return root.childs; }
	
	Entry[] folders2() {
		Entry[] r = [root];
		for (int n = 0; n < r.length; n++) {
			Entry e = r[n];
			foreach (ee; e.folders) r ~= ee;
		}
		return r;
	}
	
	void writeEntries(Stream s) {
		writefln("writeEntries (b)");
		foreach (e; entries) if (!e.info.linked) e.writeSelf(new SliceStream(s, e.starts_at));
	}
	
	void writeSystem(Stream s) {
		writefln("writeSystem");
		s.position = 0;
		s.write(new ubyte[0x800 * (0x10 - 2)]);
		ubyte[] d = new ubyte[0x800 * 2];
		for (int n = 0; n < d.length; n++) d[n] = 0x20;
		s.write(d);
	}
	
	void setEntriesPositions() {
		writefln("setEntriesPositions");
		
		long l = 0;

		// Root
		root._starts_at_nobase = l;
		l += root.length_sec;

		writefln("setEntriesPositions (1)");
		
		// Folders
		Entry[] ff = folders2();
		foreach (k, e; ff[1..ff.length]) {
			e._starts_at_nobase = l;
			e.num_folder = k + 2;
			l += e.length_sec;
		}

		writefln("setEntriesPositions (2)");

		// Files not linked
		foreach (k, e; files) {
			if (e.info.linked) continue;
			writefln(k);
			e._starts_at_nobase = l;
			l += e.length_sec;
		}
		
		writefln("setEntriesPositions (3)");
		
		// Files linked
		foreach (e; files) {
			if (!e.info.linked) continue;
			assert(e.info.linked.info.linked is null, "linked file to another linked");
			e._starts_at_nobase = e.info.linked._starts_at_nobase;
		}
		
		writefln("/setEntriesPositions");
	}

	long folders_size() {
		long[] ll;
		long pos = 0;
		foreach (entry; folders2) {
			long cpos = entry.folder_type_length;
			if (pos % 2) cpos++;
			ll  ~= cpos;
			pos += cpos;
		}
		//return sector_chunks_size(10, ll);
		return pos;
	}
	
	void writeFolders(Stream s, int type = 0) {
		writefln("writeFolders");
		//auto buf = new MemoryStream();
		auto buf = s;
		
		foreach (entry; folders2) {
			//write_dummy(buf, do_pad_if_exceeds(buf.position, entry.folder_type_length));
			if (buf.position % 2) buf.write(cast(ubyte)0);
			entry.folder_type_write(buf, type);
		}
		
		//s.copyFrom(buf);
	}
	
	void writePVD(Stream s) {
		writefln("writePVD");
		long folders_size_bytes = folders_size;
		long folders_size_sec = Entry.sectors_for(folders_size_bytes);
		start_dr_lba = 0x12 + folders_size_sec * 4;
		
		setEntriesPositions();

		s.position = 0x800 * (0x12 + folders_size_sec * 0); writeFolders(s, 0);
		s.position = 0x800 * (0x12 + folders_size_sec * 1); writeFolders(s, 0);
		s.position = 0x800 * (0x12 + folders_size_sec * 2); writeFolders(s, 1);
		s.position = 0x800 * (0x12 + folders_size_sec * 3); writeFolders(s, 1);
		
		s.position = 0x800 * 0x11;
		VolumeDescriptor vd;
		vd.type = VolumeDescriptor.Type.VolumePartitionSetTerminator;
		s.write(TA(vd));

		s.position = 0x800 * 0x10;
		pvd.SystemId = SystemId;
		pvd.VolumeId = VolumeId;
		
		pvd.VolumeSpaceSize = last.ends_at / 0x800;
		pvd.VolumeSetSize = 0x01000001;
		pvd.VolumeSequenceNumber = 0x01000001;
		pvd.LogicalBlockSize = 0x800;

		pvd.PathTableSize     = 10 + folders_size_bytes;
		pvd.TypeLPathTable    = 0x12 + folders_size_sec * 0;
		pvd.Type1PathTableOpt = 0x12 + folders_size_sec * 1;
		pvd.TypeMPathTable    = bswap(0x12 + folders_size_sec * 2);
		pvd.TypeMPathTableOpt = bswap(0x12 + folders_size_sec * 3);
		
		pvd.VolumeSetId = VolumeSetId;
		pvd.PublisherId = PublisherId;
		pvd.PreparerId = PreparerId;
		pvd.ApplicationId = ApplicationId;
		pvd.CopyrightFileId = CopyrightFileId;
		pvd.AbstractFileId = AbstractFileId;
		pvd.BibliographicFileId = BibliographicFileId;
		
		pvd.CreationDate = getUTCtime;
		pvd.ModificationDate = 0;
		pvd.ExpirationDate = 0;
		pvd.EffectiveDate = 0;
		pvd.FileStructureVersion = 2;
		
		pvd.ApplicationData.game  = GameId;
		pvd.ApplicationData.magic = "CD-XA001";
		pvd.ApplicationData.data[0..0x100] = cast(u8[])(x"00000000000000000800240000010A0000000000250000002500000000000000202020202020202020202020202020202020202020202020202020202020202020202020200000000800080000010F0090044800200000002000000001000000202020202020202020202020202020202020202020202020202020202020202000000000000000001400080000010F0000000000800000008000000000000000202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020");

		root.prepare_dr();
		pvd.dr = root.dr;
		
		s.write(TA(pvd));
	}
	
	void SetPSP_GameId() {
		Entry e;
		try {
			e = cast(Entry)root["UMD_DATA.BIN"];
			auto ss = new SliceStream(e.info.s, 0);
			GameId = ss.readString(32);
			writefln("UMD_DATA.BIN: %s", GameId);
		} catch (Exception e) {
			writefln("no UMD_DATA.BIN (%s)", e.toString);
		}
	}
	
	void write(Stream s) {
		writeSystem(s);
		writePVD(s);
		writeEntries(s);
	}
	
	this() {
		root = new Folder("", this);
		start_dr_lba = 0x10;
		//set_info = &set_info_dummy;
		root._info.time = getUTCtime;
		root.num_folder = 1;
	}

	this(char[] name) {
		this(new BufferedFile(name));
	}
	
	Stream stream;
	
	Stream open(DirectoryRecord dr, FileMode mode = FileMode.In, bool grow = false) {
		long pos = dr.Extent.v * 0x800;
		if (grow) {
			return new SliceStream(stream, pos, pos + dr.Size.v);
		} else {
			return new SliceStream(stream, pos);
		}
	}	
	
	void processDirectory(Entry e) {
		DirectoryRecord dr, bdr = e.dr;
		int cp;
		
		Stream stream = new SliceStream(this.stream, bdr.Extent.v * 0x800);

		uint maxPos = stream.position + cast(uint)bdr.Size.v;
		
		//Dump(bdr);
		
		while (true) {
			char[] name;
			Stream dr_stream;

			uint bposition = stream.position;

			dr_stream = new SliceStream(stream, stream.position);
			dr_stream.read(TA(dr));

			if (!dr.Length) {
				stream.position = (bposition / 0x800 + 1) * 0x800;
				
				dr_stream = new SliceStream(stream, stream.position);
				dr_stream.read(TA(dr));
			}
			
			stream.seekCur(dr.Length);
			
			if (stream.position >= maxPos) break;

			name = dr_stream.readString(dr.NameLength);
			
			//writefln(name);
			
			Entry ne;
			
			if (dr.flags & DirectoryRecord.Flag.Directory) {
				if (dr.NameLength && (name[0] != 0) && (name[0] != 1)) {
					ne = new Entry(name, this, dr);
					ne.folder = true;
					processDirectory(ne);
				}
			} else {
				ne = new Entry(name, this, dr);
			}
			
			if (ne) e ~= ne;
		}		
	}
	
	this(Stream s) {
		while (true) {
			char[] hd = s.readString(4); s.seekCur(-4);
			switch (hd) {
				case "CISO": s = new CSOStream(s); continue;
				case "CVMH": s = new SliceStream(s, 0x1800); continue;
				default: break;
			}
			break;
		}
		
		stream = s;

		stream.position = 0x8000;
		stream.read(TA(pvd));
		
		root = new Entry("", this, pvd.dr);
		processDirectory(root);
	}
}
