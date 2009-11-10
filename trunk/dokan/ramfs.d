import dokan;

class DokanRamFS : Dokan {
	this(wchar c) {
		super(c);
		root = new Node();
		root.is_root = true;
		root.is_directory = true;
		auto node = new Node(root, "hola.txt");
		node.data = new MemoryStream();
		node.data.writef("Hola!");
		new Node(root, "prueba.txt");
	}

	class Node {
		FILETIME CreationTime;
		FILETIME LastAccessTime;
		FILETIME LastWriteTime;
		wchar[] name;

		static ulong last_id = 0;
		ulong id;
		bool is_root;
		bool is_directory;
		Node parent;
		Node[wchar[]] childs;
		Stream data;
		long _length;
		
		long length() { return (data !is null) ? data.size : _length; }
		
		uint FileAttributes() {
			return is_directory ? 16 : 128;
		}
		
		this(Node parent = null, wchar[] name = "") {
			this.parent = parent;
			this.id = ++last_id;
			if (parent !is null) {
				this.name = name.dup;
				parent.childs[this.name] = this;
			}
			SYSTEMTIME time;
			time.wYear = 2009;
			time.wMonth = 10;
			time.wDayOfWeek = 0;
			time.wDay = 11;
			time.wHour = 0;
			time.wMinute = 0;
			time.wSecond = 0;
			time.wMilliseconds = 0;
			SystemTimeToFileTime(&time, &CreationTime);
			SystemTimeToFileTime(&time, &LastAccessTime);
			SystemTimeToFileTime(&time, &LastWriteTime);
		}
		
		static int find(wchar[] s, wchar v) {
			foreach (k, c; s) if (v == c) return k; return -1;
		}
		
		Node getPath(wchar[] path, bool create = false) {
			if (!path.length) return this;
			Node current = this;
			int separator = find(path, cast(dchar)'\\');
			if (separator == 0) {
				current = root;
			} else {
				auto currentName = (separator == -1) ? path : path[0..separator];
				if ((currentName in current.childs) is null) if (create) (new Node(current, currentName)); else return null;
				current = current.childs[currentName];
			}			
			if (separator >= 0) {
				if ((separator + 1) < path.length) {
					current = current.getPath(path[separator + 1..path.length], create);
				}
			}
			return current;
		}
		
		Node opIndex(wchar[] path) { return getPath(path); }
		
		int opApply(int delegate(ref Node) dg) {  
			int result = 0;
			foreach (child; childs) {
				result = dg(child);
				if (result) break;
			}
			return result;
		}
		wchar[] path() {
			if (parent is null) return name;
			return parent.path ~ "\\" ~ name;
		}
		
		char[] toString() { return toUTF8(path); }
	}
	
	class NodeHandle {
		Node node;
		ulong offset;
		
		this(Node node) {
			this.node = node;
			this.offset = 0;
		}
		
		bool Ready() { return (node !is null) && (node.data !is null); }
		
		void Seek(ulong offset) {
			this.offset = offset;
		}
		
		int Read(ubyte[] buffer) {
			if (!Ready) return 0;
			node.data.position = offset;
			return node.data.read(buffer);
		}

		int Write(ubyte[] buffer) {
			if (!Ready) return 0;
			node.data.position = offset;
			return node.data.write(buffer);
		}
	}
	
	Node root;
	
	int CreateFile(wchar[] FileName, uint DesiredAccess, uint ShareMode, uint CreationDisposition, uint FlagsAndAttributes, DOKAN_FILE_INFO* DokanFileInfo) {
		//writefln("CreateFile (FileName:'%s', DesiredAccess:%08X, SharedMode:%08X, CreationDisposition:%08X, FlagsAndAttributes:%08X)", FileName, DesiredAccess, ShareMode, CreationDisposition, FlagsAndAttributes);
		Node node = root.getPath(FileName, false);
		if (node !is null) {
			//node.data = new MemoryStream();
		}
		DokanFileInfo.Context = cast(ulong)cast(void *)(new NodeHandle(node));
		return 0;
	}

	int ReadFile(wchar[] FileName, void* Buffer, uint NumberOfBytesToRead, out uint NumberOfBytesRead, ulong Offset, DOKAN_FILE_INFO* DokanFileInfo) {
		//writefln("!!Unprocessed ReadFile (FileName:'%s', NumberOfBytesToRead:%d, Offset:%d)", FileName, NumberOfBytesToRead, Offset);
		NodeHandle handle = cast(NodeHandle)cast(void *)DokanFileInfo.Context;
		if ((handle is null) || !handle.Ready) return -1;
		handle.Seek(Offset);
		NumberOfBytesRead = handle.Read((cast(ubyte*)Buffer)[0..NumberOfBytesToRead]);
		return 0;
	}

