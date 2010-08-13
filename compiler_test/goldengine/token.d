module goldengine.token;

import
    goldengine.lalrstate,
    goldengine.symbol;

public class Token {
    public {
        Symbol    parentSymbol;
        wstring   text;          // readonly
        LALRState lalrState;
        Object    data;
    }

    package this(Symbol parentSymbol, wstring text) {
        this.parentSymbol = parentSymbol;
        this.text = text;
    }

	public string toString() {
		//return std.string.format("Token(%s)", mParentSymbol, text, mData);
		if (data !is null) {
			return std.string.format("%s", data);
		} else {
			return std.string.format("Token('%s')", text);
		}
	}
}
