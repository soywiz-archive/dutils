module goldengine.symbol;

import std.utf;

package int findw(wstring s, wchar c) {
	foreach (int i, wchar c2; s) if (c == c2) return i;
	return -1;
}

package wchar tolower(wchar c) {
    if (c >= 'A' && c <= 'Z') c += 32;
    return c;
}

package int ifindw(wstring s, wchar c) {
	wchar c1 = tolower(c);

	foreach (int i, wchar c2; s) {
	    c2 = tolower(c2);
	    if (c1 == c2) return i;
	}
	return -1;
}

/// Holds one symbol defined by the grammar file
/// As each symbol will only exist in one instance, the class references
/// can be compared directly
public class Symbol {
	public enum Kind {
		nonterminal  = 0, /// Normal nonterminal
		terminal     = 1, /// Normal terminal
		whitespace   = 2, /// Type of terminal
		end          = 3, /// End character (EOF)
		commentStart = 4, /// Comment start
		commentEnd   = 5, /// Comment end
		commentLine  = 6, /// Comment line
		error        = 7, /// Error symbol
	}

    int     index; /// Index into the symbol table, this corresponds to generated constants
    wstring name;  /// plain symbol character or string
    Kind    kind;  /// symbol type

    package this(int index, wstring name, Symbol.Kind kind) {
        this.index = index;
        this.name  = name;
        this.kind  = kind;
    }

    public string toString() {
        return toUTF8(toStringw);
    }

    /// Return a text representation of the symbol
    public wstring toStringw() {
        switch (kind) {
            case Symbol.Kind.nonterminal: return "<" ~ name ~ ">"; break;
            case Symbol.Kind.terminal   : return patternFormat(name); break;
            default: return "(" ~ name ~ ")"; break;
        }
    }

    /// Create a valid Regular Expression for a source string
    /// Put all special characters in single quotes
    private wstring patternFormat(wstring source) {
        const wstring quotedChars = "|-+*?()[]{}<>!";

        wstring ret;
        foreach (wchar ch; source) {
            if (ch == '\'') {
                ret ~= "''";
            } else if (findw(quotedChars, ch) >= 0) {
                ret ~= "'";
                ret ~= ch;
                ret ~= "'";
            } else {
                ret ~= ch;
			}
        }
        return ret;
    }
}
