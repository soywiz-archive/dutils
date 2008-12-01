char[] substr(char[] s, int from, int length = 0x7FFFFFFF) {
	if (from < 0) from += s.length; if (from < 0 || from >= s.length) return "";
	int to = (length < 0) ? (s.length + length) : (from + length);
	if (to > s.length) to = s.length;
	return (from <= to) ? s[from..to] : "";
}

char[][] explode(char[] delim, char[] str, int length = 0x7FFFFFFF) {
	int dl = delim.length;

	char[][] rr;

	char* s = str.ptr, se = str.ptr + str.length - dl, sp = s;
	
	if (length-- > 1) {
		while (s <= se) {
			if (s[0..dl] == delim[0..dl] || s == se) {
				rr ~= sp[0..s - sp];
				s += dl;
				sp = s;
				if (rr.length >= length) break;
			} else {
				s++;
			}
		}
	}
	
	rr ~= sp[0..se - sp + 1];
	
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