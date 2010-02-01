module ppf;

import std.stream, std.stdio, std.string;

class PPF {
	align(1) struct Header {
		char[5] magic = "PPF20";
		ubyte ppf_version = 0x01; // Version 2
		uint size;
		char[50] description;
		ubyte[1024] signature; // 0x9320
		static assert(Header.sizeof == 1084);
	}
	
	Stream streamOutput;
	Header header = Header.init;
	ubyte[] dataOriginal;
	ubyte[] dataModified;
	uint startOffset;
	string description;

	this(Stream streamOutput) {
		this.streamOutput = streamOutput;
	}
	
	this(string fileName) {
		this(new std.stream.BufferedFile(fileName, FileMode.OutNew));
	}

	~this() {
		close();
	}

	void write() {
		writeHeader();
		writeBody();
	}

	void writeHeader() {
		header.size = dataOriginal.length + startOffset;
		//header.signature = dataOriginal[0x9320..0x9320 + 1024];
		header.description[0..description.length] = description;
		streamOutput.write(cast(ubyte[])((&header)[0..1]));
	}
	
	void writeBody() {
		assert(dataModified.length >= dataOriginal.length);
		int matched = 0;
		writefln("%08X", dataOriginal.length);
		for (int n = 0; n <= dataOriginal.length; n++) {
			//writefln("%02X: %02X", dataOriginal[n], dataModified[n]);
			if ((dataOriginal.length == n) || (dataOriginal[n] == dataModified[n]) || (matched == 0xFF)) {
				if (matched > 0) {
					scope start = n - matched;
					scope slice = dataModified[start..n];

					assert(slice.length == matched);
					assert(matched < 0x100);

					streamOutput.write(cast(uint)(start + startOffset));
					streamOutput.write(cast(ubyte)matched);
					streamOutput.write(slice);

					matched = 0;
				}
			} else {
				matched++;
			}
		}
	}
	
	void close() {
		streamOutput.close();
	}
}