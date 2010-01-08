/*
CD digital audio: 2352 Data
CD-ROM (mode 1):  12 Sync + 4 Sector ID + 2048 Data + 4 Error Detection + 8 Zero + 276 Error Correction
CD-ROM (mode 2):  12 Sync + 4 Sector ID + 2336 Data
*/
ubyte[] GenerateSector(ubyte[] data, ubyte[] _data, int minute, int second, int frame, int mode, int form = 0, bool EOR = false, bool EOF = false) in {
	assert(data.length == 0x930);
} body {
	static const ubyte rs_l12_alog[255] = [1, 2, 4, 8,16,32,64,128,29,58,116,232,205,135,19,38,76,152,45,90,180,117,234,201,143, 3, 6,12,24,48,96,192,157,39,78,156,37,74,148,53,106,212,181,119,238,193,159,35,70,140, 5,10,20,40,80,160,93,186,105,210,185,111,222,161,95,190,97,194,153,47,94,188,101,202,137,15,30,60,120,240,253,231,211,187,107,214,177,127,254,225,223,163,91,182,113,226,217,175,67,134,17,34,68,136,13,26,52,104,208,189,103,206,129,31,62,124,248,237,199,147,59,118,236,197,151,51,102,204,133,23,46,92,184,109,218,169,79,158,33,66,132,21,42,84,168,77,154,41,82,164,85,170,73,146,57,114,228,213,183,115,230,209,191,99,198,145,63,126,252,229,215,179,123,246,241,255,227,219,171,75,150,49,98,196,149,55,110,220,165,87,174,65,130,25,50,100,200,141, 7,14,28,56,112,224,221,167,83,166,81,162,89,178,121,242,249,239,195,155,43,86,172,69,138, 9,18,36,72,144,61,122,244,245,247,243,251,235,203,139,11,22,44,88,176,125,250,233,207,131,27,54,108,216,173,71,142];
	static const ubyte rs_l12_log [256] = [0, 0, 1,25, 2,50,26,198, 3,223,51,238,27,104,199,75, 4,100,224,14,52,141,239,129,28,193,105,248,200, 8,76,113, 5,138,101,47,225,36,15,33,53,147,142,218,240,18,130,69,29,181,194,125,106,39,249,185,201,154, 9,120,77,228,114,166, 6,191,139,98,102,221,48,253,226,152,37,179,16,145,34,136,54,208,148,206,143,150,219,189,241,210,19,92,131,56,70,64,30,66,182,163,195,72,126,110,107,58,40,84,250,133,186,61,202,94,155,159,10,21,121,43,78,212,229,172,115,243,167,87, 7,112,192,247,140,128,99,13,103,74,222,237,49,197,254,24,227,165,153,119,38,184,180,124,17,68,146,217,35,32,137,46,55,63,209,91,149,188,207,205,144,135,151,178,220,252,190,97,242,86,211,171,20,42,93,158,132,60,57,83,71,109,65,162,31,45,67,216,183,123,164,118,196,23,73,236,127,12,111,246,108,161,59,82,41,157,85,170,251,96,134,177,187,204,62,90,203,89,95,176,156,169,160,81,11,245,22,235,122,117,44,215,79,174,213,233,230,231,173,232,116,214,244,234,168,80,88,175];
	static const ubyte DQ[2][43] = [[190,96,250,132,59,81,159,154,200,7,111,245,10,20,41,156,168,79,173,231,229,171,210,240,17,67,215,43,120,8,199,74,102,220,251,95,175,87,166,113,75,198,25], [97,251,133,60,82,160,155,201,8,112,246,11,21,42,157,169,80,174,232,230,172,211,241,18,68,216,44,121,9,200,75,103,221,252,96,176,88,167,114,76,199,26,1]];
	static const ubyte DP[2][24] = [[231,229,171,210,240,17,67,215,43,120,8,199,74,102,220,251,95,175,87,166,113,75,198,25], [230,172,211,241,18,68,216,44,121,9,200,75,103,221,252,96,176,88,167,114,76,199,26,1]];
	static const uint  EDC_crctable[0x100] = [0x00000000, 0x90910101, 0x91210201, 0x01B00300, 0x92410401, 0x02D00500, 0x03600600, 0x93F10701, 0x94810801, 0x04100900, 0x05A00A00, 0x95310B01, 0x06C00C00, 0x96510D01, 0x97E10E01, 0x07700F00, 0x99011001, 0x09901100, 0x08201200, 0x98B11301, 0x0B401400, 0x9BD11501, 0x9A611601, 0x0AF01700, 0x0D801800, 0x9D111901, 0x9CA11A01, 0x0C301B00, 0x9FC11C01, 0x0F501D00, 0x0EE01E00, 0x9E711F01, 0x82012001, 0x12902100, 0x13202200, 0x83B12301, 0x10402400, 0x80D12501, 0x81612601, 0x11F02700, 0x16802800, 0x86112901, 0x87A12A01, 0x17302B00, 0x84C12C01, 0x14502D00, 0x15E02E00, 0x85712F01, 0x1B003000, 0x8B913101, 0x8A213201, 0x1AB03300, 0x89413401, 0x19D03500, 0x18603600, 0x88F13701, 0x8F813801, 0x1F103900, 0x1EA03A00, 0x8E313B01, 0x1DC03C00, 0x8D513D01, 0x8CE13E01, 0x1C703F00, 0xB4014001, 0x24904100, 0x25204200, 0xB5B14301, 0x26404400, 0xB6D14501, 0xB7614601, 0x27F04700, 0x20804800, 0xB0114901, 0xB1A14A01, 0x21304B00, 0xB2C14C01, 0x22504D00, 0x23E04E00, 0xB3714F01, 0x2D005000, 0xBD915101, 0xBC215201, 0x2CB05300, 0xBF415401, 0x2FD05500, 0x2E605600, 0xBEF15701, 0xB9815801, 0x29105900, 0x28A05A00, 0xB8315B01, 0x2BC05C00, 0xBB515D01, 0xBAE15E01, 0x2A705F00, 0x36006000, 0xA6916101, 0xA7216201, 0x37B06300, 0xA4416401, 0x34D06500, 0x35606600, 0xA5F16701, 0xA2816801, 0x32106900, 0x33A06A00, 0xA3316B01, 0x30C06C00, 0xA0516D01, 0xA1E16E01, 0x31706F00, 0xAF017001, 0x3F907100, 0x3E207200, 0xAEB17301, 0x3D407400, 0xADD17501, 0xAC617601, 0x3CF07700, 0x3B807800, 0xAB117901, 0xAAA17A01, 0x3A307B00, 0xA9C17C01, 0x39507D00, 0x38E07E00, 0xA8717F01, 0xD8018001, 0x48908100, 0x49208200, 0xD9B18301, 0x4A408400, 0xDAD18501, 0xDB618601, 0x4BF08700, 0x4C808800, 0xDC118901, 0xDDA18A01, 0x4D308B00, 0xDEC18C01, 0x4E508D00, 0x4FE08E00, 0xDF718F01, 0x41009000, 0xD1919101, 0xD0219201, 0x40B09300, 0xD3419401, 0x43D09500, 0x42609600, 0xD2F19701, 0xD5819801, 0x45109900, 0x44A09A00, 0xD4319B01, 0x47C09C00, 0xD7519D01, 0xD6E19E01, 0x46709F00, 0x5A00A000, 0xCA91A101, 0xCB21A201, 0x5BB0A300, 0xC841A401, 0x58D0A500, 0x5960A600, 0xC9F1A701, 0xCE81A801, 0x5E10A900, 0x5FA0AA00, 0xCF31AB01, 0x5CC0AC00, 0xCC51AD01, 0xCDE1AE01, 0x5D70AF00, 0xC301B001, 0x5390B100, 0x5220B200, 0xC2B1B301, 0x5140B400, 0xC1D1B501, 0xC061B601, 0x50F0B700, 0x5780B800, 0xC711B901, 0xC6A1BA01, 0x5630BB00, 0xC5C1BC01, 0x5550BD00, 0x54E0BE00, 0xC471BF01, 0x6C00C000, 0xFC91C101, 0xFD21C201, 0x6DB0C300, 0xFE41C401, 0x6ED0C500, 0x6F60C600, 0xFFF1C701, 0xF881C801, 0x6810C900, 0x69A0CA00, 0xF931CB01, 0x6AC0CC00, 0xFA51CD01, 0xFBE1CE01, 0x6B70CF00, 0xF501D001, 0x6590D100, 0x6420D200, 0xF4B1D301, 0x6740D400, 0xF7D1D501, 0xF661D601, 0x66F0D700, 0x6180D800, 0xF111D901, 0xF0A1DA01, 0x6030DB00, 0xF3C1DC01, 0x6350DD00, 0x62E0DE00, 0xF271DF01, 0xEE01E001, 0x7E90E100, 0x7F20E200, 0xEFB1E301, 0x7C40E400, 0xECD1E501, 0xED61E601, 0x7DF0E700, 0x7A80E800, 0xEA11E901, 0xEBA1EA01, 0x7B30EB00, 0xE8C1EC01, 0x7850ED00, 0x79E0EE00, 0xE971EF01, 0x7700F000, 0xE791F101, 0xE621F201, 0x76B0F300, 0xE541F401, 0x75D0F500, 0x7460F600, 0xE4F1F701, 0xE381F801, 0x7310F900, 0x72A0FA00, 0xE231FB01, 0x71C0FC00, 0xE151FD01, 0xE0E1FE01, 0x7070FF00];

	static const uint RS_L12_BITS = 8;
	static const uint L2_P = 43 * 2 * 2;
	static const uint L2_Q = 26 * 2 * 2;

	static void SetECC_Q(ubyte[] _data, ubyte[] _output) in {
		assert(_data.length == 4 + 0x800 + 4 + 8 + L2_P);
		assert(_output.length == L2_Q);	
	} body {
		ubyte* output = _output.ptr;
		
		for (int j = 0; j < 26; j++, output += 2) for (int i = 0; i < 43; i++) for (int n = 0; n < 2; n++) {
			ubyte cdata = _data[(j * 43 * 2 + i * 2 * 44 + n) % (4 + 0x800 + 4 + 8 + L2_P)];
			if (cdata == 0) continue;
			
			int base = rs_l12_log[cdata];
			
			void process(int t) {
				uint sum = base + DQ[t][i];
				if (sum >= ((1 << RS_L12_BITS) - 1)) sum -= (1 << RS_L12_BITS) - 1;
				output[26 * 2 * t + n] ^= rs_l12_alog[sum];
			}
			
			process(0); process(1);
		}
	}

	static void SetECC_P(ubyte[] _data, ubyte[] _output) in {
		assert(_data.length == 43 * 24 * 2);
		assert(_output.length == L2_P);
	} body {
		ubyte* data   = _data.ptr;
		ubyte* output = _output.ptr;

		for (int j = 0; j < 43; j++, output += 2, data += 2) for (int i = 0; i < 24; i++) for (int n = 0; n < 2; n++) {
			ubyte cdata = data[i * 2 * 43 + n];
			if (cdata == 0) continue;
			
			uint base = rs_l12_log[cdata];
			
			void process(int t) {
				uint sum = base + DP[t][i];
				if (sum >= ((1 << RS_L12_BITS) - 1)) sum -= (1 << RS_L12_BITS) - 1;
				output[43 * 2 * t + n] ^= rs_l12_alog[sum];
			}				
			
			process(0); process(1);
		}
	}

	static void SetAddress(ubyte[] data, int minute, int second, int frame, int mode) in { // Sector ID.
		assert(data.length == 4);
	} body {
		data[0] = minute;
		data[1] = second;
		data[2] = frame;
		data[3] = mode;
	}

	static void SetSync(ubyte[] sync) in {
		assert(sync.length == 12);
	} body {
		sync[0..12] = cast(ubyte[])x"00FFFFFFFFFFFFFFFFFFFF00";
	}

	static void SetEDC(ubyte[] edc, ubyte[] data) in {
		assert(edc.length == 4);
	} body  {
		uint edc_i = 0;
		foreach (c; data) edc_i = EDC_crctable[(edc_i ^ c) & 0xFF] ^ (edc_i >> 8);
		
		edc[0] = ((edc_i >>  0) & 0xFF);
		edc[1] = ((edc_i >>  8) & 0xFF);
		edc[2] = ((edc_i >> 16) & 0xFF);
		edc[3] = ((edc_i >> 24) & 0xFF);
	}

	static void SetSubheader(ubyte[] data, int mode, int form, bool EOR, bool EOF) in {
		assert(data.length == 8);
	} body {
		ubyte inf = 8 | (1 * EOR) | (128 * EOF);
		
		if (mode == 2 && form == 2) inf |= 32;

		data[0] = data[4] = 0;  // File Number
		data[1] = data[5] = 0;  // Channel Number
		data[2] = data[6] = inf;
		data[3] = data[7] = 0;  // Coding Info
	}

	// Sets SyncData
	SetSync(data[0..12]);

	// Sets SubHeader
	SetSubheader(data[0x10..0x18], mode, form, EOR, EOF);

	switch (mode) {
		default: assert(mode != 0, "Unimplemented Sector Mode");
		case 0: break;
		case 1:
			SetEDC(data[0x810..0x810 + 4], data[0..0x810]);
			SetECC_P(data[12..12 + 2064], data[0x81C..0x8C8]);
			SetECC_Q(data[12..12 + 4 + 0x800 + 4 + 8 + L2_P], data[0x8C8..0x930]);
		break;
		case 2:
			if (form < 2) {
				// Copy data
				assert(_data.length == 0x800);
				data[0x18..0x18 + 0x800] = _data[0..0x800];
			}
			
			switch (form) {
				default: assert(form != 0, "Unimplemented Sector Mode 2 Form");
				case 0: break;
				case 1:
					// Sets EDC
					SetEDC(data[0x818..0x818 + 4], data[0x10..0x818]);
					// Sets ECC P+Q
					SetECC_P(data[12..12 + 2064], data[0x81C..0x8C8]);
					SetECC_Q(data[12..12 + 4 + 0x800 + 4 + 8 + L2_P], data[0x8C8..0x930]);
				break;
				case 2:
					// Copy Data
					assert(_data.length == 0x92C);
					data[0x18..0x18 + 0x92C] = _data[0..0x92C];
					// Sets EDC
					SetEDC(data[0x92C..0x92C + 4], data[0x10..0x92C]);
				break;
			}
		break;
	}
	
	if (mode != 0) {
		SetAddress(data[12..16], minute, second, frame, mode);
	}
	
	return data;
}

unittest {
	ubyte[0x930] sector;
	ubyte[0x800] data;
	GenerateSector(sector, data, /* minute */ 0, /* second */ 2, /* frame */ 0, /* mode */ 2, /* form */ 1);
	assert(
		cast(ubyte[])sector
		==
		(
			cast(ubyte[])
			x"00FFFFFFFFFFFFFFFFFFFF00000200020000080000000800" ~ 
			cast(ubyte[])data ~
			cast(ubyte[])
			x"0B888194000000000000FB000000FB00000000000000000000000000000000000000000000000000"
			x"00000000000000000000000000000000000000000000000000000000000000000000000000000000"
			x"0000000000001D859EA1000000000000F3000000F300000000000000000000000000000000000000"
			x"00000000000000000000000000000000000000000000000000000000000000000000000000000000"
			x"000000000000000000000000160D1F3500000000000000000000000000009EA18E6172E362230000"
			x"0000000000000000000000000000B900D200A5006700A90000000000000000000000000000000000"
			x"00001F351B487053742E000000000000000000000000000000004200210056009400A10000000000"
		)
	);
}

void main() { }