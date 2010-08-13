module test;

import std.stdio;
import std.file;
import std.stream;
import goldengine.goldparser;

class Node {
	Rule rule;
	Token[] tokens;
	public this(Rule rule, Token[] tokens) {
		this.rule = rule;
		this.tokens = tokens;
	}
	
	void dumpTree(int level = 0) {
		if (tokens.length != 1) writefln("-- %s", rule);
		foreach (token; tokens) {
			for (int n = 0; n < level; n++) writef("  ");
			auto node = cast(Node)token.data;
			if (node is null) {
				writefln("'%s' (%s)", token.text, token.parentSymbol);
			} else {
				if (tokens.length == 1) {
					node.dumpTree(level);
				} else {
					node.dumpTree(level + 1);
				}
			}
		}
	}
	
	public string toString() {
		if (tokens.length == 1) {
			return std.string.format("%s", tokens[0]);
		} else {
			return std.string.format("%s", tokens);
		}
	}
}

void main() {
	auto grammar = new Grammar(std.file.read("C-ANSI.cgt"));
	auto parser = new GOLDParser(grammar);
	parser.loadSource(new BufferedFile("test.c"));
	parser.onProgress = delegate void(int line, int sourcePos, int sourceSize) {
		//writefln("%d, %d, %d", line, sourcePos, sourceSize);
	};
	parser.onReduce = delegate Object(Rule rule, Token[] tokens) {
		return new Node(rule, tokens);
	};
	parser.onAccept = delegate void(Object reduction) {
		auto node = cast(Node)reduction;
		//writefln("%s", reduction);
		node.dumpTree();
	};
	parser.parse();
	writefln("line: %d, sourceSize: %d", parser.line, parser.sourceSize);
}