import std.stdio, std.c.stdio, std.string, std.stream, std.regex, std.regexp, std.zip, std.getopt;

template StringUtils() {
	static addslashes(string i) {
		char[char] map = ['\a' : 'a', '\b' : 'b', '\n' : 'n', '\r' : 'r', '\t' : 't', '\v' : 'v', '\\' : '\\', '"' : '"', '\'' : '\''];
		string r;
		foreach (c; i) r ~= ((c in map) !is null) ? ['\\', map[c]] : [c];
		return r;
	}

	static stripslashes(string i) {
		char[char] map = ['a' : '\a', 'b' : '\b', 'n' : '\n', 'r' : '\r', 't' : '\t', 'v' : '\v', '\\' : '\\', '"' : '"', '\'' : '\''];
		string r;
		for (int n = 0; n < i.length; n++) r ~= (i[n] == '\\') ? map[i[++n]] : i[n];
		return r;
	}

	long hexdec(string s) {
		if (s.length && s[0] == '-') return -hexdec(s[1..$]);
		long value;
		foreach (c; s) {
			int digit;
			if (c == '_') continue;
			     if (c >= '0' && c <= '9') digit = c - '0';
			else if (c >= 'a' && c <= 'f') digit = c - 'a' + 10;
			else if (c >= 'A' && c <= 'F') digit = c - 'A' + 10;
			value *= 16;
			value += digit;
		}
		return value;
	}
	
	unittest {
		assert(hexdec("10") == 0x10);
		assert(hexdec("-ff") == -0xff);
	}
}

mixin StringUtils;

class StreamAggregator : Stream {
	class Map {
		Stream stream;
		uint   start;
		uint   end;
		ubyte[] cached = null;
		this(Stream stream, uint start, uint end) {
			this.stream = stream;
			this.start  = start;
			this.end    = end;
		}
		uint length() { return end - start; }
		ubyte[] data() {
			if (cached is null) cached = cast(ubyte[])(new SliceStream(stream, 0)).readString(length);
			return cached;
		}
		void clearCache() { cached = null; }
	}
	Map currentMap;
	Map[] maps;
	uint currentPosition;
	//uint positionMask = 0x_0FFFFFFF;

	void clearCache() {
		foreach (map; maps) map.clearCache();
	}

	auto addMap(uint start, Stream stream) {
		//start &= positionMask;
		maps ~= new Map(stream, start, cast(uint)(start + stream.size));
		return this;
	}

	size_t readBlock(void* buffer, size_t size) {
		if (currentMap is null) return 0;
		size_t transferredBytes = currentMap.stream.readBlock(buffer, size);
		position = position + transferredBytes;
		return transferredBytes;
	}

	size_t writeBlock(const void* buffer, size_t size) {
		if (currentMap is null) return 0;
		size_t transferredBytes = currentMap.stream.writeBlock(buffer, size);
		position = position + transferredBytes;
		return transferredBytes;
	}

	ulong seek(long offset, SeekPos whence) {
		switch (whence) {
			case SeekPos.Set, SeekPos.End: currentPosition = cast(uint)offset; break;
			case SeekPos.Current: currentPosition += offset; break;
		}
		//currentPosition &= positionMask;
		currentMap = null;
		foreach (map; maps) {
			if (currentPosition >= map.start && currentPosition < map.end) {
				currentMap = map;
				currentMap.stream.position = currentPosition - currentMap.start;
				break;
			}
		}
		return currentPosition;
	}

	ubyte opIndex(uint position) {
		return this[position..position + 1][0];
	}

	ubyte[] opSlice(uint start, uint end) {
		auto data = new ubyte[end - start];
		scope slice = new SliceStream(this, 0);
		slice.position = start;
		slice.read(data);
		return data;
	}
}

interface Patcheable {
	string toString();
	string simpleString();
	void patch(Stream stream, uint newValue);
}

class PatchPointer : Patcheable {
	uint value, valueRaw, valueNew;
	uint address;
	string text;

	this(uint value, uint address, uint valueRaw, string text) {
		this.value    = value;
		this.valueRaw = valueRaw;
		this.address  = address;
		this.text     = text;
	}

