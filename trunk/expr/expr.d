module expr;

import std.stdio, std.string, std.conv, std.ctype, std.traits;

class Value {
	enum Type {
		NULL,
		STRING,
		REAL,
		NATIVE_FUNC,
	}
	
	alias Value delegate(Value[]) FUNC_CALLBACK;

	private union {
		char[] _s;
		real _f;
		FUNC_CALLBACK _native_func;
	}
	
	Type type;
	
	static char[] build_call(char[] type) { return "static Value opCall(" ~ type ~ " v) { auto vv = new Value; vv.set(v); return vv; }"; }
	mixin(build_call("char[]"));
	mixin(build_call("real"));
	mixin(build_call("FUNC_CALLBACK"));
	mixin(build_call("Value"));
	
	static Value opCall() { auto vv = new Value; vv.type = Type.NULL; return vv; }
	
	static char[] build_op(char[] type, char[] op) { return "Value op" ~ type ~ "(Value v) { return Value(f " ~ op ~ " v.f); }"; }
	mixin(build_op("Add", "+"));
	mixin(build_op("Sub", "-"));
	mixin(build_op("Mul", "*"));
	mixin(build_op("Div", "/"));
	mixin(build_op("Mod", "%"));
	
	Value opNeg() { return Value(-f); }
	
	void set(char[] v) { type = Type.STRING;  _s = v; }
	void set(real v  ) { type = Type.REAL  ; _f = v; }
	void set(FUNC_CALLBACK v) { type = Type.NATIVE_FUNC; _native_func = v; }
	void set(Value v) { type = v.type; _f = v._f; }
	
	void opAssign(char[] v) { set(v); }
	void opAssign(real v) { set(v); }
	void opAssign(FUNC_CALLBACK v) { set(v); }
	//void opAssign(Value v) { set(v); }
	
	int opEquals(Value  v) { return (s == v.s); }
	int opEquals(real   v) { return (f == v  ); }
	int opEquals(char[] v) { return (s == v  ); }

	int opCmp(real   v) { return cast(int)(f - v); }
	
	long i() { return cast(long)f; }
	real f() { return (type == Type.REAL) ? _f : std.conv.toReal(_s); }
	alias toString s;
	
	Value call(Value[] params) {
		assert(type == Type.NATIVE_FUNC, "Value must be a function type");
		return _native_func(params);
	}
	
	char[] toString() {
		switch (type) {
			case Type.REAL: return std.string.toString(_f);
			case Type.NULL: return "null";
			default: return _s;
		}
	}
}

class Expression {
	struct Token {
		enum Type {
			none,
			number,
			identifier,
			operator,
			space,
			end,
		}
		Type type;
		char[] value;
		bool op() { return (type == Type.operator); }
		char[] toString() { return format("TOKEN: '%s' (%d)", value, type); }
	}

	Token[] tokens;
	uint tokenpos = 0;
	
	bool  more()    { return (tokenpos < tokens.length); }
	Token current() { return tokens[tokenpos]; }
	void  next()    { tokenpos++; }
	void  prev()    { tokenpos--; }
	
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
			foreach (mv; mapvalues) try { auto v = mv(exp); assert(v !is null); return v; } catch { }
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
					assert(current.value == ")", ") mismatch");
					next();
				break;
				case "-": next(); r = -exp2; break;
				case "+": next(); r = exp0; break;
				default: throw(new Exception(std.string.format("Invalid operator '%s'", t.value)));
			}
		}
		// Valor
		else {
			next();
			r = value(t);
			
			switch (current.value) {
				case "++", "--":
					auto r2 = Value(r);
					switch (current.value) {
						case "++": r.set(r.f + 1); break;
						case "--": r.set(r.f - 1); break;
					}
					next();
					r = r2;
				break;
				// Function call
				/*
				case "(":
				break;
				*/
				default:
				break;
			}
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
		alias Token.Type Type;
		Token token;
		bool space;
		
		void push(Type type) {
			token.type = type;
			tokens ~= token;
			token.value = "";
		}
		
		char[][] ops;
		
		ops ~= "++";
		ops ~= "--";
		ops ~= "(";
		ops ~= ")";
		ops ~= "+";
		ops ~= "-";
		ops ~= "*";
		ops ~= "/";
		ops ~= "%";
		
		exp ~= "\0\0\0";
		for (int n = 0;; n++) {
			char c = exp[n]; if (c == '\0') break;
			if (isspace(c)) { space = true; continue; }
			
			if (isalnum(c) || c == '_') {
				// number
				if (isdigit(c) || c == '.') {
					for (;; n++) { c = std.ctype.tolower(exp[n]);
						bool exit = true;
						if (isdigit(c) || c == '.') exit = false;
						if (token.value.length == 1 && (c == 'b' || c == 'x')) exit = false;
						if (c >= 'a' && c <= 'f') exit = false;
						if (exit) break;
						
						token.value ~= c;
					}
					n--;
					push(Type.number);
				}
				// op
				else {
					for (;; n++) { c = exp[n];
						if (!isalnum(c) && c != '_') break;
						token.value ~= c;
					}
					n--;
					push(Type.identifier);
				}
			} else {
				foreach (op; ops) {
					if (op == exp[n..n + op.length]) {
						token.value = op;
						push(Type.operator);
						n += op.length - 1;
						break;
					}
				}
			}
		}
		
		push(Type.end);
		
		//writefln(tokens);
		
		//flush();
		
		//tokens ~= Token("", true);
		
		//assert(0 == 1);
		
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
