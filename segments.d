import std.string;

T min(T)(T a, T b) { return (a < b) ? a : b; }
T max(T)(T a, T b) { return (a > b) ? a : b; }

class Segments {
	static class Segment {
		long l, r;
		long w() { return r - l; }
		alias w length;
		static bool intersect(Segment a, Segment b, bool strict = false) {
			return (strict
				? (a.l <  b.r && a.r >  b.l)
				: (a.l <= b.r && a.r >= b.l)
			);
		}
		bool valid() { return w >= 0; }
		static Segment opCall(long l, long r) {
			auto v = new Segment;
			v.l = l;
			v.r = r;
			return v;
		}
		int opCmp(Object o) { Segment that = cast(Segment)o;
			long r = this.l - that.l;
			if (r == 0) r = this.r - that.r;
			return cast(int)r;
		}
		bool opEquals(Object o) { Segment that = cast(Segment)o; return (this.l == that.l) && (this.r == that.r); }
		void grow(Segment s) {
			l = min(l, s.l);
			r = max(r, s.r);
		}
		string toString() { return format("(%08X, %08X)", l, r); }
	}
	Segment[] segments;
	void refactor() {
		segments = segments.sort;
		/*
		Segment[] ss = segments; segments = [];
		foreach (s; ss) if (s.valid) segments ~= s;
		*/
	}
	
	long length() { return segments.length; }
	Segment opIndex(int idx) { return segments[idx]; }

	template Operations() {
		Segments opAddAssign(Segment s) {
			foreach (cs; segments) {
				if (Segment.intersect(s, cs)) {
					cs.grow(s);
					goto end;
				}
			}
			segments ~= s;

			end: refactor(); return this;
		}
		
		Segments opSubAssign(Segment s) {
			Segment[] ss;
			
			void addValid(Segment s) { if (s.valid) ss ~= s; }

			foreach (cs; segments) {
				if (Segment.intersect(s, cs)) {
					addValid(Segment(cs.l, s.l ));
					addValid(Segment(s.r , cs.r));
				} else {
					addValid(cs);
				}
			}
			segments = ss;

			end: refactor(); return this;
		}
	}

	template Allocation() {
		long allocate(uint size) {
		}

		long[void[]] positions;
		long allocateDataOnce(void[] data) {
			if ((data in positions) is null) positions[data] = allocate((cast(ubyte[])data).length);
			return positions[data];
		}
	}

	mixin Operations;
	mixin Allocation;

	string toString() { string r = "Segments {\n"; foreach (s; segments) r ~= "  " ~ s.toString ~ "\n"; r ~= "}"; return r; }

	unittest {
		auto ss = new Segments;
		ss += Segment(0, 100);
		ss += Segment(50, 200);
		ss += Segment(-50, 0);
		ss -= Segment(0, 50);
		ss -= Segment(0, 75);
		ss += Segment(-1500, -100);
		ss -= Segment(-1000, 1000);
		assert(ss.length == 1);
		assert(ss[0] == Segment(-1500, -1000));
	}
}