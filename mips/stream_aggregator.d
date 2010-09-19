module stream_aggregator;

import std.stream, std.string, std.stdio;

class StreamAggregator : Stream {
	class Map {
		Stream stream;
		uint   start;
		uint   end;
		ubyte[] cached = null;
		string fileName;
		long fileStart, fileEnd;
		this(Stream stream, uint start, uint end, string fileName = "unknown", long fileStart = 0, long fileEnd = 0) {
			this.stream = stream;
			this.start  = start;
			this.end    = end;
			this.fileName = fileName;
			this.fileStart = fileStart;
			this.fileEnd = fileEnd;
		}
		uint length() { return end - start; }
		ubyte[] data() {
			if (cached is null) cached = cast(ubyte[])(new SliceStream(stream, 0)).readString(length);
			return cached;
		}
		void clearCache() { cached = null; }
	}
	Map currentMap;
	Map[] maps;
	uint currentPosition;
	//uint positionMask = 0x_0FFFFFFF;

	void clearCache() {
		foreach (map; maps) map.clearCache();
	}

	auto addMap(uint start, Stream stream, string fileName = "unknown", long fileStart = 0, long fileEnd = 0) {
		//start &= positionMask;
		maps ~= new Map(stream, start, cast(uint)(start + stream.size), fileName, fileStart, fileEnd);
		return this;
	}

	size_t readBlock(void* buffer, size_t size) {
		if (currentMap is null) return 0;
		size_t transferredBytes = currentMap.stream.readBlock(buffer, size);
		position = position + transferredBytes;
		return transferredBytes;
	}

	size_t writeBlock(const void* buffer, size_t size) {
		if (currentMap is null) {
			throw(new Exception(std.string.format("Trying to write out of any segment (0x%08X)", currentPosition)));
			return 0;
		}
		size_t transferredBytes = currentMap.stream.writeBlock(buffer, size);
		position = position + transferredBytes;
		return transferredBytes;
	}

	ulong seek(long offset, SeekPos whence) {
		switch (whence) {
			case SeekPos.Set, SeekPos.End: currentPosition = cast(uint)offset; break;
			case SeekPos.Current: currentPosition += offset; break;
		}
		//currentPosition &= positionMask;
		currentMap = null;
		foreach (map; maps) {
			if (currentPosition >= map.start && currentPosition < map.end) {
				currentMap = map;
				currentMap.stream.position = currentPosition - currentMap.start;
				break;
			}
		}
		return currentPosition;
	}

	ubyte opIndex(uint position) {
		return this[position..position + 1][0];
	}

	ubyte[] opSlice(uint start, uint end) {
		auto data = new ubyte[end - start];
		scope slice = new SliceStream(this, 0);
		slice.position = start;
		slice.read(data);
		return data;
	}

	override void close() {
		foreach (map; maps) map.stream.close();
	}
}