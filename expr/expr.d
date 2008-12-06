module expr;

import std.stdio, std.string, std.conv, std.ctype;

struct Value {
	union { char[] _s; real _f; } bool is_str;
	static Value opCall(char[] v) { Value vv; vv = v; return vv; }
	static Value opCall(real v  ) { Value vv; vv = v; return vv; }
	
	static char[] build_op(char[] type, char[] op) { return "Value op" ~ type ~ "(Value v) { return Value(f " ~ op ~ " v.f); }"; }
	
	mixin(build_op("Add", "+"));
	mixin(build_op("Sub", "-"));
	mixin(build_op("Mul", "*"));
	mixin(build_op("Div", "/"));
	mixin(build_op("Mod", "%"));
	
	Value opNeg() { return Value(-f); }
	
	void opAssign(char[] v) { is_str = true;  _s = v; }
	void opAssign(real v  ) { is_str = false; _f = v; }
	
	int opEquals(Value  v) { return (s == v.s); }
	int opEquals(real   v) { return (f == v  ); }
	int opEquals(char[] v) { return (s == v  ); }

	int opCmp(real   v) { return cast(int)(f - v); }
	
	long i() { return cast(long)f; }
	real f() { return is_str ? std.conv.toReal(_s) : _f; }
	alias toString s;
	
	char[] toString() { return is_str ? _s : std.string.toString(_f); }
}

class Expression {
	struct Token {
		char[] value; bool op;
		char[] toString() { return format("TOKEN: '%s' (%s)", value, op); }
	}

	Token[] tokens;
	uint tokenpos = 0;
	
	bool  more()    { return (tokenpos < tokens.length); }
	Token current() { return tokens[tokenpos]; }
	void  next()    { tokenpos++; }
	
	static Value delegate(char[])[] mapvalues;
	
	static int hexdigit(char c) {
		if (c >= '0' && c <= '9') return c - '0';
		if (c >= 'a' && c <= 'z') return c - 'a' + 10;
		if (c >= 'A' && c <= 'Z') return c - 'A' + 10;
		return -1;
	}
	
	static real number_base(char[] s, int base = 10) {
		long r = 0, decimal = 1; bool start_dec;
		foreach (pos, c; s) {
			switch (c) {
				case '.': start_dec = true; break;
				case '-': decimal *= -1; if (pos != 0) throw(new Exception("'-' not in the beggining")); break;
				default:
					int cv = hexdigit(c);
					if (cv < 0 || cv >= base) throw(new Exception(std.string.format("Invalid character '%s' in number '%s' in base '%d'", [cast(char)c], s, base)));
					r = (r * base) + cv;
					if (start_dec) decimal *= base;
				break;
			}
		}
		return (cast(real)r / cast(real)decimal);
	}
	
	static real number(char[] s) {
		if (find(s, ".") == -1) {
			if (s.length > 2 && s[0..2] == "0x") return number_base(s[2..s.length], 16);
			if (s.length > 2 && s[0..2] == "0b") return number_base(s[2..s.length], 2);
			if (s.length > 1 && s[0   ] == '0' ) return number_base(s[1..s.length], 8);
		}
		return number_base(s, 10);
	}

	static Value value(Token t) {
		Value r;
		char[] exp = t.value;
		bool found;
		
		if ((exp.length > 0) && (exp[0] < '0' || exp[0] > '9')) {
			foreach (mv; mapvalues) try { return mv(exp); } catch { }
			throw(new Exception(format("Unknown value '%s'", exp)));
		}

		return Value(number(exp));
	}

	Value exp2() { // ( num
		Value r;
		Token t = current;
		
		if (t.op) {
			switch (t.value) {
				case "(":
					next();
					r = exp0;					
					if (current.value != ")") throw(new Exception(") mismatch"));
					next();
				break;
				case "-": next(); r = -exp2; break;
				case "+": next(); r = exp0; break;
				default: throw(new Exception(std.string.format("Invalid operator '%s'", t.value)));
			}
		}
		// Numero
		else {
			next();			
			r = value(t);
			//writefln("PUSH %08X (%s) %s", r, t.value, t.op);
		}
		
		return r;
	}
	
	Value exp1() { // * /
		auto r = exp2;

		while (more) switch (current.value) {
			case "+": next(); r = r + exp0; break;
			case "-": next(); r = r - exp0; break;
			default: return r;
		}
		
		return r;
	}
	
	Value exp0() { // + -
		auto r = exp1;
		
		while (more) switch (current.value) {
			case "*": next(); r = r * exp2; break;
			case "/": next(); r = r / exp2; break;
			default: return r;
		}
		
		return r;
	}
	
	this(char[] exp) {
		int type = -1;
		char[] s;
		
		void flush(int ct = -1, bool force = false) {
			if (type != -1) {
				if (force || (type != ct && s.length)) {
					tokens ~= Token(s, (type == 1));
					s = "";
					//writefln("flush");
				}
			}
			type = ct;
		}
		
		foreach (c; std.string.tolower(exp)) {
			if (std.ctype.isspace(c)) continue;
			
			// keyword/number
			if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '.') {
				flush(0);
				s ~= c;
			}
			// operator
			else {
				flush(1, true);
				s ~= c;				
			}
		}
		
		flush();
		
		tokens ~= Token("", true);
		
		//foreach (t; tokens) t.dump();
	}
}

static Value evaluate(char[] exp, Value delegate(char[])[] mapvalues = null) {
	//auto obj = new typeof(this)(exp);
	auto obj = new Expression(exp);
	obj.mapvalues = mapvalues;
	return obj.exp0;
}

static Value evaluate(char[] exp, Value delegate(char[]) mapvalue) {
	return evaluate(exp, [mapvalue]);
}

unittest {	
	assert(evaluate("1+2*3+1") == (1+2*3+1));
	assert(evaluate("-1+2*x+1", delegate Value(char[] name) { return Value(-5.3); }) == (-1+2*(-5.3)+1));
}

/*
void main() {
	writefln(evaluate("1+2*3+1", delegate Value(char[] name) {
		//writefln(name);
		return Value(-11.5);
	}));
}
*/
