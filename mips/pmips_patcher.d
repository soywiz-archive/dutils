module pmips_patcher;

import std.stdio;

import mips_patches;
import rangelist;
import stream_aggregator;

import pmips_pointersearch;

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
}
