module goldengine.grammar;

import goldengine.dfastate;
import goldengine.lalrstate;
import goldengine.rule;
import goldengine.symbol;

import std.stdio;
import std.stream;

class Reader {
	ubyte[] buffer;
	uint bufPos;
	this(void[] buffer, uint bufPos = 0) {
		this.buffer = cast(ubyte[])buffer;
		this.bufPos = bufPos;
	}

	bool eof() {
		return bufPos >= buffer.length;
	}
	
	T read(T)() {
		static if (is(T == wstring)) {
			wstring res;
			wchar c;
			while (!eof && ((c = read!wchar) != '\0')) res ~= c;
			return res;
		}
		scope (exit) bufPos += T.sizeof;
		return *cast(T*)&buffer[bufPos];
	}
}

public class Grammar {
    private {
		Reader mBuffer;
        int mStartSymbolIdx;

        const wstring cgtHeader = "GOLD Parser Tables/v1.0";
    }

    public {
        ///Grammar parameters
        wstring grmName;
        wstring grmVersion;
        wstring grmAuthor;
        wstring grmAbout;
        bool caseSensitive;

        ///Parse tables
        wstring[] charsetTable;
        Symbol[] symbolTable;
        Rule[] ruleTable;
        DFAState[] dfaStateTable;
        LALRState[] lalrStateTable;

        ///Initial states
        int initialDFAState;
        int initialLALRState;

        ///Special symbols
        Symbol symbolStart;
        Symbol symbolEof;
        Symbol symbolError;
    }

    ///Declaration of CGT format constants and structures
    ///Those are only needed when reading a grammar file
    private {
        struct CGTRecordEntry {
            char entryType;

			union {
				bool    vBool;
				ubyte   vByte;
				int     vInteger;
				wstring vString;
			}

            public static CGTRecordEntry read(Reader buffer) {
                CGTRecordEntry res;
				{
					res.entryType = buffer.read!char;
					switch (res.entryType) {
						case 'E': break;
						case 'B': res.vBool    = (buffer.read!ubyte == 1); break;
						case 'b': res.vByte    = (buffer.read!ubyte); break;
						case 'I': res.vInteger = cast(int)(buffer.read!short); break;
						case 'S': res.vString  = (buffer.read!wstring); break;
						default: throw new Exception("Invalid record entry type");
					}
				}
                return res;
            }
			
			public string toString() {
				switch (entryType) {
					case 'E': return std.string.format("void");
					case 'B': return std.string.format("bool(%s)", vBool ? "true" : "false");
					case 'b': return std.string.format("byte(%d)", vByte);
					case 'I': return std.string.format("int(%d)", vInteger);
					case 'S': return std.string.format("wstring('%s')", vString);
				}
			}
        }

        struct CGTMRecord {
            char recId;
            CGTRecordEntry[] entries;

            public static CGTMRecord read(Reader buffer) {
                CGTMRecord res;
				{
					// Length.
					res.entries.length = buffer.read!ushort - 1;

					// RecordId
					auto idRec = CGTRecordEntry.read(buffer);
					if (idRec.entryType != 'b') throw new Exception("Invalid M record structure");
					res.recId = cast(char)idRec.vByte;

					// Entries.
					//writefln("Packet(%s)", res.recId);
					foreach (ref e; res.entries) {
						e = CGTRecordEntry.read(buffer);
						//writefln("  %s", e);
					}
				}
                return res;
            }
        }
    }

    ///Load a grammar from a stream
    this(void[] data) {
        loadTables(data);
    }

    //actually loads the file
    private void loadTables(void[] data) {
		mBuffer = new Reader(data);
        processBuffer();
    }

