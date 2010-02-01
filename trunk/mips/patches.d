module mips_patches;

import string_utils;
import std.string, std.stream, std.stdio;

abstract class Patcheable {
	string toString();
	string simpleString();
	string text;
	void patch(Stream stream, uint newValue);
}

class PatchPointer : Patcheable {
	uint value, valueRaw, valueNew;
	uint address;

	this(uint value, uint address, uint valueRaw, string text) {
		this.value    = value;
		this.valueRaw = valueRaw;
		this.address  = address;
		this.text     = text;
	}

	string toString() {
		return std.string.format("T:%08X:[%08X]:'", address, valueRaw) ~ addslashes(text) ~ "'";
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

	this(int value, int addressHi, int addressLo, int valueRaw, string text) {
		this.value     = value;
		this.valueRaw  = valueRaw;
		this.addressHi = addressHi;
		this.addressLo = addressLo;
		this.text      = text;
	}

	string toString() {
		return std.string.format("C:%08X:%08X:[%08X]:'", addressHi, addressLo, valueRaw) ~ addslashes(text) ~ "'";
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