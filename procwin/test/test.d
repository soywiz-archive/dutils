import procwin;
import std.string, std.stdio, std.stream, std.file, std.path, std.math, std.c.windows.windows, std.c.stdio, std.c.string, std.utf;

struct REMOTE_DATA {
	uint v;
}

extern(C) int test_function(REMOTE_DATA* data = null) {
	//writefln("aaaaaaa");
	data.v = 5;
	return 0;
} void test_function_end() { return; }

void do_process(Process p) {
	REMOTE_DATA data;
	writefln(p.base_name);
	
	p.prepare_rw();
	auto info = p.execute(cast(ubyte[])(&data)[0..1], cast(void *)&test_function, cast(void *)&test_function_end);

	void read_data() {
		auto s = new SliceStream(info.data, 0);
		s.read(cast(ubyte[])(&data)[0..1]);
	}

	Sleep(10);
	read_data();
	writefln(data.v);
	
	//writefln(w.process);
}

void main() {
	//writefln((&test_function)[0..1].length);

	/*foreach (p; Process.list) {
		writefln(p.pe.pcPriClassBase);
	}*/
	
	//writefln(Process.ListWindows.length);
	
	//writefln(&test_function);
	//writefln(&test_function_ward);
	
	foreach (w; Process.ListWindows()) {
		if (w.get_class == "yumemirukusuri") {
			auto p = w.process;
			//do_process(w.process);
			writefln(p);
			p.inject("xmllite.dll");
		}
	}
}