	string toString() {
		return std.string.format("T:%08X:[%08X]:", address, valueRaw) ~ addslashes(text);
	}

	string simpleString() {
		return std.string.format("T[%08X-%08X]", address, 0);
	}

	void patch(Stream stream, uint valueNew) {
		stream.position = address; stream.write(valueNew);
		this.valueNew = valueNew;
	}
}

class PatchCode : Patcheable {
	uint value, valueRaw, valueNew;
	uint addressHi;
	uint addressLo;
	string text;

	this(int value, int addressHi, int addressLo, int valueRaw, string text) {
		this.value     = value;
		this.valueRaw  = valueRaw;
		this.addressHi = addressHi;
		this.addressLo = addressLo;
		this.text      = text;
	}

	string toString() {
		return std.string.format("C:%08X:%08X:[%08X]:", addressHi, addressLo, valueRaw) ~ addslashes(text);
	}

	string simpleString() {
		return std.string.format("C[%08X-%08X]", addressHi, addressLo);
	}

	static void patchMIPSLoadAdress(ref uint HI, ref uint LO, uint valueNew) {
		// ADDI: 0010 00ss ssst tttt iiii iiii iiii iiii
		// ORI : 0011 01ss ssst tttt iiii iiii iiii iiii
		// LUI : 0011 11-- ---t tttt iiii iiii iiii iiii

		//HI &= 0b_1111111111111111_0000000000000000;
		HI &= 0b_0111111111111111_0000000000000000;
		HI |= (valueNew >> 16) & 0xFFFF;

		// Sets immediate value.
		LO &= 0b_1111111111111111_0000000000000000;
		LO |= (valueNew >>  0) & 0xFFFF;

		// Convert to ORI.
		LO &= 0b_000000_11111111111111111111111111;
		LO |= 0b_001101_00000000000000000000000000;
	}

	void patch(Stream stream, uint valueNew) {
		uint HI, LO;
		
		uint read(uint position, ref uint v) {
			try {
				stream.position = position;
				stream.read(v);
			} catch (Exception e) {
				.writefln("Error reading: %08X", position);
				.writefln("%s", this);
				throw(e);
			}
			return v;
		}

		uint write(uint position, ref uint v) {
			try {
				stream.position = position;
				stream.write(v);
			} catch (Exception e) {
				.writefln("Error writting: %08X <- %08X", position, v);
				.writefln("%s", this);
				throw(e);
			}
			return v;
		}
		
		read(addressHi, HI);
		read(addressLo, LO);
		{
			patchMIPSLoadAdress(HI, LO, valueNew);
		}
		write(addressHi, HI);
		write(addressLo, LO);
		this.valueNew = valueNew;
	}
}

class PatchEntry {
	string text;
	uint start, length;
	uint end() { return start + length; }
	uint end(uint end) { length = end - start; return end; }
	Patcheable[int] patches;
}

class MipsPointerSearch {
	static struct ANALYSIS_STATE {
		uint rld[32]; // Value of the registers.
		uint lui[32]; // Position where the affected LUI was found.
	}

	PatchEntry[int] search;
	uint data_base;
	uint valueMask = 0x0FFFFFFF;
	StreamAggregator mmap;
	uint[] code;
	ubyte[] data;

	void dump() {
		//writefln("%s", search.length);
		foreach (address, si; search) {
			//writefln("%s", si.text);
			//writef("%08X:", address);
			foreach (patchAddress, patch; si.patches) {
				write(patch.toString);
				writefln("");
			}
			//writefln("");
		}
	}

	int opApply(int delegate(ref int, ref PatchEntry) dg) {
		int result = 0;
		foreach (pos; search.keys.sort) {
			result = dg(pos, search[pos]);
			if (result) break;
		}
		return result;
	}

	this(StreamAggregator mmap, uint valueMask = 0x0FFFFFFF) {
		this.mmap      = mmap;
		this.valueMask = valueMask;
	}

