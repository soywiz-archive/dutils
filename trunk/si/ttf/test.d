import std.stdio, std.stream, std.file, std.path;
import si, si_ttf;

void main() {
	auto font = Font.fromFile("verdana.ttf");
	auto text = font.draw("hola", RGBA(0x00, 0x00, 0xFF));
	auto bmp = new Bitmap32(320, 240);
	text.draw(bmp, 50, 50);
	text.draw(bmp, 51, 50);
	
	ImageFileFormatProvider["png"].write(bmp, "test.png");
}