module goldengine.dfastate;

import goldengine.symbol;

package struct DFAEdge {
	int charsetIdx;
	int targetStateIdx;

	public static DFAEdge opCall(int charsetIdx, int targetStateIdx) {
		DFAEdge ret;
		ret.charsetIdx = charsetIdx;
		ret.targetStateIdx = targetStateIdx;
		return ret;
	}
}

package struct DFAState {
	int       index;
	bool      acceptState;
	Symbol    acceptSymbol;
	DFAEdge[] edges;

	public static DFAState opCall(int index, bool acceptState, Symbol acceptSymbol) {
		DFAState ret;
		ret.index = index;
		ret.acceptState = acceptState;
		ret.acceptSymbol = acceptSymbol;
		return ret;
	}

	public int findEdge(wchar c, wstring[] charsetTable, bool caseSensitive) {
		auto func_findw = caseSensitive ? &findw : &ifindw;
		foreach (ref e; edges) if (func_findw(charsetTable[e.charsetIdx], c) >= 0) return e.targetStateIdx;
		return -1;
	}
}
