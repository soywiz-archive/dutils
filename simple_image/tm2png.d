// soywiz@gmail.com
import simple_image;

import std.stream;
import std.string;
import std.stdio;
import std.date;
import std.file;
import std.zip;

void showHelp() {
	writefln("tm2png <file.tm2>");
}

void convert(char[] name) {
	char[] i_f = name;
	char[] o_f = name ~ ".zip";
	
	writefln("%s->%s", i_f, o_f);
	
	Image i = ImageFileFormatProvider.read(new BufferedStream(new File(i_f, FileMode.In)));
	
	std.zip.ZipArchive za = new ZipArchive();
	std.zip.ArchiveMember zam;
	
	foreach (k, ic; i.childs) {
		Stream fs = new MemoryStream();
	
		Image ic32 = new Bitmap32(ic.width, ic.height); ic32.copyFrom(ic);
		ImageFileFormatProvider["png"].write(ic32, fs);
		
		ubyte[] data;
		data.length = fs.position;
		fs.position = 0;
		fs.read(data);
		
		zam = new ArchiveMember();
		zam.name = std.string.format("%03d.png", k);
		zam.expandedData = data;
		za.addMember(zam);

		fs.position = 0; o.copyFrom(fs);
	}
	
	i.close();

	Stream o = new BufferedStream(new File(o_f, FileMode.OutNew));
	o.write(cast(ubyte[])za.build());
	o.close();
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