    //process cached data
    private void processBuffer() {
        //check file header
        if (mBuffer.read!wstring != cgtHeader) throw new Exception("File format not recognized");
		
		while (!mBuffer.eof) {
			auto rt = mBuffer.read!char;
			switch (rt) {
				//Multiple is the only current record type, but this
				//code is ready for expansion
				case 'M': { // Multiple
					CGTMRecord rec = CGTMRecord.read(mBuffer);
					int curEntry = 0;
					switch (rec.recId) {
						case 'P': { // idParameters
							grmName         = rec.entries[0].vString;
							grmVersion      = rec.entries[1].vString;
							grmAuthor       = rec.entries[2].vString;
							grmAbout        = rec.entries[3].vString;
							caseSensitive   = rec.entries[4].vBool;
							mStartSymbolIdx = rec.entries[5].vInteger;
						} break;
						case 'T': { // idTableCounts
							symbolTable.length    = rec.entries[0].vInteger;
							charsetTable.length   = rec.entries[1].vInteger;
							ruleTable.length      = rec.entries[2].vInteger;
							dfaStateTable.length  = rec.entries[3].vInteger;
							lalrStateTable.length = rec.entries[4].vInteger;
						} break;
						case 'I': { // idInitial
							initialDFAState  = rec.entries[0].vInteger;
							initialLALRState = rec.entries[1].vInteger;
						} break;
						case 'S': { // idSymbols
							int symIdx = rec.entries[0].vInteger;
							symbolTable[symIdx] = new Symbol(symIdx, rec.entries[1].vString, cast(Symbol.Kind)rec.entries[2].vInteger);
							if (symIdx == mStartSymbolIdx) {
								//this is the start symbol, set reference
								symbolStart = symbolTable[symIdx];
							}
							if (symbolTable[symIdx].kind == Symbol.Kind.end) {
								//this is the "end of file" symbol
								symbolEof = symbolTable[symIdx];
							}
							if (symbolTable[symIdx].kind == Symbol.Kind.error) {
								//this is the "error" symbol
								symbolError = symbolTable[symIdx];
							}
						} break;
						case 'C': { // idCharSets
							charsetTable[rec.entries[0].vInteger] = rec.entries[1].vString;
						} break;
						case 'R': { // idRules
							int ruleIdx = rec.entries[0].vInteger;
							ruleTable[ruleIdx] = new Rule(ruleIdx, symbolTable[rec.entries[1].vInteger]);
							for (int i = 3; i < rec.entries.length; i++) {
								ruleTable[ruleIdx].ruleSymbols ~= symbolTable[rec.entries[i].vInteger];
							}
						} break;
						case 'D': { // idDFAStates
							int stateIdx = rec.entries[0].vInteger;
							bool acceptState = rec.entries[1].vBool;
							Symbol accSym = null;
							if (acceptState) accSym = symbolTable[rec.entries[2].vInteger];
							dfaStateTable[stateIdx] = DFAState(stateIdx, acceptState, accSym);
							for (int i = 4; i < rec.entries.length; i += 3) {
								dfaStateTable[stateIdx].edges ~= DFAEdge(
									rec.entries[i + 0].vInteger,
									rec.entries[i + 1].vInteger
								);
							}
						} break;
						case 'L': { // idLRTables
							int stateIdx = rec.entries[0].vInteger;
							LALRState state = new LALRState(stateIdx);
							for (int i = 2; i < rec.entries.length; i += 4) {
								state.actions ~= new LALRAction(
									symbolTable[rec.entries[i].vInteger],
									cast(ActionConstants)rec.entries[i+1].vInteger,
									rec.entries[i+2].vInteger);
							}
							lalrStateTable[stateIdx] = state;
						} break;
						case '!': { // Comment
						} break;
						case 'c': { // ???
							writefln("c block encountered");
						} break;
						default: throw new Exception(std.string.format("Invalid record structure (%s) (%d)", rec.recId, rec.recId));
					}
					break;
				}
				default: throw new Exception("Unknown record type");
			}
		}

        if (!symbolStart || !symbolEof || !symbolError || dfaStateTable.length < 1
            || lalrStateTable.length < 1)
            throw new Exception("Failed to load grammer: Missing some required values");
    }
}
