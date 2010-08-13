module test;

import std.stdio;
import std.file;
import std.stream;
import goldengine.goldparser;

public class Node {
	Rule rule;
	Token[] tokens;
	
	public this() {
	}

	public this(Rule rule, Token[] tokens) {
		this.rule = rule;
		this.tokens = tokens;
	}
	
	void dumpTree(int level = 0) {
		//if (tokens.length != 1)
		{
			for (int n = 0; n < level - 1; n++) writef("  ");
			writefln("-- %s", rule);
		}
		foreach (token; tokens) {
			auto node = cast(Node)token.data;
			if (node is null) {
				for (int n = 0; n < level; n++) writef("  ");
				writefln("'%s' (%s)", token.text, token.parentSymbol);
			} else {
				//node.dumpTree(level + (tokens.length > 1));
				node.dumpTree(level + 1);
			}
		}
	}

	void optimize() {
	}

	void codegen() {
		dumpTree();
	}

	public string toString() {
		if (tokens.length == 1) {
			return std.string.format("%s", tokens[0]);
		} else {
			return std.string.format("%s", tokens);
		}
	}
}

public class NodeType : public Node {
}

public class NodeArgument : public Node {
	NodeType type;
	Node name;
}

public class NodeBlock : public Node {
	Node[] nodes;
}

public class NodeFunction : public Node {
	NodeType       returnValue;
	NodeArgument[] arguments;
	NodeBlock      _body;

	void parse() {
	}
}

void main() {
	auto parser = new GOLDParser(new Grammar(std.file.read("C-ANSI.cgt")));
	parser.loadSource(new BufferedFile("test.c"));
	parser.onProgress = delegate void(int line, int sourcePos, int sourceSize) {
		//writefln("%d, %d, %d", line, sourcePos, sourceSize);
	};
	parser.onReduce = delegate Object(Rule rule, Token[] tokens) {
		if (tokens.length == 1) {
			auto node = cast(Node)tokens[0].data;
			if (node !is null) return node;
		}
		return new Node(rule, tokens);
	};
	parser.onAccept = delegate void(Object reduction) {
		auto node = cast(Node)reduction;
		//writefln("%s", reduction);
		//node.dumpTree();
		node.optimize();
		node.codegen();
	};
	parser.parse();
	writefln("line: %d, sourceSize: %d", parser.line, parser.sourceSize);
}