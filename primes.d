module primes;

import std.stdio, std.string, std.math, std.stream, std.file, std.conv, std.bigint, std.bitmanip;

alias BigInt big;

class Prime {
	static struct Factors {
		struct Factor {
			big value;
			uint count;
		}

		Factor[string] factors;
		static string hash(big value) { return value.toString; }
		//Factor[big] factors;
		//static big hash(big value) { return value; }

		uint opIndex(big value) {
			if (hash(value) in factors) return factors[hash(value)].count;
			return 0;
		}

		void opIndexAssign(uint count, big value) {
			factors[hash(value)] = Factor(value, count);
		}

		int opApply(int delegate(ref big, ref uint) dg) {
			int result = 0;
			foreach (ref factor; factors) {
				result = dg(factor.value, factor.count);
				if (result) break;
			}
			return result;
		}

		big value() {
			big r = 1;
			foreach (factor; factors) for (uint n = 0; n < factor.count; n++) r *= factor.value;
			return r;
		}

		string toString() {
			string[] r;
			foreach (value, count; this) {
				r ~= std.string.format("%s^%d", value.toString, count);
			}
			if (!r.length) return "1";
			return std.string.join(r, " * ");
		}
	}

	static ulong[] _list;
	private static void calculate(uint upTo = 10_000_000) {
		_list = [];
		scope BitArray array; for (int i = 0; i < upTo; i++) array ~= true;
		for (int i = 2; i < upTo; i++) if (array[i]) for(int j = i * 2; j < upTo; j += i) array[j] = false;
		for (int i = 2; i < upTo; i++) if (array[i]) _list ~= i;
	}
	static ulong[] list() {
		if (!_list.length) calculate();
		return _list;
	}
	static Factors factorize(big value) {
		Factors factors;
		bool test3 = (value > big("99999999999999"));
		foreach (prime; Prime.list) {
			big bigprime = prime;
			int count = 0;
			while ((value % bigprime) == 0) {
				value /= prime;
				count++;
			}
			if (count > 0) {
				factors[bigprime] = count;
			}
			if (bigprime * bigprime >= value) break;
			if (test3 && (bigprime * bigprime * bigprime >= value)) break;
		}
		if (value != 1) factors[value] = 1;
		return factors;
	}
	
	static big commonMinimumMultiple(big[] values) {
		Factors finalfactors;
		foreach (value; values) {
			auto factors = factorize(value);
			foreach (value, count; factors) {
				if (count > finalfactors[value]) finalfactors[value] = count;
			}
		}
		return finalfactors.value;
	}
	
	static big greatestCommonDivisor(big[] values) {
		Factors finalfactors = factorize(values[0]);
		foreach (value; values[1..$]) {
			auto factors = factorize(value);
			foreach (value, count; finalfactors) {
				if (factors[value] < count) finalfactors[value] = count;
			}
		}
		return finalfactors.value;
	}
}