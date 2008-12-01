import lzma;

import std.file;

void main() {
	write("lzma.txt.out", lzma.decode(cast(ubyte[])read("lzma.txt.lzma")));
}