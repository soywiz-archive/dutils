module test;

import std.stdio;
import std.file;
import std.conv;
import std.stream;
import std.algorithm;
import goldengine.goldparser;

class Node {
	this() {
	}
	
	wstring type() { return "undefined"; }

	Node[] nodes() { return []; }
	
	Node[] optimizeRemoveAdd(Node child, int level = 0) {
		return [child];
	}

	static Node[] getNodesFromTokens(Token[] tokens) {
		Node[] nodes;
		foreach (token; tokens) {
			auto node = cast(Node)token.data;
			if (node !is null) nodes ~= node;
		}
		return nodes;
	}

	Node[] optimizeRemoveAddList(Node[] children, int level = 0) {
		Node[] list;
		foreach (node; nodes) {
			list ~= this.optimizeRemoveAdd(node.optimize(level), level);
		}
		return list;
	}

	void dumpTree(int level = 0) {
		//if (tokens.length != 1)
		{
			for (int n = 0; n < level; n++) writef("  ");
			writefln("-- %s", this);
			//writefln("-- %s", this);
		}
		foreach (node; nodes) {
			node.dumpTree(level + 1);
		}
	}

	Node optimize(int level = 0) {
		return this;
	}

	static void optimize(ref Node node, int level = 0) {
		node = node.optimize(level);
	}

	static void optimize(Node[] nodes, int level = 0) {
		foreach (ref node; nodes) node = node.optimize(level);
	}

	void codegen() {
		//dumpTree();
		foreach (node; nodes) node.codegen();
	}

	string toString() {
		return std.string.format("%s()", this.classinfo);
	}

	static Node parse(Rule rule, Token[] tokens) {
		return new Node();
	}
}

class NodeBinaryOp : Node {
	wstring op;
	Node l, r;
	
	Node[] nodes() { return [l, r]; }
	
	wstring type() {
		if (l.type != r.type) throw(new Exception("Left and right types mismatch"));
		return l.type;
	}
	
	this(wstring op, Node l, Node r) {
		this.op = op;
		this.l = l;
		this.r = r;
	}

	static Node parse(Rule rule, Token[] tokens) {
		return new NodeBinaryOp(
			tokens[1].text,
			cast(Node)tokens[0].data,
			cast(Node)tokens[2].data
		);
	}
	
	Node optimize(int level = 0) {
		l = l.optimize(level);
		r = r.optimize(level);
		//return this;
		if (level >= 1) {
			auto _l = cast(NodeLiteral)l;
			auto _r = cast(NodeLiteral)r;
			if ((_l !is null) && (_r !is null)) {
				switch (op) {
					case "+": return new NodeLiteral(_l.value + _r.value);
					case "-": return new NodeLiteral(_l.value - _r.value);
					default: break;
				}
			}
		}
		return this;
	}

	void codegen() {
		l.codegen();
		r.codegen();
		writefln("OP%s", op);
	}

	string toString() {
		return std.string.format("%s(%s)", this.classinfo, op);
	}
}

class NodeLiteral : Node {
	int value;
	
	wstring type() { return "int"; }
	
	this(int value) {
		this.value = value;
	}
	
	static Node parse(Rule rule, Token[] tokens) {
		return new NodeLiteral(to!int(tokens[0].text));
	}

	void codegen() {
		writefln("PUSH %d", value);
	}

	string toString() {
		return std.string.format("%s(%d)", this.classinfo, value);
	}
}

class NodeContainer : Node {
	Node[] _nodes;

	Node[] nodes() { return _nodes; }

	this(Node[] nodes) {
		this._nodes = nodes;
	}
	
	Node[] optimizeRemoveAdd(Node child, int level = 0) {
		auto container = cast(NodeContainer)child;
		if (container && container.classinfo.name == "test.NodeContainer") {
			return container._nodes;
		}
		return [child];
	}

	Node optimize(int level = 0) {
		_nodes = optimizeRemoveAddList(_nodes, level);
		if (_nodes.length == 1) {
			return _nodes[0].optimize(level);
		} else {
			foreach (ref node; _nodes) node = node.optimize;
			return this;
		}
	}

	static Node parse(Rule rule, Token[] tokens) {
		return new NodeContainer(getNodesFromTokens(tokens));
	}

	string toString() {
		return std.string.format("%s(COUNT:%d)", this.classinfo, _nodes.length);
	}
}

class NodeSentence : NodeContainer {
	this(Node[] nodes) {
		super(nodes);
	}
	
	Node optimize(int level = 0) {
		foreach (ref node; nodes) node = node.optimize(level);
		return this;
	}

	void codegen() {
		NodeContainer.codegen();
		writefln("POP");
	}

	static Node parse(Rule rule, Token[] tokens) {
		return new NodeSentence(getNodesFromTokens(tokens));
	}
}

class NodeCall : Node {
	Node func;
	Node[] params;
	
	Node[] nodes() { return params ~ func; }
	
	this(Node func, Node[] params) {
		this.func   = func;
		this.params = params;
	}

	Node optimize(int level = 0) {
		func = func.optimize(level);
		foreach (ref node; params) node = node.optimize(level);
		return this;
	}

	static Node parse(Rule rule, Token[] tokens) {
		auto nodes = getNodesFromTokens(tokens);
		return new NodeCall(nodes[0], nodes[1..$]);
	}

	void codegen() {
		foreach (param; params) param.codegen();
		func.codegen();
		writefln("CALL");
	}
}

class NodeId : Node {
	wstring name;
	
	this(wstring name) {
		this.name = name;
	}
	
	static Node parse(Rule rule, Token[] tokens) {
		return new NodeId(tokens[0].text);
	}

	void codegen() {
		writefln("PUSH_ID '%s'", name);
	}
}

void main() {
	auto parser = new GOLDParser(new Grammar(cast(ubyte[])import("TEST.cgt")));
	parser.loadSource(new BufferedFile("test.test"));
	parser.onProgress = delegate void(int line, int sourcePos, int sourceSize) {
		//writefln("%d, %d, %d", line, sourcePos, sourceSize);
	};
	parser.onReduce = delegate Object(Rule rule, Token[] tokens) {
		//writefln("%s", rule.ntSymbol.name);
		switch (rule.ntSymbol.name) {
			case "DecLiteral": return NodeLiteral.parse(rule, tokens);
			case "Id"        : return NodeId.parse(rule, tokens);
			case "BinaryOp"  : return NodeBinaryOp.parse(rule, tokens);
			case "Sentence"  : return NodeSentence.parse(rule, tokens);
			case "Call"      : return NodeCall.parse(rule, tokens);
			case "CommaExpression":
			case "Expression":
			case "Sentences" : return NodeContainer.parse(rule, tokens);
			default: break;
		}
		writefln("%s", rule.ntSymbol.name);
		assert(0);
		return Node.parse(rule, tokens);
	};
	parser.onAccept = delegate void(Object reduction) {
		auto node = cast(Node)reduction;
		//writefln("%s", reduction);
		//node.dumpTree();

		Node.optimize(node, 5);
		node.dumpTree();
		node.codegen();
	};
	parser.parse();
	writefln("line: %d, sourceSize: %d", parser.line, parser.sourceSize);
}