	PatchEntry addAddress(uint start, uint end) {
		PatchEntry pe = new PatchEntry;
		pe.start  = start;
		char c;
		mmap.position = start;
		do { mmap.read(c); if (c) pe.text ~= c; } while (c);
		pe.length = end - start;
		search[start & valueMask] = pe;
		return pe;
	}

	public void execute() {
		foreach (map; mmap.maps) {
			this.data_base = map.start;
			this.data      = cast(ubyte[])map.data;
			this.code      = cast(uint[])map.data;
			execute(0);
		}
	}

	private void execute(int start, int level = 0, ANALYSIS_STATE state = ANALYSIS_STATE.init) {
		int n, m;
		int branch = -1;

		for (n = start; n < code.length; n++) {
			bool isbranch = false, update = false;
			//writefln("%d", n);

			uint cv = code[n];               // Dato actual de 32 bits
			uint cvm = (cv & valueMask);
			uint cpos = data_base + (n * 4); // Dirección actual
			int j, cop, rs, rt;              // Partes de la instrucción
			short imm;                       // Valor inmediato

			// Comprobamos si hemos encontrado un puntero de 32 bits
			//writefln("%08X", cvm);
			if (cvm in search) search[cvm].patches[cpos] = new PatchPointer(cvm, cpos, cv, search[cvm].text);

			// TIPO:I | Inmediato
			cop = (cv >> 26) & 0b111111; // 6 bits
			rs  = (cv >> 21) & 0b11111;  // 5 bits
			rt  = (cv >> 16) & 0b11111;  // 5 bits
			imm = (cv >>  0) & 0xFFFF;   // 16 bits

			// TIPO:J | Salto incondicional largo
			j   = cv & 0x3FFFFFF; // 26 bits

			// Comprueba el código de operación
			switch (cop) {
				// Saltos cortos
				case 0b000100: case 0b000101: isbranch = true; break; // BEQ, BNE
				case 0b000001: switch (rt) { case 0b00001: case 0b10001: case 0b00000: case 0b10000: isbranch = true; default: } break; // BGEZ, BGEZAL, BLTZ, BLTZAL
				case 0b000110: case 0b000111: if (rt == 0) isbranch = true; break; // BLEZ, BGTZ
				// Saltos largos
				//case 0b000010: break; // J
				// Carga de datos típicas (LUI + ADDI/ORI)
				case 0b001111: // LUI
					state.rld[rt] = (imm << 16);
					state.lui[rt] = cpos;
					update = true;
				break;
				case 0b001000: case 0b001001: // ADDI/ADDIU
					state.rld[rt] = state.rld[rs] + imm;
					update = true;
				break;
				case 0b001101: // ORI
					state.rld[rt] = state.rld[rs] | imm;
					update = true;
				break;
				default: break;
			}

			if (update) {
				state.rld[0] = 0x00000000;

				cvm = ((cv = state.rld[rt]) & valueMask);

				if (cvm in search) {
					search[cvm].patches[cpos] = new PatchCode(cvm, state.lui[rt], cpos, cv, search[cvm].text);
				}
			}

			if (branch != -1) {
				if (level > 0) return;
				execute(branch, level + 1, state);
				branch = -1;
			}

			if (isbranch) branch = n + imm;
		}
	}
}

class MipsPointerPatch {
	RangeList ranges;
	PatchEntry[int] search;
	StreamAggregator mmap;

	this(PatchEntry[int] search) {
		this.search = search;
		this.ranges = new RangeList();
		foreach (pentry; search) {
			//writefln("pentry: %08X.%08X", pentry.start, pentry.length);
			this.ranges.add(pentry.start, pentry.length);
		}
		
		//this.ranges.show();
		this.ranges.showSummary();
	}
	
	this(MipsPointerSearch mps) {
		this.mmap = mps.mmap;
		this(mps.search);
	}

	static opCall(MipsPointerSearch mps) {
		auto mpp = new MipsPointerPatch(mps);
		mpp.execute();
	}

