module rangelist;

import std.stdio, std.string;

struct Range {
	uint start, end;
	uint length() { return end - start; }
	string toString() { return std.string.format("%08X-%08X(%04d)", start, end, length); }
}

interface IRangeList {
	uint showSummary();
	void add(int from, int length);
	void addEnd();
	uint getReuse(string text, long affinitySegment = -1);
	uint getReuse(string[] texts, long affinitySegment = -1);
	int  opApply(int delegate(ref Range) dg);
}

abstract class RangeListBase : IRangeList {
	Range[uint] ranges;
	Range[uint] rangesEnd;

	void addEnd() {
		//show();
	}
	
	int opApply(int delegate(ref Range) dg) {
		int result = 0;
		foreach (start; ranges.keys.sort) {
			result = dg(ranges[start]);
			if (result) break;
		}
		return result;
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

	void add(Range range) {
		void combineCreatedRange(Range middleRange) {
			Range lowerRange = void, upperRange = void, combinedRange = void;

			if (middleRange.start in rangesEnd) {
				lowerRange = rangesEnd[middleRange.start];
				combinedRange = Range(lowerRange.start, middleRange.end);

				//writefln("LOW: [%s :: %s] --> %s", lowerRange, middleRange, combinedRange);

				remove(lowerRange);
				remove(middleRange);
				add(combinedRange);
			}

			if (middleRange.end in ranges) {
				upperRange = ranges[middleRange.end];
				combinedRange = Range(middleRange.start, upperRange.end);
				
				//writefln("UPP: [%s :: %s] --> %s", middleRange, upperRange, combinedRange);

				remove(middleRange);
				remove(upperRange);
				add(combinedRange);
			}
		}

		if (range.length > 0) {
			ranges[range.start]  = range;
			rangesEnd[range.end] = range;
			combineCreatedRange(range);
		}
	}

	void add(int from, int length) {
		add(Range(from, from + length));
	}

	void use(int from, int length) {
		Range range = ranges[from];
		remove(range);
		add(Range(range.start + length, range.end));
	}

	void remove(Range range) {
		ranges.remove(range.start);
		rangesEnd.remove(range.end);
	}
}

class RangeList : RangeListBase {
	Range getFreeRange(int length, long affinitySegment = -1) {
		Range[] valid_ranges;
		
		foreach (range; this) {
			if (range.length >= length) {
				// Return directly a range in the segment.
				if (hasAffinity(range.start, affinitySegment) && hasAffinity(range.end - 1, affinitySegment)) {
					//.writefln("Find segment! on 0x%08X with length %d.", affinitySegment, length);
					return range;
				}
				// Store as a valid range.
				valid_ranges ~= range;
			}
		}

		if (affinitySegment != -1) {
			.writefln("Didn't find a segment on 0x%08X with length %d.", affinitySegment, length);
		}

		// Any segment.
		if (valid_ranges.length) return valid_ranges[0];

		// Not valid ranges.
		show();
		throw(new Exception(format("Not enough space (%d)", length)));
	}

	bool hasAffinity(uint address, long affinitySegment = -1, uint affinityMask = 0x_8FFF_0000) {
	//bool hasAffinity(uint address, long affinitySegment = -1, uint affinityMask = 0x_FFFF_0000) {
		if (affinitySegment == -1) return true;
		return (address & affinityMask) == (affinitySegment & affinityMask);
	}
	
	template GetReuse() {
		uint[][string] stringPos;

		private uint getReuseInternal(string text, long affinitySegment = -1) {
			foreach (address; stringPos[text]) if (hasAffinity(address, affinitySegment)) return address;
			return stringPos[text][0];
		}

		uint getReuse(string text, long affinitySegment = -1) {
			if ((text in stringPos) is null) {
				//writefln("getReuse()(%s)(%d)", text, text.length);
				stringPos[text] ~= getAndUse(text.length, affinitySegment);
			}
			return getReuseInternal(text);
		}
		/**
		 * Puts all the texts all together in a segment. (64K)
		 */
		uint getReuse(string[] texts, long affinitySegment = -1) {
			string text_joined = std.string.join(texts, "");
			if ((text_joined in stringPos) is null) {
				//writefln("getReuse[](%s)(%d) : %s", text_joined, text_joined.length, texts);
				uint start = getAndUse(text_joined.length, affinitySegment);
				if (!hasAffinity(start, start + text_joined.length - 1)) throw(new Exception("Texts must be together in the same segment."));
				int pos = start;
				foreach (text; texts) {
					stringPos[text] ~= pos;
					pos += text.length;
				}
				stringPos[text_joined] ~= start;
			}
			return getReuseInternal(text_joined);
		}
	}

	mixin GetReuse;

	int getAndUse(int length, long affinitySegment = -1) {
		int start;
		//writefln("getAndUse(%d)", length);
		use(start = getFreeRange(length, affinitySegment).start, length);
		return start;
	}

	int length() {
		int r = 0;
		foreach (ref range; ranges) r += range.length;
		return r;
	}
}	