module sfs;

import std.string, std.stream, std.file, std.path, std.stdio, std.date;

class FS_Entry {
	char[] name;
	FS_Entry _parent;

	FS_Entry[char[]] mounts;

	final public FS_Entry mount(char[] name, FS_Entry mount) {
		mounts[name] = mount;
		mount.parent = this;
		return this;
	}

	final public FS_Entry child(char[] name) {
		FS_Entry r = _child(name); if (r) return r;
		if (can_create) return create(name);
		throw(new Exception(format("Can't open or create '%s'", name)));
	}

	FS_Entry parent(FS_Entry fe) { return _parent = fe; }
	FS_Entry parent() { return _parent; }
	
	FS_Entry[] childs() { return []; }
	
	FS_Entry parent_self() { return parent ? parent : this; }
	
	char[] path() { return parent ? (parent.path ~ "/" ~ name) : name; }
	
    int opApply(int delegate(inout FS_Entry) callback) {
		int result;

		foreach (e; childs) {
			result = callback(e);
			if (result) break;
		}
		
		return result;
    }
	
	protected FS_Entry _child(char[] name) {
		foreach (child; childs) if (child.name == name) return child;
		return null;
	}
	
	FS_Entry create(char[] name) { return create_file(name); }
	FS_Entry create_file(char[] name) { throw(new Exception("Not implemented: 'create_file'")); }
	FS_Entry create_dir(char[] name) { throw(new Exception("Not implemented: 'create_dir'")); }
	
	bool can_create() { return false; }
	bool is_file() { return false; }
	bool is_dir() { return true; }
	bool exists() { return is_file || is_dir; }
	
	d_time atime() { return 0; }
	d_time atime(ulong) { return 0; }
	d_time mtime() { return 0; }
	d_time mtime(ulong) { return 0; }
	d_time ctime() { return 0; }
	d_time ctime(ulong) { return 0; }
	
	ulong attribs() { return 0; }
	ulong attribs(ulong) { return 0; }
	
	ulong owner() { return 0; }
	ulong owner(ulong) { return 0; }

	ulong group() { return 0; }
	ulong group(ulong) { return 0; }
	
	long size() {
		auto s = open();
		long r = s.size;
		close();
		return r;
	}
	
	ubyte[] read() {
		auto s = open;
		ubyte[] data = new ubyte[s.size];
		s.read(data);
		close();
		return data;
	}
	Stream open(FileMode mode = FileMode.In, bool grow = false) { throw(new Exception("Not implemented: 'open'")); }
	void close() { }
	
	void replace(Stream s, bool grow = false) {
		Stream cs = open(FileMode.OutNew, grow);
		cs.copyFrom(s);
		close();
	}
	
	protected void _flush() { }
	
	final void flush(bool recursive = false) {
		_flush();
		if (recursive) foreach (child; childs) child.flush();
	}
	
	private FS_Entry child2(char[] name) {
		if (name == ".") return this;
		if (name == "..") return parent;
		if (name in mounts) return mounts[name];
		return child(name);
	}
	
	char[][] list() {
		char[][] r;
		foreach (child; childs) r ~= child.name;
		return r;
	}
	
	FS_Entry opIndex(char[] path) {
		path = std.string.replace(path, "\\", "/");
		path = std.string.replace(path, "//", "/");
		
		if (path.length && path[0] == '/') {
			FS_Entry c = this;
			while (c.parent) c = c.parent;
			return c[path[1..path.length]];
		}
		
		int pos = find(path, "/");
		
		if (pos >= 0) return child2(path[0..pos])[path[pos + 1..path.length]];
		
		return child2(path);
	}
	
	/*Entry opIndex(char[] name) {
		int idx = find(name, "/");
		
		if (idx == -1) {
			if (name == ".") return this;
			if (name == "..") return parent_self;
			foreach (e; _childs) if (e.name == name) return e; throw(new Exception("Not found '" ~ name ~ "'"));
		}
		return this[name[0..idx]][name[idx+1..name.length]];
	}*/	
	
	void opCatAssign(FS_Entry e) { }
}

import std.c.windows.windows;

class Directory : FS_Entry {
	char[] path;
	long _size = -1;
	d_time _time_write;
	
	override d_time atime() { return _time_write; }
	override d_time ctime() { return _time_write; }
	override d_time mtime() { return _time_write; }
	
	override long size() {
		if (_size == -1) _size = std.file.getSize(path);
		return _size;
	}
	
	this(char[] path, char[] name = null, FS_Entry parent = null) {
		if (name is null) name = getBaseName(path);
		this.path = path;
		this.name = name;
		this.parent = parent;
	}

	Stream _open;
	override Stream open(FileMode mode = FileMode.In, bool grow = false) { 
		if (!_open) _open = new File(path, mode);
		return _open;
	}

	override void close() {
		if (!_open) return;
		_open.close();
		_open = null;
	}
	
	char[] child_path(char[] name) {
		return path ~ "/" ~ name;
	}
	
	override bool can_create() { return is_dir(); }

	override FS_Entry create_file(char[] name) {
		auto npath = child_path(name);
		return new Directory(npath);
	}
	override FS_Entry create_dir(char[] name) {
		auto npath = child_path(name);
		try { mkdir(npath); } catch { }
		flush();
		return new Directory(npath);
	}
	
	override void _flush() { cached = false; }
	
	private void listdir() {
		int strlen(wchar* c) { int l; while (*(c++)) l++; return l; }
		HANDLE h;
		WIN32_FIND_DATAW fileinfo;
		
		h = FindFirstFileW(std.utf.toUTF16z(std.path.join(path, "*.*")), &fileinfo);
		if (h == INVALID_HANDLE_VALUE) return;
		
		try {
			do
			{
				wchar* ptr = fileinfo.cFileName.ptr;
				char[] cname = std.utf.toUTF8(ptr[0..strlen(ptr)]);
				if (cname == "." || cname == "..") continue;
				
				auto d = new Directory(child_path(cname), cname, this);
				d._directory = (fileinfo.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
				d._cached_is_file_dir = true;
				d._size = (fileinfo.nFileSizeHigh << 32) | (fileinfo.nFileSizeLow << 0);
				d._time_write = std.date.FILETIME2d_time(&fileinfo.ftLastWriteTime);
				_childs ~= d;
				
			} while (FindNextFileW(h, &fileinfo) != FALSE);
		}
		finally
		{
			FindClose(h);
		}	
	}
	
	bool cached; FS_Entry[] _childs;
	FS_Entry[] childs() {
		if (!cached) {
			listdir();
			cached = true;
		}
		return _childs;
	}

	bool _cached_is_file_dir, _directory;
	override bool is_file() { if (_cached_is_file_dir) return !_directory; try { return std.file.isfile(path) != 0; } catch { return false; } }
	override bool is_dir() { if (_cached_is_file_dir) return _directory; try { return std.file.isdir(path) != 0; } catch { return false; } }
}

version (test_sfs) {
	void main() {
		auto fs = new FS_Entry();
		fs.mount("test", new Directory("."));
		fs["test"].create_dir("test");
		auto test = fs["test/test/demo.txt"];
		writefln((cast(Directory)test).path);
		auto s = test.open(FileMode.OutNew);
		s.writefln("test");
		s.close();
	}
}