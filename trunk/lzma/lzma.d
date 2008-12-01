module lzma;

import std.stdio, std.file, std.string;

extern (C) {
	enum SRes {
		SZ_OK = 0,

		SZ_ERROR_DATA = 1,
		SZ_ERROR_MEM = 2,
		SZ_ERROR_CRC = 3,
		SZ_ERROR_UNSUPPORTED = 4,
		SZ_ERROR_PARAM = 5,
		SZ_ERROR_INPUT_EOF = 6,
		SZ_ERROR_OUTPUT_EOF = 7,
		SZ_ERROR_READ = 8,
		SZ_ERROR_WRITE = 9,
		SZ_ERROR_PROGRESS = 10,
		SZ_ERROR_FAIL = 11,
		SZ_ERROR_THREAD = 12,

		SZ_ERROR_ARCHIVE = 16,
		SZ_ERROR_NO_ARCHIVE = 17
	}
	alias ushort CLzmaProb;

	const uint LZMA_PROPS_SIZE = 5;
	const uint LZMA_REQUIRED_INPUT_MAX = 20;

	struct ISzAlloc {
		void *(*Alloc)(void *p, int size);
		void (*Free)(void *p, void *address); /* address can be 0 */
		uint data;
	}

	struct CLzmaProps {
		uint lc, lp, pb;
		uint dicSize;
	}

	struct CLzmaDec {
		CLzmaProps prop;
		CLzmaProb *probs;
		ubyte* dic;
		ubyte* buf;
		uint range, code;
		uint dicPos;
		uint dicBufSize;
		uint processedPos;
		uint checkDicSize;
		uint state;
		uint reps[4];
		uint remainLen;
		int needFlush;
		int needInitState;
		uint numProbs;
		uint tempBufSize;
		ubyte tempBuf[LZMA_REQUIRED_INPUT_MAX];
	}
	
	enum ELzmaStatus {
		LZMA_STATUS_NOT_SPECIFIED,               /* use main error code instead */
		LZMA_STATUS_FINISHED_WITH_MARK,          /* stream was finished with end mark. */
		LZMA_STATUS_NOT_FINISHED,                /* stream was not finished */
		LZMA_STATUS_NEEDS_MORE_INPUT,            /* you must provide more input bytes */
		LZMA_STATUS_MAYBE_FINISHED_WITHOUT_MARK  /* there is probability that stream was finished without end mark */
	}
	
	enum ELzmaFinishMode {
		LZMA_FINISH_ANY,   /* finish at any point */
		LZMA_FINISH_END    /* block must be finished at the end */
	}

	SRes LzmaProps_Decode(CLzmaProps *p, ubyte* data, uint size);
	void LzmaDec_Init(CLzmaDec *p);

	SRes LzmaDec_AllocateProbs(CLzmaDec* p, ubyte* props, uint propsSize, ISzAlloc* alloc);
	void LzmaDec_FreeProbs(CLzmaDec* p, ISzAlloc* alloc);

	SRes LzmaDec_Allocate(CLzmaDec* state, ubyte* prop, uint propsSize, ISzAlloc* alloc);
	void LzmaDec_Free(CLzmaDec* state, ISzAlloc* alloc);
	
	SRes LzmaDec_DecodeToDic(CLzmaDec *p, uint dicLimit, ubyte* src, uint* srcLen, ELzmaFinishMode finishMode, ELzmaStatus* status);
	SRes LzmaDec_DecodeToBuf(CLzmaDec *p, ubyte* dest, uint* destLen, ubyte* src, uint* srcLen, ELzmaFinishMode finishMode, ELzmaStatus* status);
	SRes LzmaDecode(ubyte* dest, uint* destLen, ubyte* src, uint* srcLen, ubyte* propData, uint propSize, ELzmaFinishMode finishMode, ELzmaStatus* status, ISzAlloc* alloc);
	
	void* Alloc(void *p, int length) { return std.c.stdlib.malloc(length); }
	void Free(void *p, void* address) { std.c.stdlib.free(address); }
}

ubyte[] LzmaDecode(ubyte[] i) {
	ubyte[] o;
	
	SRes res;
	ISzAlloc alloc;
	CLzmaDec state;
	CLzmaProps[] cprobs;
	ELzmaStatus status;
	
	alloc.Alloc = &Alloc;
	alloc.Free = &Free;
	
	if ((res = LzmaProps_Decode(&state.prop, i.ptr, LZMA_PROPS_SIZE)) != SRes.SZ_OK) throw(new Exception("Invalid LZMA header"));

	uint outLength = cast(uint)*(cast(ulong *)(i.ptr + LZMA_PROPS_SIZE));
	if (outLength > 0x4000000) throw(new Exception(format("Too big output %d", outLength)));
	
	LzmaDec_Init(&state);
	LzmaDec_Allocate(&state, i.ptr, LZMA_PROPS_SIZE, &alloc);
	
	try {
		int start_off = LZMA_PROPS_SIZE + 8;
		ubyte *inData = i.ptr + start_off;
		uint inLength = i.length - start_off;
		o.length = outLength;
		
		if ((res = LzmaDec_DecodeToBuf(&state, o.ptr, &outLength, inData, &inLength, ELzmaFinishMode.LZMA_FINISH_END, &status)) != SRes.SZ_OK) {
			throw(new Exception(format("Can't decode buffer %d")));
		}
	} catch (Exception e) {
		o.length = 0;
	} finally {
		LzmaDec_Free(&state, &alloc);
	}
	
	return o;
}

alias LzmaDecode decode;