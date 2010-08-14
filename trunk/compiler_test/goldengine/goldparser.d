module goldengine.goldparser;

import goldengine.dfastate;
import goldengine.lalrstate;
import goldengine.stack;
import goldengine.sourcereader;

import std.stream;
import str = std.string;
import std.utf;
import std.conv;

public import goldengine.grammar;
public import goldengine.rule;
public import goldengine.symbol;
public import goldengine.token;

/*
auto parser = new GOLDParser(new Grammar(std.file.read("file.cgt")));
parser.loadSource(new BufferedFile("file.source"));
parser.onProgress = delegate void(int line, int sourcePos, int sourceSize) {
};
parser.onReduce = delegate Object(Rule rule, Token[] tokens) {
};
parser.onAccept = delegate void(Object reduction) {
};
parser.parse();
*/
class GOLDParser {
	enum Message {
		empty,                   // Nothing
		tokenRead,               // A new token is read
		reduction,               // A rule is reduced
		accept,                  // Grammar complete
		notLoadedError,          // Now grammar is loaded
		lexicalError,            // Token not recognized
		syntaxError,             // Token is not expected
		commentError,            // Reached the end of the file - mostly due to being stuck in comment mode
		internalError,           // Something is wrong, very wrong
	}

	enum Result {
		shift,
		reduce,
		reduceTrimmed,
		accept,
		syntaxError,
		internalError,
	}

	class Error : Exception {
		public GOLDParser.Message code;
		public int line;

		this(GOLDParser.Message code, int line, string msg) {
			super(msg);
			this.line = line;
			this.code = code;
		}

		public string toString() {
			return "Line "~to!string(line)~": "~msg;
		}
	}

	private {
		Grammar mGrammar;
		SourceReader mSource;
		Stack!(Token) mInputStack;
		Stack!(Token) mLALRTokenStack;
		Symbol[] mExpectedSymbols;
		int mCommentLevel;
		int mCurrentLine;
		LALRState mCurrentLALRState;
		bool mTrimReductions = false;
	}

	public {
		///executed when a rule has been reduced and a reduction object
		///should be created
		Object delegate(Rule redRule, Token[] redTokens) onReduce;
		///executed when the start rule has been reduced
		///reduction is the object you returned from onReduce
		void delegate(Object reduction) onAccept;
		///set this to allow progress-reporting to the user
		void delegate(int line, int sourcePos, int sourceSize) onProgress;
	}

	this(Grammar g) {
		mInputStack = new Stack!(Token)();
		mLALRTokenStack = new Stack!(Token)();
		mGrammar = g;
	}

	public Grammar grammar() {
		return mGrammar;
	}

	public void grammar(Grammar g) {
		mGrammar = g;
		reset();
	}

	/// Load the source text from a stream
	/// After the call, the parser will be ready to start parsing
	public void loadSource(Stream st) {
		mSource = new SourceReader(st);
		reset();
	}

	/// Load the source text from a string
	/// After the call, the parser will be ready to start parsing
	public void loadSource(wstring text) {
		mSource = new SourceReader(text);
		reset();
	}

	/// Reset the parser to the initial state, where it could begin
	/// parsing from the beginning of the source text
	public void reset() {
		mSource.reset();

		mExpectedSymbols.length = 0;

		mCommentLevel = 0;
		mCurrentLine = 1;

		mInputStack.clear();

		mLALRTokenStack.clear();
		mCurrentLALRState = mGrammar.lalrStateTable[mGrammar.initialLALRState];
		Token start = new Token(mGrammar.symbolStart,"");
		start.lalrState = mCurrentLALRState;
		mLALRTokenStack.push(start);
	}

	///Return current line number
	public int line() { return mCurrentLine; }

	///Return size, in characters, of the source text
	public int sourceSize() { return mSource.size(); }

	///Return current position, in characters, in the source text
	public int sourcePos() { return mSource.position(); }

	public bool trimReductions() { return mTrimReductions; }
	public void trimReductions(bool trim) { mTrimReductions = trim; }

	///When a syntax error is thrown, this will contain an array
	///of symbols that were expected when the error occured
	///This is valid when parse throws a syntax error exception, too
	public Symbol[] expectedSymbols() {
		return mExpectedSymbols;
	}