	int WriteFile(wchar[] FileName, void* Buffer, uint NumberOfBytesToWrite, out uint NumberOfBytesWritten, ulong Offset, DOKAN_FILE_INFO* DokanFileInfo) {
		//writefln("!!Unprocessed WriteFile (FileName:'%s', NumberOfBytesToWrite:%d, Offset:%d)", FileName, NumberOfBytesToWrite, Offset);
		NodeHandle handle = cast(NodeHandle)cast(void *)DokanFileInfo.Context;
		if ((handle is null) || !handle.Ready) return -1;
		handle.Seek(Offset);
		NumberOfBytesWritten = handle.Write((cast(ubyte*)Buffer)[0..NumberOfBytesToWrite]);
		return 0;
	}

	int FindFiles(wchar[] PathName, FINDCALLBACK Callback, DOKAN_FILE_INFO* DokanFileInfo) {
		return FindFilesWithPattern(PathName, "*", Callback, DokanFileInfo);
	}
	
	int GetFileInformation(wchar[] FileName, out BY_HANDLE_FILE_INFORMATION Buffer, DOKAN_FILE_INFO* DokanFileInfo) {
		//writefln("!!Unprocessed GetFileInformation (FileName:'%s')", FileName);

		NodeHandle handle = cast(NodeHandle)cast(void *)DokanFileInfo.Context;
		if ((handle is null) || !handle.Ready) return -1;

		Buffer.FileAttributes     = handle.node.FileAttributes;
		Buffer.CreationTime       = handle.node.CreationTime;
		Buffer.LastAccessTime     = handle.node.LastAccessTime;
		Buffer.LastWriteTime      = handle.node.LastWriteTime;
		Buffer.VolumeSerialNumber = 0;
		Buffer.FileSizeLow        = handle.node.length & 0xFFFFFFFF;
		Buffer.FileSizeHigh       = handle.node.length >> 32;
		Buffer.NumberOfLinks      = 0;
		Buffer.FileIndexLow       = handle.node.id & 0xFFFFFFFF;
		Buffer.FileIndexHigh      = handle.node.id >> 32;

		return 0;
	}

	int FindFilesWithPattern(wchar[] PathName, wchar[] Pattern, FINDCALLBACK Callback, DOKAN_FILE_INFO* DokanFileInfo) {
		WIN32_FIND_DATAW Find;

		foreach (node; root.getPath(PathName)) {
			copywchar(Find.FileName, node.name);
			writefln("::%s", node.name);
			if (!DokanIsNameInExpression(Pattern.ptr, Find.FileName.ptr, true)) continue;

			Find.FileAttributes = node.FileAttributes;
			Find.FileSizeLow    = node.length & 0xFFFFFFFF;
			Find.FileSizeHigh   = node.length >> 32;
			Find.CreationTime   = node.CreationTime;
			Find.LastAccessTime = node.LastAccessTime;
			Find.LastWriteTime  = node.LastWriteTime;
			copywchar(Find.AlternateFileName, node.name);

			Callback(&Find, DokanFileInfo);
		}
		//writefln("!!Unprocessed FindFiles");
		return 0;
	}

	int GetVolumeInformation(out wchar[] VolumeName, out uint VolumeSerialNumber, out uint MaximumComponentLength, out uint FileSystemFlags, out wchar[] FileSystemName, DOKAN_FILE_INFO* DokanFileInfo) {
		VolumeName             = "TestVolume";
		FileSystemName         = "DokanFS";
		VolumeSerialNumber     = 0x_00_00_00_00;
		FileSystemFlags        = 0x_00_00_00_00;
		MaximumComponentLength = 255;
		return 0;
	}
	
	int GetDiskFreeSpace(out ulong FreeBytesAvailable, out ulong TotalNumberOfBytes, out ulong TotalNumberOfFreeBytes, DOKAN_FILE_INFO* DokanFileInfo) {
		FreeBytesAvailable     = 1 * 1024 * (1024 * 1024);
		TotalNumberOfFreeBytes = 1 * 1024 * (1024 * 1024);
		TotalNumberOfBytes     = 1 * 1024 * (1024 * 1024);
		return 0;
	}
}

int main(char[][] args) {
	scope dokan = new DokanRamFS('m');
	return dokan.main();
}
