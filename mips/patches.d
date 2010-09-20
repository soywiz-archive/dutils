module mips_patches;

import string_utils;
import std.string, std.stream, std.stdio;

abstract class Patcheable {
	uint value, valueRaw, valueNew; // Pointee
	uint address; // Pointer address
	string text;

	string toString();
	string simpleString();
	void patch(Stream stream, uint newValue);
}

class PatchPointer : Patcheable {
	this(uint value, uint address, uint valueRaw, string text) {
		this.value    = value;
		this.valueRaw = valueRaw;
		this.address  = address;
		this.text     = text;
	}

	string toString() {
		return std.string.format("T:%08X:[%08X->%08X]:'", address, valueRaw, valueNew) ~ addslashes(text) ~ "'";
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
	alias address addressHi;
	uint addressLo;

	this(int value, int addressHi, int addressLo, int valueRaw, string text) {
		this.value     = value;
		this.valueRaw  = valueRaw;
		this.addressHi = addressHi;
		this.addressLo = addressLo;
		this.text      = text;
	}

	string toString() {
		return std.string.format("C:%08X:%08X:[%08X->%08X]:'", addressHi, addressLo, valueRaw, valueNew) ~ addslashes(text) ~ "'";
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
		static bool[uint] rememberLUIs;
		uint HI, LO;
		uint HI_back, LO_back;
		uint oldValue = -1;
		
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

		if (addressHi == 0x8011FC2C) {
			//writefln("new:%08X", valueNew);
		}
		
		read(addressHi, HI); HI_back = HI;
		read(addressLo, LO); LO_back = LO;
		oldValue = ((HI >> 0) & 0xFFFF) << 16;
		{
			patchMIPSLoadAdress(HI, LO, valueNew);
		}
		if ((HI != HI_back) || (addressHi in rememberLUIs)) {
			if ((addressHi in rememberLUIs) && (HI != HI_back)) {
				writefln(" :: (Error) :: Modified a LUI with several values");
			}
			rememberLUIs[addressHi] = true;
			writefln("  :: (Warning) :: Modified LUI at 0x%08X for ADDI/ORI at 0x%08X :: value(0x%08X->0x%08X)", addressHi, addressLo, oldValue, valueNew);
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