module sfs;

import std.string, std.stream, std.file, std.path, std.stdio;

class FS_Entry {
	char[] name;
	private FS_Entry _parent;

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

	FS_Entry parent(FS_Entry fe) {
		_parent = fe;
		if (_parent is null) _parent = this;
		return _parent;
	}
	FS_Entry parent() { return this; }
	FS_Entry[] childs() { return []; }
	
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
	
	ulong atime() { return 0; }
	ulong atime(ulong) { return 0; }
	ulong mtime() { return 0; }
	ulong mtime(ulong) { return 0; }
	ulong ctime() { return 0; }
	ulong ctime(ulong) { return 0; }
	
	ulong attribs() { return 0; }
	ulong attribs(ulong) { return 0; }
	
	ulong owner() { return 0; }
	ulong owner(ulong) { return 0; }

	ulong group() { return 0; }
	ulong group(ulong) { return 0; }
	
	Stream open(FileMode mode = FileMode.In, bool grow = false) { throw(new Exception("Not implemented: 'open'")); }
	void close() { throw(new Exception("Not implemented: 'close'")); }
	void replace(Stream s) {
		Stream cs = open(FileMode.OutNew);
		
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
		int pos = find(path, "/");
		char[] base, sub;
		
		writefln(this);
		
		if (pos >= 0) return child2(path[0..pos])[path[pos + 1..path.length]];
		
		return child2(path);
	}
}

class Directory : FS_Entry {
	char[] path;
	
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
	
	bool cached; FS_Entry[] _childs;
	FS_Entry[] childs() {
		if (!cached) {
			foreach (cname; listdir(path)) {
				_childs ~= new Directory(child_path(cname), cname, this);
			}
			cached = true;
		}
		return _childs;
	}

	override bool is_file() { try { return std.file.isfile(path) != 0; } catch { return false; } }
	override bool is_dir() { try { return std.file.isdir(path) != 0; } catch { return false; } }
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