import std.string;

int hex2dec(char[] s) {
	int r;
	foreach (c; s) {
		int cv;
		if (c >= '0' && c <= '9') {
			cv = c - '0';
		} else if (c >= 'a' && c <= 'f') {
			cv = c - 'a' + 10;
		} else if (c >= 'A' && c <= 'F') {
			cv = c - 'A' + 10;
		} else {
			//continue;
			break;
		}
		r *= 0x10;
		r += cv;
	}
	return r;
}

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

extern(Windows) {
	int MultiByteToWideChar(uint CodePage, uint dwFlags, char* lpMultiByteStr, int cbMultiByte, wchar* lpWideCharStr, int cchWideChar);
	int WideCharToMultiByte(uint CodePage, uint dwFlags, wchar* lpWideCharStr, int cchWideChar, char* lpMultiByteStr, int cbMultiByte, char* lpDefaultChar, int* lpUsedDefaultChar);
}

wchar[] sjis_convert_utf16(char[] data) { return convert_to_utf16(data, 932); }
char[] sjis_convert_utf8(char[] data) { return std.utf.toUTF8(sjis_convert_utf16(data)); }

wchar[] convert_to_utf16(char[] data, int codepage) {
	wchar[] out_data = new wchar[data.length * 4];
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

char[] convert_from_utf16(wchar[] data, uint codepage) {
	char[] out_data = new char[data.length * 4];
	int len = WideCharToMultiByte(
		codepage,
		0,
		data.ptr,
		data.length,
		out_data.ptr,
		out_data.length,
		null,
		null
	);
	return out_data[0..len];
}

char[] mb_convert_encoding(char[] str, int to_codepage, int from_codepage) {
	return convert_from_utf16(convert_to_utf16(str, from_codepage), to_codepage);
}

uint charset_to_codepage(char[] charset) {
	charset = replace(std.string.tolower(strip(charset)), "-", "_");
	switch (charset) {
		case "shift_jis": return 932;
		case "utf_16": return 1200;
		case "utf_32": return 12000;
		case "utf_7": return 65000;
		case "utf_8": return 65001;
		case "windows_1252", "latin_1", "iso_8859_1": return 1252;
		default: throw(new Exception("Unknown charset '" ~ charset ~ "'"));
	}
}

char[] mb_convert_encoding(char[] str, char[] to_encoding, char[] from_encoding) {
	return mb_convert_encoding(str, charset_to_codepage(to_encoding), charset_to_codepage(from_encoding));
}

import etc.c.zlib;
uint crc32(void[] data) { return etc.c.zlib.crc32(0, cast(ubyte *)data.ptr, data.length); }