	///Return a space-delimited string of the above
	public wstring expectedSymbolsStr() {
		wstring res;
		foreach (Symbol s; mExpectedSymbols) res ~= s.name ~ " ";
		return res;
	}

	/// Parse the whole source text until it is accepted or an error occurs
	/// No parsing tree will be constructed unless the onReduce event is set.
	/// If the method runs through without exception, the source has been accepted.
	/// Make sure you load grammar and source before the call
	public void parse() {
		while (true) {
			GOLDParser.Message res = parseStep();
			if (onProgress) onProgress(line, sourcePos, sourceSize);
			switch (res) {
				case GOLDParser.Message.lexicalError  : throw new GOLDParser.Error(res, line, "Lexical error");
				case GOLDParser.Message.syntaxError   : throw new GOLDParser.Error(res, line, toUTF8("Syntax error, expected: " ~ expectedSymbolsStr));
				case GOLDParser.Message.notLoadedError: throw new GOLDParser.Error(GOLDParser.Message.notLoadedError, 0, "Grammar not loaded");
				case GOLDParser.Message.internalError : throw new GOLDParser.Error(res, line, "Internal error");
				case GOLDParser.Message.commentError  : throw new GOLDParser.Error(res, line, "Unexpected end of file");
				case GOLDParser.Message.accept        : return;
				default                               : break; // non-error events are handled by calling event procedures
			}
		}
	}

	/// Execute one step in the parsing process
	/// Use this if you want to write the parsing loop yourself
	/// No exceptions will be thrown, instead the return value is set
	/// appropriately
	public GOLDParser.Message parseStep() {
		// check if grammar is loaded (grammar is checked for validity on load)
		if (!mGrammar) return GOLDParser.Message.notLoadedError;

		while (true) {
			if (mInputStack.count == 0) {
				// We need to read a token from the Lexer
				auto token = retrieveToken();
				mInputStack.push(token);
				if ((mCommentLevel == 0) && (token.parentSymbol.kind != Symbol.Kind.commentLine) && (token.parentSymbol.kind != Symbol.Kind.commentStart)) return GOLDParser.Message.tokenRead;
			} else if (mCommentLevel > 0) {
				// the parser is in comment mode, so count commentStart
				// and commentEnd symbols until end of comment
				Token t = mInputStack.pop();
				switch (t.parentSymbol.kind) {
					case Symbol.Kind.commentStart: mCommentLevel++; break;
					case Symbol.Kind.commentEnd  : mCommentLevel--; break;
					case Symbol.Kind.end         : return GOLDParser.Message.commentError; // comment was not closed before end of file
					default                      : break;
				}
			} else {
				//a token is present and can be parsed
				Token t = mInputStack.top();
				switch (t.parentSymbol.kind) {
					case Symbol.Kind.whitespace  : mInputStack.pop(); break; //whitespace is ignored
					case Symbol.Kind.commentStart: mCommentLevel = 1; mInputStack.pop(); break;
					case Symbol.Kind.commentLine : mSource.readLine(); mInputStack.pop(); break;
					case Symbol.Kind.error       : return GOLDParser.Message.lexicalError;
					default                      :
						//LALR-parse the input token
						GOLDParser.Result parseRes = parseToken(t);
						switch (parseRes) {
							case GOLDParser.Result.accept       : return GOLDParser.Message.accept;
							case GOLDParser.Result.internalError: return GOLDParser.Message.internalError;
							case GOLDParser.Result.reduce       : return GOLDParser.Message.reduction;
							case GOLDParser.Result.shift        : mInputStack.pop(); break;
							case GOLDParser.Result.syntaxError  : return GOLDParser.Message.syntaxError;
							default                             : break; // Do nothing. This includes Shift and Trim-Reduced
						}
					break;
				}
			}
		}

		return GOLDParser.Message.empty;
	}

