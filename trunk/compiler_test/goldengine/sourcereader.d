module goldengine.sourcereader;

import goldengine.unicodebom;

version(Tango) {
    import
        tango.io.Conduit,
        tango.io.MemoryConduit;
} else {
    import std.stream;
}

package class SourceReader {
    private {
        wstring mSourceBuffer;
        int mBufferPos = 0;
        int mCurrentLine = 0;
    }

version(Tango) {
    this(Conduit c) {
        auto mem = new MemoryConduit;
        mem.copy(c);

        auto unicode = new UnicodeBom!(wchar)(Encoding.Unknown);
        mSourceBuffer = unicode.decode(mem.slice());
    }
} else {
    this(Stream st) {
        void[] buf;
        buf.length = cast(uint)st.size;
        st.readBlock(buf.ptr, cast(uint)st.size);
        auto unicode = new UnicodeBom!(wchar)(Encoding.Unknown);
        mSourceBuffer = cast(wstring)unicode.decode(buf);
    }
}

    this(wstring s) {
        mSourceBuffer = s;
    }

    ///Source size in characters
    public int size() {
        return mSourceBuffer.length;
    }

    ///Current position in source
    public int position() {
        return mBufferPos;
    }

    ///Reset to start position
    public void reset() {
        mBufferPos = 0;
    }

    ///Has the end-of-file been reached?
    public bool eof() {
        return mBufferPos >= mSourceBuffer.length;
    }

    ///Read a string from the input, advancing position if discard=true
    public wstring read(int count, bool discard) {
        int toread = size - mBufferPos;
        if (toread > count)
            toread = count;

        int oldPos = mBufferPos;
        if (discard) {
            mBufferPos += toread;
        }
        return mSourceBuffer[oldPos..oldPos+toread];
    }

    ///Return one character from the buffer without discarding it
    ///count = 1 means get the current char
    ///Returns false when reading beyond file end
    public bool lookAhead(int count, ref wchar c) {
        if (mBufferPos + count <= size) {
            c = mSourceBuffer[mBufferPos+count-1];
            return true;
        } else {
            return false;
        }
    }

    ///according to docs, this should read until and endline is found and stop
    ///before the endline character
    public wstring readLine() {
        bool endReached = false;
        wstring res;
        while (!endReached && !eof) {
            wstring c = read(1, true);
            if (c[0] == 10 || c[0] == 13) {
                //a newline was just read and discarded -> abort and step back one
                endReached = true;
                mBufferPos--;
            } else {
                res ~= c;
            }
        }
        return res;
    }
}