	Patcheable[][uint] searchReusedLUIs(bool warning = true) {
		Patcheable[][uint] LUI;
		foreach (pentry; search) {
			foreach (patch; pentry.patches) {
				PatchCode pcode = cast(PatchCode)patch;
				if (pcode !is null) {
					//assert((pcode.addressHi in LUI) !is null, "Reutilized LUI!");
					LUI[pcode.addressHi] ~= patch;
				}
			}
		}
		if (warning) {
			foreach (patches; LUI) {
				if (patches.length > 1) {
					writefln("Reutilized LUI! {");
					foreach (patch; patches) {
						writefln("  %s", patch.toString);
					}
					writefln("}");
				}
			}
		}
		
		return LUI;
	}

	void cleanSegments() {
		scope ubyte[] temp;
		writef("Cleaning segments...");
		foreach (range; ranges) {
			mmap.position = range.start;
			if (temp.length < range.length) temp.length = range.length;
			mmap.write(temp[0..range.length]);
		}
		writefln("Ok");
	}

	void patch() {
		PatchCode[][uint] LUI;
		bool globalError;
		writef("Patching...");
		int text_count = 0;
		int patch_count = 0;
		foreach (pentry; search) {
			text_count++;

			string text = pentry.text;
			uint pos = ranges.getReuse(text);
			try {
				mmap.position = pos;
				mmap.writeString(text ~ '\0');
			} catch (Exception e) {
				writefln("Can't write translated string to 0x%08X", pos);
				throw(e);
			}

			foreach (patch; pentry.patches) {
				patch_count++;

				patch.patch(mmap, pos);

				PatchCode pcode = cast(PatchCode)patch;
				if (pcode !is null) {
					LUI[pcode.addressHi] ~= pcode;
				}
			}
		}
		writefln("texts(%d) patches(%d)", text_count, patch_count);
		foreach (patches; LUI) {
			const LUI_MASK = 0x_FFFF_0000;
			//const LUI_MASK = 0x_FFFF_FFFF;
			if (patches.length >= 2) {
				bool error = false;
				foreach (patch; patches[1..$]) if ((patch.valueNew & LUI_MASK) != (patches[0].valueNew & LUI_MASK)) { error = true; break; }
				if (error) {
					writefln("Reused LUI with different value {");
					foreach (patch; patches) {
						writefln("  [%08X]::%s", patch.valueNew & LUI_MASK, patch);
					}
					writefln("}");
				}
				globalError |= error;
			}
		}
		//assert(!globalError);
	}

	void execute() {
		//searchReusedLUIs(true);
		
		searchReusedLUIs(false);
		cleanSegments();
		patch();
		mmap.clearCache();
	}

	static class RangeList {
		int padding = 1;
		int[int] rangeStart;
		int[int] rangeEnd;
		
		struct Range { uint start, end; uint length() { return end - start; } }

		int opApply(int delegate(ref Range) dg) {
			int result = 0;
			foreach (start; rangeStart.keys.sort) {
				result = dg(Range(start, start + rangeStart[start]));
				if (result) break;
			}
			return result;
		}

		int getLastPosition() {
			int last = 0;
			foreach (int r, int l; rangeStart) if (r + l > last) last = r + l;
			return last;
		}

		void show() {
			//rangeEnd = rangeStart.rehash;
			writefln("%s {", this.toString);
			foreach (range; this) writefln("  RANGE: %08X-%08X(%d)", range.start, range.end, range.length);
			writefln("}");
		}

		uint showSummary() {
			uint totalLength = 0; foreach (range; this) totalLength += range.length;
			writefln("%s {", this.toString);
			writefln("  RANGE SPACE: %d", totalLength);
			writefln("}");
			return totalLength;
		}

		void add(int from, int length) {
			/*if (from in rangeStart) {
				if (length > rangeStart[from]) {
					rangeEnd.remove(from + rangeStart[from]);
					rangeStart[from] = length;
					rangeEnd[from + length] = length;
				}
				return;
			}*/

			// Range inner.
			foreach (range; this) if (from >= range.start && from < range.end) return;

			//printf("ADD_RANGE: %08X, %d\n", from, length);

			if (from in rangeEnd) {
				int rstart = from - rangeEnd[from];
				rangeStart[rstart] += length;
				rangeEnd.remove(from);
				rangeEnd[from + length] = rangeStart[rstart];
			} else {
				rangeStart[from] = rangeEnd[from + length] = length;
			}

			//removeInnerRanges();

			//showRanges();
		}

