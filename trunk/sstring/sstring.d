import std.string;

char[] substr(char[] s, int from, int length = 0x7FFFFFFF) {
	if (from < 0) from += s.length; if (from < 0 || from >= s.length) return "";
	int to = (length < 0) ? (s.length + length) : (from + length);
	if (to > s.length) to = s.length;
	return (from <= to) ? s[from..to] : "";
}

char[][] explode(char[] delim, char[] str, int length = 0x7FFFFFFF, bool fill = false) {
	char[][] rr;
	char[] str2 = str;

	while (true) {
		int pos = find(str2, delim);
		if (pos != -1) {
			if (rr.length < length - 1) {
				rr ~= str2[0..pos];
				str2 = str2[pos + 1..str2.length];
				continue;
			}
		}
		
		rr ~= str2;
		break;
	}
	
	if (fill && length < 100) while (rr.length < length) rr ~= "";
	
	return rr;
}

char[] ltrim(char[] str, bool* z) {
	char* s = str.ptr, se = str.ptr + str.length;
	for (; s < se && z[*s]; s++) { }
	return s[0..se - s];
}

char[] rtrim(char[] str, bool* z) {
	return str;
}

char[] ltrim(char[] str, char[] delims = " \t\r\n") {
	bool[0x100] delims_b; foreach (c; delims) delims_b[] = true;
	return ltrim(str, delims_b.ptr);
}

char[] rtrim(char[] str, char[] delims = " \t\r\n") {
	bool[0x100] delims_b; foreach (c; delims) delims_b[] = true;
	return rtrim(str, delims_b.ptr);
}

char[] trim(char[] str, char[] delims = " \t\r\n") {
	bool[0x100] delims_b; foreach (c; delims) delims_b[] = true;
	return rtrim(ltrim(str, delims_b.ptr), delims_b.ptr);
}

version (UNIT_TEST) {
	import std.stdio;
	void main() {
		writefln("'%s'", trim("     hola, esto es una prueba"));
	}
}