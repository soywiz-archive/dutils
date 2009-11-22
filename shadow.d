import std.stdio, std.math;

class Matrix(T) {
	T[] data;
	int w, h;

	this(int w, int h) {
		this.data = new T[w * h];
		this.w = w;
		this.h = h;
	}
	
	this(T[][] v) {
		w = v[0].length;
		h = v.length;
		data = new T[w * h];
		for (int y = 0, n = 0; y < h; y++) {
			for (int x = 0; x < w; x++, n++) {
				data[n] = v[y][x];
			}
		}
	}
	
	T* pos(int x, int y) {
		assert(x >= 0 && x < w);
		assert(y >= 0 && y < h);
		return &data[y * h + x];
	}
	
	T get(int x, int y) {
		return *pos(x, y);
	}
	
	T set(int x, int y, T v) {
		return *pos(x, y) = v;
	}
	
	char[] toString() {
		char[] r = "";
		for (int y = 0; y < h; y++) {
			if (y != 0) r ~= "\n";
			for (int x = 0; x < w; x++) {
				if (x != 0) r ~= ", ";
				r ~= std.string.format("%s", get(x, y));
			}
		}
		return r;
	}
}

class Shadow {
	static struct Vec {
		int x, y;
		int length() { return cast(int)sqrt(cast(float)(x * x + y * y)); }
		static public Vec opCall(int x, int y) { Vec v = void; v.x = x; v.y = y; return v; }
		char[] toString() { return std.string.format("(%d, %d)", x, y); }
		int opCmp(Vec that) {
			if (that.x == 0 && that.y == 0) return -1;
			if (this.x == 0 && this.y == 0) return +1;
			return this.length - that.length;
		}
	}
	static Matrix!(int) distCalc(Matrix!(bool) mask) {
		auto r = new Matrix!(int)(mask.w, mask.h);
		auto v = new Matrix!(Vec)(mask.w, mask.h);
		int dist = 0;
		
		void putIfBetter(int x, int y, Vec c) {
			if (c < v.get(x, y)) v.set(x, y, c);
		}
		
		void process(int x, int y) {
			if (mask.get(x, y)) {
				dist = 0;
			} else {
				dist++;
				putIfBetter(x, y, Vec(dist, 0));
			}
		}

		for (int y = 0; y < mask.h; y++) {
			dist = 0; for (int x = 0         ; x <  mask.w; x++) process(x, y);
			dist = 0; for (int x = mask.w - 1; x >= 0     ; x--) process(x, y);
		}

		for (int x = 0; x < mask.w; x++) {
			dist = 0; for (int y = 0         ; y <  mask.h; y++) process(x, y);
			dist = 0; for (int y = mask.h - 1; y >= 0     ; y--) process(x, y);
		}
		
		// Interpolate.
		// TODO.
		
		writefln(v);
		writefln(mask);

		return r;
	}
}

void main() {
	bool[][] mask = [
		[1, 0, 0, 0, 1, 0, 0, 0],
		[0, 0, 0, 0, 0, 0, 0, 0],
		[0, 0, 0, 1, 0, 0, 0, 0],
		[0, 0, 1, 1, 1, 0, 0, 0],
		[0, 0, 1, 1, 1, 1, 1, 0],
		[0, 0, 0, 1, 1, 1, 0, 0],
		[0, 0, 0, 1, 1, 0, 0, 1],
		[0, 0, 0, 0, 1, 1, 1, 1],
	];
	Shadow.distCalc(new Matrix!(bool)(mask));
}