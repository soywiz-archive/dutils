import dokan;

debug = UnprocessedWrite;

class DokanRamFS : Dokan {
	this(wchar c) {
		super(c);
		root = new Node();
		auto node = new Node(root, "hola.txt");
		node.data = new MemoryStream();
		node.data.writef("Hola!");
		node = new Node(root, "prueba.txt");
		node.data = new MemoryStream();
		node.data.writef("Prueba!");
	}

	class Node {
		FILETIME CreationTime;
		FILETIME LastAccessTime;
		FILETIME LastWriteTime;
		wstring name;

		static ulong last_id = 0;
		ulong id;
		bool is_root() { return parent is null; }
		bool is_directory;
		Node parent;
		Node[wstring] childs;
		Stream data;
		long _length;
		
		long length() { return (data !is null) ? data.size : _length; }
		
		void remove() {
			parent.childs.remove(this.name);
			this.parent = null;
		}
		
		uint FileAttributes() {
			return is_directory ? 16 : 128;
		}
		
		this(Node parent = null, wstring name = "", bool is_directory = false) {
			this.parent = parent;
			this.id = ++last_id;
			this.is_directory = is_directory;
			if (this.is_root) this.is_directory = true;
			if (parent !is null) {
				this.name = cast(wstring)name.dup;
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
		
		static int find(wstring s, wchar v) {
			foreach (k, c; s) if (v == c) return k; return -1;
		}
		
		Node getChild(wstring name, bool create = false) {
			if (!name.length || (name == ".")) return this;
			if (name == "..") return parent;
			if ((name in childs) is null) {
				if (!create) return null;
				new Node(this, name);
			}
			return childs[name];
		}
		
		Node getPath(wstring path, bool create = false) {
			if (!path.length) return this;
			Node current = this;
			int separator = find(path, cast(dchar)'\\');

			current = (separator != 0) ? getChild((separator == -1) ? path : path[0..separator], create) : root;

			if (current && (separator >= 0)) {
				if ((separator + 1) < path.length) {
					current = current.getPath(path[separator + 1..path.length], create);
				}
			}
			return current;
		}
		
		Node opIndex(wstring path) { return getPath(path); }
		
		int opApply(int delegate(ref Node) dg) {  
			int result = 0;
			foreach (child; childs) {
				result = dg(child);
				if (result) break;
			}
			return result;
		}
		wstring path() {
			if (parent is null) return name;
			return parent.path ~ "\\" ~ name;
		}
		
		string toString() { return toUTF8(path); }
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
		
		void Remove() {
			if (node is null) return;
			node.remove();
		}
	}
	
	Node root;
	
	// CreateFile
	//   If file is a directory, CreateFile (not OpenDirectory) may be called.
	//   In this case, CreateFile should return 0 when that directory can be opened.
	//   You should set TRUE on DokanFileInfo->IsDirectory when file is a directory.
	//   When CreationDisposition is CREATE_ALWAYS or OPEN_ALWAYS and a file already exists,
	//   you should return ERROR_ALREADY_EXISTS(183) (not negative value)
	int CreateFile(wstring FileName, uint DesiredAccess, uint ShareMode, uint CreationDisposition, uint FlagsAndAttributes, DOKAN_FILE_INFO* DokanFileInfo) {
		debug (UnprocessedWrite) {
			writefln("-------------------------------------");
			writefln("CreateFile (FileName:'%s', DesiredAccess:%08X, SharedMode:%08X, CreationDisposition:%08X, FlagsAndAttributes:%08X)", FileName, DesiredAccess, ShareMode, CreationDisposition, FlagsAndAttributes);
		}
		Node node = root.getPath(FileName, false);
		if (node is null) {
			debug (UnprocessedWrite) writefln("  [null]");
			DokanFileInfo.Context = 0;
			return 183;
		} else {
			debug (UnprocessedWrite) writefln("  [context] : %08X", cast(uint)cast(void *)node);
			//node.data = new MemoryStream();
			DokanFileInfo.Context = cast(ulong)cast(void *)(new NodeHandle(node));
			DokanFileInfo.IsDirectory = node.is_directory;
			return 0;
		}
	}

	// When FileInfo->DeleteOnClose is true, you must delete the file in Cleanup.
	int Cleanup(wstring FileName, DOKAN_FILE_INFO* DokanFileInfo) {
		debug (UnprocessedWrite) writefln("!!Unprocessed Cleanup (FileName:'%s', DeleteOnClose:%d)", FileName, DokanFileInfo.DeleteOnClose);
		if (DokanFileInfo.DeleteOnClose) {
			Node node = root.getPath(FileName);
			if (node !is null) node.remove();
		}
		/*
		NodeHandle handle = cast(NodeHandle)cast(void *)DokanFileInfo.Context;
		writefln("  [1] %08X", cast(uint)cast(void *)handle);
		if (handle is null) return -1;
		writefln("  [2]");
		if (DokanFileInfo.DeleteOnClose) {
			handle.Remove();
			writefln("      deleted!!!");
		}
		*/
		return 0;
	}

	int ReadFile(wstring FileName, void* Buffer, uint NumberOfBytesToRead, out uint NumberOfBytesRead, ulong Offset, DOKAN_FILE_INFO* DokanFileInfo) {
		debug (UnprocessedWrite) writefln("!!Unprocessed ReadFile (FileName:'%s', NumberOfBytesToRead:%d, Offset:%d)", FileName, NumberOfBytesToRead, Offset);
		NodeHandle handle = cast(NodeHandle)cast(void *)DokanFileInfo.Context;
		writefln("  %08X", cast(uint)cast(void *)DokanFileInfo.Context);
		if ((handle is null) || !handle.Ready) return -1;
		handle.Seek(Offset);
		NumberOfBytesRead = handle.Read((cast(ubyte*)Buffer)[0..NumberOfBytesToRead]);
		return 0;
	}

	int WriteFile(wstring FileName, void* Buffer, uint NumberOfBytesToWrite, out uint NumberOfBytesWritten, ulong Offset, DOKAN_FILE_INFO* DokanFileInfo) {
		debug (UnprocessedWrite) writefln("!!Unprocessed WriteFile (FileName:'%s', NumberOfBytesToWrite:%d, Offset:%d)", FileName, NumberOfBytesToWrite, Offset);
		NodeHandle handle = cast(NodeHandle)cast(void *)DokanFileInfo.Context;
		if ((handle is null) || !handle.Ready) return -1;
		handle.Seek(Offset);
		NumberOfBytesWritten = handle.Write((cast(ubyte*)Buffer)[0..NumberOfBytesToWrite]);
		return 0;
	}

	int OpenDirectory(wstring FileName, DOKAN_FILE_INFO* DokanFileInfo) {
		debug (UnprocessedWrite) writefln("!!Unprocessed OpenDirectory (FileName:'%s')", FileName);
		return 0;
	}

	int CreateDirectory(wstring FileName, DOKAN_FILE_INFO* DokanFileInfo) {
		debug (UnprocessedWrite) writefln("!!Unprocessed CreateDirectory (FileName:'%s')", FileName);
		Node node = root.getPath(FileName, true);
		if (node !is null) {
			node.is_directory = true;
		}
		return 0;
	}

	// You should not delete file on DeleteFile or DeleteDirectory.
	// When DeleteFile or DeleteDirectory, you must check whether
	// you can delete or not, and return 0 (when you can delete it)
	// or appropriate error codes such as -ERROR_DIR_NOT_EMPTY,
	// -ERROR_SHARING_VIOLATION.
	// When you return 0 (ERROR_SUCCESS), you get Cleanup with
	// FileInfo->DeleteOnClose set TRUE, you delete the file.
	int DeleteFile(wstring FileName, DOKAN_FILE_INFO* DokanFileInfo) {
		debug (UnprocessedWrite) writefln("!!Unprocessed DeleteFile (FileName:'%s')", FileName);
		Node node = root.getPath(FileName, false);
		if (node is null) return -0x02; // File doesn't exists
		return 0;
	}

	int DeleteDirectory(wstring FileName, DOKAN_FILE_INFO* DokanFileInfo) {
		debug (UnprocessedWrite) writefln("!!Unprocessed DeleteDirectory (FileName:'%s')", FileName);
		Node node = root.getPath(FileName, false);
		if (node is null) return -1; // File doesn't exists
		if (node.childs.length) return -0x91; // ERROR_DIR_NOT_EMPTY
		return 0; // ERROR_SUCCESS (Can remove)
	}

	int FindFiles(wstring PathName, FINDCALLBACK Callback, DOKAN_FILE_INFO* DokanFileInfo) {
		return FindFilesWithPattern(PathName, "*", Callback, DokanFileInfo);
	}
	
	int GetFileInformation(wstring FileName, out BY_HANDLE_FILE_INFORMATION Buffer, DOKAN_FILE_INFO* DokanFileInfo) {
		debug (UnprocessedWrite) writefln("!!Unprocessed GetFileInformation (FileName:'%s')", FileName);

		NodeHandle handle = cast(NodeHandle)cast(void *)DokanFileInfo.Context;
		if ((handle is null) || (handle.node is null)) return -1;

		Buffer.FileAttributes     = handle.node.FileAttributes;
		Buffer.CreationTime       = handle.node.CreationTime;
		Buffer.LastAccessTime     = handle.node.LastAccessTime;
		Buffer.LastWriteTime      = handle.node.LastWriteTime;
		Buffer.VolumeSerialNumber = 0x19831116;
		Buffer.NumberOfLinks      = 0;
		*cast(ulong *)&Buffer.FileSizeLow  = handle.node.length;
		*cast(ulong *)&Buffer.FileIndexLow = handle.node.id;

		return 0;
	}

	int FindFilesWithPattern(wstring PathName, wstring Pattern, FINDCALLBACK Callback, DOKAN_FILE_INFO* DokanFileInfo) {
		debug (UnprocessedWrite) writefln("!!Unprocessed FindFilesWithPattern (PathName:'%s', Pattern:'%s')", PathName, Pattern);

		Node directory = root.getPath(PathName);
		if (directory is null || !directory.is_directory) return -1;

		WIN32_FIND_DATAW Find;
		
		foreach (node; directory) {
			copywchar(Find.FileName, cast(wchar[])node.name);

			debug (UnprocessedWrite) writefln("::%s", node.name);

			if (!DokanIsNameInExpression(cast(wchar*)Pattern.ptr, cast(wchar*)Find.FileName.ptr, true)) continue;

			Find.FileAttributes = node.FileAttributes;
			*cast(ulong *)&Find.FileSizeLow = node.length;
			Find.CreationTime   = node.CreationTime;
			Find.LastAccessTime = node.LastAccessTime;
			Find.LastWriteTime  = node.LastWriteTime;
			copywchar(Find.AlternateFileName, cast(wchar[])node.name);

			Callback(&Find, DokanFileInfo);
		}

		return 0;
	}

	int GetVolumeInformation(out wstring VolumeName, out uint VolumeSerialNumber, out uint MaximumComponentLength, out uint FileSystemFlags, out wstring FileSystemName, DOKAN_FILE_INFO* DokanFileInfo) {
		VolumeName             = "TestVolume";
		FileSystemName         = "DokanFS";
		VolumeSerialNumber     = 0x19831116;
		FileSystemFlags        = FILE_CASE_SENSITIVE_SEARCH | FILE_CASE_PRESERVED_NAMES | FILE_UNICODE_ON_DISK;
		MaximumComponentLength = 256;
		return 0;
	}
	
	int GetDiskFreeSpace(out ulong FreeBytesAvailable, out ulong TotalNumberOfBytes, out ulong TotalNumberOfFreeBytes, DOKAN_FILE_INFO* DokanFileInfo) {
		FreeBytesAvailable     = 1 * 1024 * (1024 * 1024);
		TotalNumberOfFreeBytes = 1 * 1024 * (1024 * 1024);
		TotalNumberOfBytes     = 1 * 1024 * (1024 * 1024);
		return 0;
	}
}

int main(string[] args) {
	scope dokan = new DokanRamFS('m');
	return dokan.main();
}
