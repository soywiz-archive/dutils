import simple_image;

import std.stream;

version = demo_32;
version = demo_24;
version = demo_8;

version = demo_png;
version = demo_tga;

int main(char[][] args) {
	Image i;

	/*
	version (demo_32) {
		i = ImageFileFormatProvider.read(new File("samples/sample32.png"));
		version(demo_png) ImageFileFormatProvider["png"].write(i, new File("output/test32.png", FileMode.OutNew));
		version(demo_tga) ImageFileFormatProvider["tga"].write(i, new File("output/test32.tga", FileMode.OutNew));
	}

	version (demo_24) {
		i = ImageFileFormatProvider.read(new File("samples/sample24.png"));
		version(demo_png) ImageFileFormatProvider["png"].write(i, new File("output/test24.png", FileMode.OutNew));
		version(demo_tga) ImageFileFormatProvider["tga"].write(i, new File("output/test24.tga", FileMode.OutNew));
	}

	version (demo_8) {
		i = ImageFileFormatProvider.read(new File("samples/sample8.png"));
		version(demo_png) ImageFileFormatProvider["png"].write(i, new File("output/test8.png", FileMode.OutNew));
		version(demo_tga) ImageFileFormatProvider["tga"].write(i, new File("output/test8.tga", FileMode.OutNew));
	}*/

	//i = ImageFileFormatProvider.read(new File("B01_1A.BMP"));
	//ImageFileFormatProvider["png"].write(i, new File("B01_1A.PNG", FileMode.OutNew));
	
	i = ImageFileFormatProvider.read(new File("logo.png"));
	version(demo_png) ImageFileFormatProvider["png"].write(i, new File("logo2.png", FileMode.OutNew));
	

	//ImageFileFormatProvider.read(new File("samples/sample32.png")).createPalette(16);

	return 0;
}