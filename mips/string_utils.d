module string_utils;

static addslashes(string i) {
	char[char] map = ['\a' : 'a', '\b' : 'b', '\n' : 'n', '\r' : 'r', '\t' : 't', '\v' : 'v', '\\' : '\\', '"' : '"', '\'' : '\''];
	string r;
	foreach (c; i) r ~= ((c in map) !is null) ? ['\\', map[c]] : [c];
	return r;
}

static stripslashes(string i) {
	char[char] map = ['a' : '\a', 'b' : '\b', 'n' : '\n', 'r' : '\r', 't' : '\t', 'v' : '\v', '\\' : '\\', '"' : '"', '\'' : '\''];
	string r;
	for (int n = 0; n < i.length; n++) r ~= (i[n] == '\\') ? map[i[++n]] : i[n];
	return r;
}

long hexdec(string s) {
	if (s.length && s[0] == '-') return -hexdec(s[1..$]);
	long value;
	foreach (c; s) {
		int digit;
		if (c == '_') continue;
			 if (c >= '0' && c <= '9') digit = c - '0';
		else if (c >= 'a' && c <= 'f') digit = c - 'a' + 10;
		else if (c >= 'A' && c <= 'F') digit = c - 'A' + 10;
		value *= 16;
		value += digit;
	}
	return value;
}

unittest {
	assert(hexdec("10") == 0x10);
	assert(hexdec("-ff") == -0xff);
}
