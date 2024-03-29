module pmips_patcher;

import std.stdio, std.algorithm;

import mips_patches;
import rangelist;
import stream_aggregator;

import pmips_pointersearch;

class MipsPointerPatch {
	IRangeList ranges;
	PatchEntry[int] search;
	StreamAggregator mmap;

	this(PatchEntry[int] search) {
		this.search = search;
		this.ranges = new RangeList();
		foreach (pentry; search) {
			//writefln("pentry: %08X.%08X", pentry.start, pentry.length);
			this.ranges.add(pentry.start, pentry.length);
		}
		this.ranges.addEnd();
		
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
		
		PatchCode[][uint] code_patches_sorted_by_lui;
		Patcheable[] text_patches;

		void prepare_patches() {
			foreach (pentry; search) {
				text_count++;
				foreach (patch; pentry.patches) {
					PatchCode pcode = cast(PatchCode)patch;
					patch.text = pentry.text ~ '\0';
					patch_count++;
					if (pcode) {
						code_patches_sorted_by_lui[pcode.addressHi] ~= pcode;
					} else {
						text_patches ~= patch;
					}
				}
			}
			writefln("texts(%d) patches(%d)", text_count, patch_count);
		}
		
		void check_reused_lui() {
			foreach (patches; LUI) {
				//const LUI_MASK = 0x_FFFF_0000;
				const LUI_MASK = 0x_8FFF_0000;
				//const LUI_MASK = 0x_FFFF_FFFF;
				if (patches.length >= 2) {
					bool error = false;
					foreach (patch; patches[1..$]) if ((patch.valueNew & LUI_MASK) != (patches[0].valueNew & LUI_MASK)) { error = true; break; }
					if (error) {
						writefln("ERROR: Reused LUI with different value {");
						foreach (patch; patches) {
							writefln("  NewTextSegment(%08X) | %s", patch.valueNew & LUI_MASK, patch);
						}
						writefln("}");
					}
					globalError |= error;
				}
			}
		}
		
		void patch_actually_new() {
			void dopatch(Patcheable patch) {
				patch.valueNew = ranges.getReuse(patch.text, patch.valueRaw);
				try {
					mmap.position = patch.valueNew;
					mmap.writeString(patch.text);
				} catch (Exception e) {
					writefln("POS(%08X) TEXT.length(%d)", patch.valueNew, patch.text.length);
					throw(e);
				}
				patch.patch(mmap, patch.valueNew);
			}
			writefln("Patching code instructions (HI(LUI)+LO(ORI/ADDI))...");
			foreach (lui_addr, patches; code_patches_sorted_by_lui) {
				if (!patches.length) throw(new Exception("!patches.length"));
				string[] text_list; foreach (patch; patches) text_list ~= patch.text;

				try {
					//writefln("%08X : <<%s>>", patches[0].valueRaw, text_list);
					ranges.getReuse(
						text_list,
						patches[0].valueRaw      // Use this segment if possible.
					);
				} catch (Exception e) {
					writefln(
						"Warning: Didn't been able to put '%s' CONTIGUOUS in the same segment affinity with 0x%08X. Will try to use same segment afinity without being contiguous.",
						std.string.join(text_list, ""),
						patches[0].valueRaw
					);
				}

				foreach (patch; patches) {
					dopatch(patch);
				}
			}

			writefln("Patching text instructions (32-bits)...");
			foreach (patch; text_patches) dopatch(patch);
		}

		prepare_patches();
		patch_actually_new();
		check_reused_lui();
		
		this.ranges.showSummary();
		//assert(!globalError);
	}

	void execute() {
		//searchReusedLUIs(true);
		
		searchReusedLUIs(false);
		cleanSegments();
		patch();
		mmap.clearCache();
	}
}
