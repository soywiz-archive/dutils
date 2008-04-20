import simple_image.simple_image;

import std.stream;
import std.stdio;

int main(char[][] args) {
	Image i;
	
	i = ImageFileFormatProvider.read(new File("test.tm2"));

	foreach (k, ic; i.childs) {
		ImageFileFormatProvider["png"].write(ic, std.string.format("1/%d.png", k));
	}

	//ImageFileFormatProvider.read(new File("samples/sample32.png")).createPalette(16);

	return 0;
}