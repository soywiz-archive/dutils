module pmips_textsearch;

import stream_aggregator;
import string_utils;

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
			
			int count_total    = text.length;
			int count_special  = 0;
			int count_spaces   = 0;
			int count_symbol   = 0;
			int count_nonalpha = 0;
			int count_alpha    = 0;
			
			foreach (c; text) {
				if (c < 0x20) {
					//return false;
					count_special++;
					count_nonalpha++;
				} else if (c == 0x20) {
					count_spaces++;
					count_nonalpha++;
				} else if (!std.ctype.isalpha(c)) {
					count_symbol++;
					count_nonalpha++;
				} else {
					count_alpha++;
				}
				if (c > 0x7F) return false;
			}

			real per_spaces   = cast(real)count_spaces    / cast(real)count_total;
			real per_special  = cast(real)count_special   / cast(real)count_total;
			real per_symbol   = cast(real)count_symbol    / cast(real)count_total;
			real per_nonalpha = cast(real)count_nonalpha  / cast(real)count_total;
			real per_alpha    = cast(real)count_alpha     / cast(real)count_total;

			if (count_total < 5 && per_spaces    >= 0.4) return false;
			if (count_total > 0 && per_special   >= 0.3) return false;
			if (count_total < 5 && per_symbol    >= 0.4) return false;
			if (count_total < 5 && per_nonalpha  >= 0.4) return false;
			if (count_total < 4 && per_alpha < 1.0) return false;

			//0x801b36a4

			for (int n = end; ((n % 4) != 0); n++) {
				if (end >= data.length) return false;
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
