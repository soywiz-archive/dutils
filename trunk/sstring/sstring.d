import std.string;

bool starts_with(char[] a, char[] b) {
	if (a.length < b.length) return false;
	return a[0..b.length] == b[0..b.length];
}

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


// SJIS

// http://msdn.microsoft.com/en-us/library/ms776413(VS.85).aspx
// http://msdn.microsoft.com/en-us/library/ms776446(VS.85).aspx
// http://www.microsoft.com/globaldev/reference/dbcs/932.mspx

extern(Windows) int MultiByteToWideChar(uint CodePage, uint dwFlags, char* lpMultiByteStr, int cbMultiByte, wchar* lpWideCharStr, int cchWideChar);

wchar[] sjis_convert_utf16(char[] data, int codepage = 932) {
	wchar[] out_data = new wchar[data.length  * 2];
	int len = MultiByteToWideChar(
		codepage,
		0,
		data.ptr,
		data.length,
		out_data.ptr,
		out_data.length
	);
	return out_data[0..len];
}

char[] sjis_convert_utf8(char[] data, int codepage = 932) {
	return std.utf.toUTF8(sjis_convert_utf16(data, codepage));
}