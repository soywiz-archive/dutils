module pmips_pointersearch;

import std.stdio;

import mips_patches;
import string_utils;
import stream_aggregator;

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
		/*int round_align_min(int value, int alignv) {
			if (value % alignv) {
				return value - 
			}
		}*/
		foreach (map; mmap.maps) {
			this.data_base = map.start;
			this.data      = cast(ubyte[])map.data;
			this.code      = cast(uint[])(this.data[0..this.data.length - this.data.length % 4]);
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
			bool _show_info = false;

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

			/*if (cpos >= 0x8011FF90 && cpos <= 0x80120000) {
				_show_info = true;
				writef("%08X:", cpos);
			}*/

			// Comprueba el código de operación
			switch (cop) {
				// Saltos cortos
				case 0b000100: case 0b000101: // BEQ, BNE
					if (_show_info) writefln("BEQ/BNE");
					isbranch = true;
				break;
				case 0b000001: // BGEZ, BGEZAL, BLTZ, BLTZAL
					switch (rt) {
						case 0b00001: case 0b10001: case 0b00000: case 0b10000:
							if (_show_info) writefln("BGEZ/BGEZAL/BLTZ/BLTZAL");
							isbranch = true;
						default:
					}
				break;
				case 0b000110: case 0b000111: // BLEZ, BGTZ
					if (rt == 0) {
						if (_show_info) writefln("BLEZ/BGTZ");
						isbranch = true;
					}
				break;
				// Saltos largos
				/*case 0b000010: // J
					isbranch = true;
				break;*/
				// Carga de datos típicas (LUI + ADDI/ORI)
				case 0b001111: // LUI
					if (_show_info) writefln("LUI");
					state.rld[rt] = (imm << 16);
					state.lui[rt] = cpos;
					update = true;
				break;
				case 0b001000: case 0b001001: // ADDI/ADDIU
					if (_show_info) writefln("ADDI/ADDIU");
					state.rld[rt] = state.rld[rs] + imm;
					update = true;
				break;
				case 0b001101: // ORI
					if (_show_info) writefln("ORI");
					state.rld[rt] = state.rld[rs] | imm;
					update = true;
				break;
				default: break;
			}

			if (update) {
				state.rld[0] = 0x00000000;

				cvm = ((cv = state.rld[rt]) & valueMask);

				if (cvm in search) {
					if (_show_info) writefln("Find!");
					// Only once.
					if ((cpos in search[cvm].patches) is null) {
						if (rs != rt) {
							writefln("LUI+ADDI/ORI using several registers (%d, %d) LUI_GOOD(0x%08X), LUI_BAD(0x%08X), ADDI/ORI(0x%08X)", rs, rt, state.lui[rs], state.lui[rt], cpos);
						}
					}
					// FIXED BUG!! rt -> rs
					search[cvm].patches[cpos] = new PatchCode(cvm, state.lui[rs], cpos, cv, search[cvm].text);
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
