module ppf;

import std.stream, std.stdio, std.string, std.algorithm;

//version = PPF_OPTIMIZE;

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
		int distinctCount = 0;
		int distinctStart = 0;
		writefln("%08X", dataOriginal.length);
		for (int n = 0; n <= dataOriginal.length; n++) {
			//writefln("%02X: %02X", dataOriginal[n], dataModified[n]);
			if ((dataOriginal.length == n) || (dataOriginal[n] == dataModified[n]) || (distinctCount >= 0xFF)) {
				// Check if we will find a match in less than 8 bytes for optimizing output.
				/*version (PPF_OPTIMIZE) {
					if (distinctCount < 0x100) {
						bool foundDistinct;
						int m;
						for (m = n; (m < n + 8) && (m < dataOriginal.length); m++) if (dataOriginal[m] != dataModified[m]) { foundDistinct = true; break; }
						if (foundDistinct) {
							m--;
							int add = m - n;
							if (distinctCount + add < 0x100 - 1) {
								//writefln("Optimize! %d", m - n);
								distinctCount += add;
								n = m;
								continue;
							}
						}
					}
				}*/
				if (distinctCount > 0) {
					scope slice = dataModified[distinctStart..n];

					assert(slice.length == distinctCount, std.string.format("%d == %d", slice.length, distinctCount));
					assert(distinctCount < 0x100);

					streamOutput.write(cast(uint)(startOffset + distinctStart));
					streamOutput.write(cast(ubyte)distinctCount);
					streamOutput.write(slice);
				}
				distinctCount = 0;
				distinctStart = n + 1;
			} else {
				distinctCount++;
			}
		}
	}
	
	void close() {
		streamOutput.close();
	}
}