	private Token retrieveToken() {
		Token ret;
		if (mSource.eof()) {
			ret = new Token(mGrammar.symbolEof, "");
		} else {
			//current state of the DFA
			int currentState = mGrammar.initialDFAState;
			bool done = false;
			int length = 1;
			//data of last found accept state
			int lastAcceptState = -1;
			int lastAcceptLength = -1;

			while (!done) {
				//this will check if a target state can be found for the
				//current look-ahead character
				int targetStateIdx;
				wchar ch;
				if (mSource.lookAhead(length,ch)) {
					targetStateIdx = mGrammar.dfaStateTable[currentState].findEdge(
						ch, mGrammar.charsetTable, mGrammar.caseSensitive);
				} else {
					targetStateIdx = -1;
				}

				if (targetStateIdx >= 0) {
					if (mGrammar.dfaStateTable[targetStateIdx].acceptState) {
						//this target state is an accept state, so
						//store the data for later use
						lastAcceptState = targetStateIdx;
						lastAcceptLength = length;
					}
					//advance to target state
					currentState = targetStateIdx;
					length++;
				} else {
					//no target state could be found, return last accept
					//or fail if none set
					if (lastAcceptState >= 0) {
						wstring text = mSource.read(lastAcceptLength, true);
						ret = new Token(mGrammar.dfaStateTable[lastAcceptState].acceptSymbol, text);
					} else {
						wstring text = mSource.read(1, true);
						ret = new Token(mGrammar.symbolError, text);
					}
					done = true;
				}
			}
		}

		//count lines for error reporting
		wchar last = 0;
		foreach (wchar c; ret.text) {
			if (c == 10 || c == 13) {
				if (c == 13 || last == 10) {
					mCurrentLine++;
				}
			}
			last = c;
		}

		//return current token
		return ret;
	}

	// execute onReduce event
	private Object doOnReduce(Rule redRule, Token[] redTokens) {
		return onReduce ? onReduce(redRule, redTokens) : null;
	}

	// execute onAccept event
	private void doOnAccept(Object reduction) {
		if (onAccept) onAccept(reduction);
	}

	private GOLDParser.Result parseToken(Token nextToken) {
		GOLDParser.Result res;
		//find an action for nextToken in the current LALR state
		LALRAction action = mCurrentLALRState.findAction(nextToken.parentSymbol);
		if (action) {
			mExpectedSymbols.length = 0;
			switch (action.action) {
				case ActionConstants.acAccept:
					doOnAccept(mLALRTokenStack.top.data);
					res = GOLDParser.Result.accept;
					break;
				case ActionConstants.acShift:
					//Shift to target state and push the current token
					//There seems to be an error in the official pseudo-code:
					//State has to be changed first, before assigning it to nextToken
					mCurrentLALRState = mGrammar.lalrStateTable[action.target];
					nextToken.lalrState = mCurrentLALRState;
					mLALRTokenStack.push(nextToken);
					res = GOLDParser.Result.shift;
				break;
				case ActionConstants.acReduce:
					//This section of the algorithm will reduce the rule
					//specified by the action action.
					Rule reduceRule = mGrammar.ruleTable[action.target];
					Token head;
					if (mTrimReductions && reduceRule.oneNT) {
						//trim reduction, if the rule only has one nonterminal
						//i.e. instead of creating a new token, modify the
						//existing one
						head = mLALRTokenStack.pop();
						head.parentSymbol = reduceRule.ntSymbol;
						res = GOLDParser.Result.reduceTrimmed;
					} else {
						//create a new reduction for the current rule
						Token[] redTokens = new Token[reduceRule.ruleSymbols.length];
						for (int i = reduceRule.ruleSymbols.length-1; i >= 0; i--) redTokens[i] = mLALRTokenStack.pop();

						head = new Token(reduceRule.ntSymbol,"");
						head.data = doOnReduce(reduceRule, redTokens);

						res = GOLDParser.Result.reduce;
					}

					//execute the GOTO action for the rule that was just
					//reduced
					LALRState lookupState = mLALRTokenStack.top.lalrState;
					LALRAction acGoto = lookupState.findAction(head.parentSymbol);
					if (acGoto) {
						mCurrentLALRState = mGrammar.lalrStateTable[acGoto.target];
						head.lalrState = mCurrentLALRState;
						mLALRTokenStack.push(head);
					} else {
						//if no goto action could be found, there is a table error
						res = GOLDParser.Result.internalError;
					}
					break;
			}
		} else {
			//There is a syntax error!
			mExpectedSymbols.length = 0;
			foreach (LALRAction a; mCurrentLALRState.actions) {
				if (a.action == ActionConstants.acShift) {
					mExpectedSymbols ~= a.entry;
				}
			}
			res = GOLDParser.Result.syntaxError;
		}
		return res;
	}
}
