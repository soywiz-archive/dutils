module goldengine.rule;

import goldengine.symbol;

import std.utf;

public class Rule {
    int      index;       /// Index into the rule table, this corresponds to the generated constants
    Symbol   ntSymbol;    /// Rule nonterminal
    Symbol[] ruleSymbols; /// Rule handle

    package this(int index, Symbol ntSymbol) {
        this.index    = index;
        this.ntSymbol = ntSymbol;
    }

    /// Does this rule consist of a single nonterminal?
    public bool oneNT() {
        return (ruleSymbols.length == 1) && (ruleSymbols[0].kind == Symbol.Kind.nonterminal);
    }

    public string toString() {
        return toUTF8(toStringw);
    }

    ///Get a string representation of this rule
    public wstring toStringw() {
        wstring result = ntSymbol.toStringw ~ " ::= ";
        foreach (sym; ruleSymbols) result ~= sym.toStringw ~ " ";
        return result;
    }
}
