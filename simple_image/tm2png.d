import simple_image.simple_image;

import std.stream;
import std.string;
import std.stdio;
import std.date;
import std.file;

void setString(char[] v, char[] s = "", char pad = '\0') {
	int mlen = s.length;
	if (v.length < mlen) mlen = v.length;
	v[0..mlen] = s;
	for (int n = mlen; n < v.length; n++) v[n] = pad;
}

align(1) struct TAR_Entry {
	char[100] file;
	char[8]   mode;
	char[8]   uid;
	char[8]   gid;
	char[12]  size;
	char[12]  time;
	char[8]   checksum;
	char      link;
	char[100] linked;
	
	static TAR_Entry opCall(char[] name, uint size, long time) {
		TAR_Entry e;
		
		setString(e.file, name);
		setString(e.linked, "");
		setString(e.mode, std.string.format("%6o \0", 0777));
		setString(e.uid , std.string.format("%6o \0", 0));
		setString(e.gid , std.string.format("%6o \0", 0));
		setString(e.size, std.string.format("%11o " , size));
		setString(e.time, std.string.format("%11o " , time));
		e.link = '0';
		
		setString(e.checksum, "", ' ');
		
		ulong checksum = 0;
		foreach (c; TA(e)) checksum += c;

		setString(e.checksum, std.string.format("%6o \0" , checksum));

		return e;
	}
}

void showHelp() {
	writefln("tm2png file.tm2");
}

void convert(char[] name) {
	char[] i_f = name;
	char[] o_f = name ~ ".tar";
	
	writefln("%s->%s", i_f, o_f);
	
	Image i = ImageFileFormatProvider.read(new File(i_f, FileMode.In));
	Stream o = new File(o_f, FileMode.OutNew);
	
	void doAlign() {
		while (o.position % 0x200) o.write(cast(ubyte)0);
	}
	
	TAR_Entry te;

	void writeTE() {
		doAlign();
		o.write(TA(te));
	}
	
	foreach (k, ic; i.childs) {
		Stream fs = new MemoryStream();
	
		Image ic32 = new Bitmap32(ic.width, ic.height); ic32.copyFrom(ic);
		ImageFileFormatProvider["png"].write(ic32, fs);

		te = TAR_Entry(std.string.format("%03d.png", k), fs.size, getUTCtime() / TicksPerSecond);

		writeTE();
		doAlign();
		fs.position = 0; o.copyFrom(fs);
	}
	
	setString(cast(char[])TA(te));
	//writeTE();
	doAlign();
}

int main(char[][] args) {
	if (args.length < 2) {
		showHelp();
		return 0;
	}
	
	if (isdir(args[1])) {
		listdir(args[1], delegate bool(char[] n) {
			if (n.length < 4) return true;
			if (toupper(n[n.length - 4..n.length]) == ".TM2") {
				try {
					convert(args[1] ~ "/" ~ n);
				} catch (Exception e) {
					writefln("ERROR: %s", e.toString());
				}
			}
			return true;
		});
	} else {
		convert(args[1]);
	}

	return 0;
}