		int removeInner() {
			int removed = 0;
			bool done = false;
			while (!done) {
				done = true;
				foreach (int afrom, int alen; rangeStart) {
					foreach (int bfrom, int blen; rangeStart) {
						if (afrom == bfrom) continue;

						if (bfrom < afrom + alen && bfrom + blen > afrom + alen) {
							show();

							writefln("%08X(%d)", afrom, alen);
							writefln("%08X(%d)", bfrom, blen);

							assert(1 == 0);
						}

						if (bfrom < afrom && bfrom + blen > afrom) {
							show();
							assert(1 == 0);
						}

						if (afrom >= bfrom && afrom + alen <= bfrom + blen) {
							done = false;
							rangeEnd.remove(afrom + alen);
							rangeStart.remove(afrom);
							removed++;
							break;
						}
					}

					if (!done) break;
				}
			}
			return removed;
		}

		void use(int from, int length) {
			rangeEnd[from + rangeStart[from]] -= length;
			if (rangeStart[from] - length > 0) {
				rangeStart[from + length] = rangeStart[from] - length;
			}
			rangeStart.remove(from);
		}

		Range getFreeRange(int length) {
			foreach (range; this) { if (range.length >= length) return range; }
			show();
			throw(new Exception(format("Not enough space (%d)", length)));
		}
		
		template GetReuse() {
			uint[string] stringPos;
			uint getReuse(string text) {
				if (text in stringPos) {
					return stringPos[text];
				} else {
					return stringPos[text] = getAndUse(text.length + 1);
				}
			}
		}

		mixin GetReuse;

		int getAndUse(int length) {
			int start;
			use(start = getFreeRange(length).start, length);
			return start;
		}

		int length() {
			int r = 0; foreach (int l; rangeStart) r += l; return r;
		}
	}	
}

class TextSearcher {
	StreamAggregator mmap;

	this(StreamAggregator mmap) {
		this.mmap = mmap;
	}
	
	static opCall(StreamAggregator mmap) {
		auto ts = new TextSearcher(mmap);
		ts.execute();
		return ts.results;
	}
	
	static struct Result {
		uint start;
		uint end;
		string text;
		uint length() { return end - start; }
		string toString() { return std.string.format("%08X:%02X:'", start, length) ~ addslashes(text) ~ "'"; }
	}

	Result[] results;

	int MIN_LENGTH = 2;
	int ALIGNMENT = 4;

	private void execute(ubyte[] data, uint offset) {
		bool checkText(int start, int end, string text) {
			// Not aligned.
			if (text.length < MIN_LENGTH) return false;
			if ((start % ALIGNMENT) != 0) return false;
			
			int count_total   = text.length;
			int count_special = 0;
			
			foreach (c; text) {
				if (c < 0x20) {
					//return false;
					count_special++;
				}
				if (c > 0x7F) return false;
			}
			
			if (count_special >= count_total / 5) return false;

			for (int n = end; ((n % 4) != 0); n++) {
				if (data[end] != '\0') return false;
			}
			
			//writefln(1);

			return true;
		}

		for (int n = 0; n < data.length; n++) {
			int start = n;
			for (; n < data.length; n++) if (data[n] == '\0') break;
			int end = n;
			string text = cast(string)data[start..end];
			bool is_text = checkText(start, end, text);
			if (is_text) end++;
			if ((end % ALIGNMENT) != 0) end += ALIGNMENT - (end % ALIGNMENT);
			//writefln("%s : %08X", text, end);

			if (!is_text) {
				n = start;
			} else {
				results ~= Result(start + offset, end + offset, text);
				//writefln("%08X:%02X:'%s'", offset + start, offset + end, addslashes(text));
			}
			//break;
		}
	}

