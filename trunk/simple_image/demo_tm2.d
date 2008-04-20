import simple_image.simple_image;

import std.stream;
import std.stdio;

int main(char[][] args) {
	Image i;
	
	i = ImageFileFormatProvider.read(new File("S_DB_GAME.TM2"));

	foreach (k, ic; i.childs) {
		Image ic32 = new Bitmap32(ic.width, ic.height);
		ic32.copyFrom(ic);
		ImageFileFormatProvider["png"].write(ic32, std.string.format("1/%d.png", k));
	}

	//ImageFileFormatProvider.read(new File("samples/sample32.png")).createPalette(16);

	return 0;
}