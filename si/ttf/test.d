import std.stdio, std.stream, std.file, std.path;
import si, si_ttf;

void main() {
	auto font = Font.fromFile("verdana.ttf");
	auto text = font.render("hola", RGBA(0x00, 0x00, 0xFF));
	auto bmp = new Bitmap32(320, 240);
	text.blit(bmp, 50, 50);
	text.blit(bmp, 51, 50);
	
	bmp.write("test.png");
}