	void execute() {
		foreach (map; mmap.maps) {
			execute(map.data, map.start);
		}
	}
}

auto loadTranslation(string fileName) {
	scope file = new BufferedFile(fileName);
	string[uint] translation;
	while (!file.eof) {
		scope line = std.string.strip(file.readLine);
		if (!line.length) continue;
		scope matches = std.regexp.search(cast(string)line, r"^(\w+):(\w+):'(.*)'$", "mi");
		if (matches !is null) {
			string text = stripslashes(matches[3]);
			uint address = cast(uint)hexdec(matches[1]);
			//writefln("%08X: %s", address, text);
			translation[address] = text;
		} else {
			//writefln("Invalid line: '%s'", line);
		}
	}
	return translation;
}

int main(string[] args) {
	auto mmap = new StreamAggregator;
	bool showHelp = true;

	void help() {
		writefln("---------------------------------------------------------------------");
		writefln("Pointer Mips (pmips) - soywiz - 2010");
		writefln("---------------------------------------------------------------------");
		writefln("Utility for translating executable files of mips platforms.");
		writefln(" N64, PSX, PS2, PSP");
		writefln("---------------------------------------------------------------------");
		writefln("");
		writefln("Options:");
		writefln("  -map  Adds a memory map. -map FILE:START-END@MEMORY");
		writefln("");
		writefln("Operations:");
		writefln("  -t  (1) Find Text blocks and writtes to 'texts.txt'.");
		writefln("  -p  (2) Find References to text blocks defined in file 'texts.txt'.");
		writefln("  -w  (3) Write changes from 'texts.txt' using references from 'pointers.txt'.");
		writefln("");
		writefln("Examples:");
		writefln("  pmips.exe -map SLUS_006.26:800@800A0000 -f");
	}
	
	void findTextBlocks(string option) {
		//writefln("%s", option);
		auto fileName = "texts.txt";
		writef("Finding text blocks...");
		scope results = TextSearcher(mmap);
		writefln("%d found", results.length);
		writefln("Writting to '%s'...", fileName);
		scope file = new std.stream.File(fileName, FileMode.OutNew);
		foreach (result; results) {
			file.writeString(result.toString);
			file.writefln("");
			//writefln("%s", result);
		}
		file.close();		
		showHelp = false;
	}

	TextSearcher.Result[uint] extractTexts(string fileName) {
		TextSearcher.Result[uint] texts;
		writefln("Opening texts '%s'...", fileName);
		scope file = new BufferedFile(fileName);
		while (!file.eof) {
			string line = std.string.strip(cast(string)file.readLine);
			//writefln("%s", line);
			if (line.length) {
				scope matches = std.regexp.search(line, r"^([^@:]+):(\w+):'(.*)'$", "mi");
				if (matches !is null) {
					uint start = cast(uint)hexdec(matches[1]);
					uint end = start + cast(uint)hexdec(matches[2]);
					texts[start] = TextSearcher.Result(start, end, stripslashes(matches[3]));
				}
			}
		}
		return texts;
	}
	
	Patcheable[int][uint] extractPatches(string fileName) {
		Patcheable[int][uint] patches;
		uint address;
		writefln("Opening patches '%s'...", fileName);
		scope file = new BufferedFile(fileName);
		while (!file.eof) {
			string line = std.string.strip(cast(string)file.readLine);
			if (line.length) {
				// Segment.
				{
					scope matches = std.regexp.search(line, r"^([^@:\[]+):'(.*)'$", "mi");
					if (matches !is null) {
						address = cast(uint)hexdec(matches[1]);
						//writefln("%08X", address);
						//writefln("%s", line);
						//texts[cast(uint)hexdec(matches[1])] = stripslashes(matches[2]);
						continue;
					}
				}
				// Patch.
				{
					scope matches = std.regexp.search(line, r"^\s*(C|T)\[(\w+)\-(\w+)\]", "mi");
					if (matches !is null) {
						uint v0 = cast(uint)hexdec(matches[2]);
						uint v1 = cast(uint)hexdec(matches[3]);
						/*if (v0 == 0x801943A4) {
							writefln("%s:%08X-%08X", matches[1], v0, v1);
						}*/
						switch (matches[1]) {
							case "C":
								patches[address][v1] = new PatchCode(address, v0, v1, address, "");
							break;
							case "T":
								patches[address][v0] = new PatchPointer(address, v0, address, "");
							break;
						}
						continue;
						//writefln("%s", line);
						//texts[cast(uint)hexdec(matches[1])] = stripslashes(matches[2]);
					}
				}
			}
		}
		return patches;
	}
	
	void findPointers(string option) {
		auto search = new MipsPointerSearch(mmap);
		auto texts = extractTexts("texts.txt");
		writefln("Found %d texts.", texts.length);
		foreach (result; TextSearcher(mmap)) {
			if (result.start in texts) search.addAddress(result.start, result.end);
		}
		search.execute();
		//search.dump();
		scope filew = new std.stream.File("pointers.txt", FileMode.OutNew);
		foreach (address, si; search) {
			if (si.patches.length) {
				filew.writef("%08X:'", si.start);
				filew.writeString(addslashes(si.text));
				filew.writefln("'");
				foreach (patchAddress, patch; si.patches) {
					filew.writef("\t");
					filew.writeString(patch.simpleString);
					filew.writefln("");
				}
			} else {
				filew.writef("#%08X:'", address);
				filew.writeString(addslashes(si.text));
				filew.writefln("'");
				filew.writefln("\t#NOT FOUND REFERENCES!!");
			}
			filew.writefln("");
		}
		filew.close();
		showHelp = false;
	}

	void patchFile() {
		auto search  = new MipsPointerSearch(mmap);
		auto texts   = extractTexts("texts.txt");
		auto patches = extractPatches("pointers.txt");

		foreach (text; texts) {
			auto pe = new PatchEntry();
			pe.start = text.start;
			pe.end   = text.end;
			pe.text  = text.text;
			auto textAddressBase = text.start & search.valueMask;
			//writefln("%08X, %08X", patches.keys[0]);
			if (text.start in patches) {
				pe.patches = patches[text.start];
			}
			search.search[pe.start] = pe;
		}
		//writefln("%08X", patches.keys.sort[0]);
		
		MipsPointerPatch(search);
		writefln("Pached successfully");
		showHelp = false;
	}

	void addMap(string option, string value) {
		scope matches = std.regexp.search(value, r"^([^@:]+)(:([0-9a-f]*)(\-([0-9a-f]*))?)?(@([0-9a-f]+))?", "mi");
		if (matches) {
			auto file       = matches[1];
			auto file_start = hexdec(matches[3]);
			auto file_end   = hexdec(matches[5]);
			auto mem_start  = hexdec(matches[7]);
			//foreach (n; 0..8) writefln("%d: %s", n, matches[n]);
			writefln("MAP: file('%s'), file_start(0x_%08X), file_end(0x_%08X), mem_start(0x_%08X)", file, file_start, file_end, mem_start);
			string fileBack = file ~ ".bak";
			if (!std.file.exists(fileBack)) {
				writef("Backuping file '%s'->'%s'...", file, fileBack);
				std.file.copy(file, fileBack);
				writefln("Ok");
			} else {
				writef("Restoring file '%s'->'%s'...", fileBack, file);
				std.file.copy(fileBack, file);
				writefln("Ok");
			}
			
			auto stream = new std.stream.File(file, FileMode.In | FileMode.Out);
			mmap.addMap(cast(uint)mem_start, (file_end > file_start) ? (new SliceStream(stream, file_start, file_end)) : (new SliceStream(stream, file_start)));
		} else {
			writefln("MAP: Invalid format for -map option ('%s').", value);
		}
	}

	if (args.length > 1) {
		getopt(args,
			config.bundling,
			"map", &addMap,

			config.noBundling,
			"t", &findTextBlocks,
			"p", &findPointers,
			"w", &patchFile,
			"h|help", &help
		);
	} else {
		showHelp = true;
	}

	if (showHelp) {
		help();
		return -1;
	} else {
		return 0;
	}
}