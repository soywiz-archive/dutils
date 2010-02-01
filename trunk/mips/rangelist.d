module rangelist;

import std.stdio, std.string;

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

	Range getFreeRange(int length, long suggested_segment = -1) {
		Range[] valid_ranges;

		bool same_segment(uint addr) { return (addr & 0xFFFF0000) == (suggested_segment & 0xFFFF0000); }
			
		foreach (range; this) {
			if (range.length >= length) {
				// Return directly a range in the segment.
				if ((suggested_segment >= 0) && same_segment(range.start) && same_segment(range.end - 1)) {
					//.writefln("Find segment! on 0x%08X with length %d.", suggested_segment, length);
					return range;
				}
				// Store as a valid range.
				valid_ranges ~= range;
			}
		}

		if (suggested_segment != -1) {
			.writefln("Didn't find a segment on 0x%08X with length %d.", suggested_segment, length);
		}

		// Any segment.
		if (valid_ranges.length) return valid_ranges[0];

		// Not valid ranges.
		show();
		throw(new Exception(format("Not enough space (%d)", length)));
	}
	
	template GetReuse() {
		uint[string] stringPos;
		uint getReuse(string text, long suggested_segment = -1) {
			if ((text in stringPos) is null) {
				return stringPos[text] = getAndUse(text.length, suggested_segment);
			}
			return stringPos[text];
		}
		/**
		 * Puts all the texts all together in a segment. (64K)
		 */
		uint getReuse(string[] texts, long suggested_segment = -1) {
			string text_joined = std.string.join(texts, "");
			if ((text_joined in stringPos) is null) {
				uint start = getAndUse(text_joined.length, suggested_segment);
				assert((start & 0x_FFFF_0000) == ((start + text_joined.length) & 0x_FFFF_0000), "Texts must be together in the same segment.");
				int pos = start;
				foreach (text; texts) {
					stringPos[text] = pos;
					pos += text.length;
				}
				stringPos[text_joined] = start;
			}
			return stringPos[text_joined];
		}
	}

	mixin GetReuse;

	int getAndUse(int length, long suggested_segment = -1) {
		int start;
		use(start = getFreeRange(length, suggested_segment).start, length);
		return start;
	}

	int length() {
		int r = 0; foreach (int l; rangeStart) r += l; return r;
	}
}	