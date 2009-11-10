/*
  Dokan : user-mode file system library for Windows

  Copyright (C) 2008 Hiroki Asakawa info@dokan-dev.net

  http://dokan-dev.net/en

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU Lesser General Public License as published by the Free
Software Foundation; either version 3 of the License, or (at your option) any
later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU Lesser General Public License along
with this program. If not, see <http://www.gnu.org/licenses/>.
*/
module dokan;

public import std.stdio, std.stream, std.file, std.path, std.utf, std.string;
public import std.c.windows.windows;

static int strlen(wchar *s) { int c; while (*s++ != 0) c++; return c; }
static wchar[] towchar(wchar *s) { return s[0..strlen(s)]; }
static void copywchar(wchar[] to, wchar[] from) {
	int len = ((to.length - 1) < from.length) ? (to.length - 1) : from.length;
	to[0..len] = from[0..len]; to[len] = 0;
}

// Error Codes (ERROR_SUCCESS, ...): http://msdn.microsoft.com/en-us/library/ms681382(VS.85).aspx
extern (Windows) {
	const wchar[] DOKAN_DRIVER_NAME = "dokan.sys";
	
	void OutputDebugStringW(wchar *);
  
	struct BY_HANDLE_FILE_INFORMATION {
		uint     FileAttributes;
		FILETIME CreationTime;
		FILETIME LastAccessTime;
		FILETIME LastWriteTime;
		uint     VolumeSerialNumber;
		uint     FileSizeHigh;
		uint     FileSizeLow;
		uint     NumberOfLinks;
		uint     FileIndexHigh;
		uint     FileIndexLow;
	}

	struct WIN32_FIND_DATAW {
		uint     FileAttributes;
		FILETIME CreationTime;
		FILETIME LastAccessTime;
		FILETIME LastWriteTime;
		uint     FileSizeHigh;
		uint     FileSizeLow;
		uint     Reserved0;
		uint     Reserved1;
		wchar    FileName[MAX_PATH];
		wchar    AlternateFileName[14];
	}

	struct DOKAN_OPTIONS {
		wchar    DriveLetter;   // drive letter to be mounted
		ushort   ThreadCount;   // number of threads to be used
		ubyte    DebugMode;     // ouput debug message
		ubyte    UseStdErr;     // ouput debug message to stderr
		ubyte    UseAltStream;  // use alternate stream
		ubyte    UseKeepAlive;  // use auto unmount
		ulong    GlobalContext; // FileSystem can use this variable
		
		static assert (DOKAN_OPTIONS.sizeof == 16);
	}

	struct DOKAN_FILE_INFO {
		ulong  Context;       // FileSystem can use this variable
		ulong  DokanContext;  // Don't touch this
		uint   ProcessId;     // process id for the thread that originally requested a given I/O operation
		ubyte  IsDirectory;   // requesting a directory file
		ubyte  DeleteOnClose; // Delete on when "cleanup" is called
		DOKAN_OPTIONS* DokanOptions;
		
		static assert (DOKAN_FILE_INFO.sizeof == 32);
	}
	
	alias int function(WIN32_FIND_DATAW*, DOKAN_FILE_INFO*) FINDCALLBACK;
	
	struct DOKAN_OPERATIONS {
		/* CreateFile           */ int function(wchar* FileName, uint DesiredAccess, uint ShareMode, uint CreationDisposition, uint FlagsAndAttributes, DOKAN_FILE_INFO* DokanFileInfo) CreateFile;
		/* OpenDirectory        */ int function(wchar* FileName, DOKAN_FILE_INFO* DokanFileInfo) OpenDirectory;
		/* CreateDirectory      */ int function(wchar* FileName, DOKAN_FILE_INFO* DokanFileInfo) CreateDirectory;
		/* Cleanup              */ int function(wchar* FileName, DOKAN_FILE_INFO* DokanFileInfo) Cleanup;
		/* CloseFile            */ int function(wchar* FileName, DOKAN_FILE_INFO* DokanFileInfo) CloseFile;
		/* ReadFile             */ int function(wchar* FileName, void* Buffer, uint NumberOfBytesToRead,  uint* NumberOfBytesRead,    ulong Offset, DOKAN_FILE_INFO* DokanFileInfo) ReadFile;
		/* WriteFile            */ int function(wchar* FileName, void* Buffer, uint NumberOfBytesToWrite, uint* NumberOfBytesWritten, ulong Offset, DOKAN_FILE_INFO* DokanFileInfo) WriteFile;
		/* FlushFileBuffers     */ int function(wchar* FileName, DOKAN_FILE_INFO* DokanFileInfo) FlushFileBuffers;
		/* GetFileInformation   */ int function(wchar* FileName, BY_HANDLE_FILE_INFORMATION* Buffer, DOKAN_FILE_INFO* DokanFileInfo) GetFileInformation;
		/* FindFiles            */ int function(wchar* PathName, FINDCALLBACK Callback, DOKAN_FILE_INFO* DokanFileInfo) FindFiles;
		/* FindFilesWithPattern */ int function(wchar* PathName, wchar* SearchPattern, FINDCALLBACK Callback, DOKAN_FILE_INFO* DokanFileInfo) FindFilesWithPattern;
		/* SetFileAttributes    */ int function(wchar* FileName, uint FileAttributes, DOKAN_FILE_INFO* DokanFileInfo) SetFileAttributes;
		/* SetFileTime          */ int function(wchar* FileName, FILETIME* CreationTime, FILETIME* LastAccessTime, FILETIME* LastWriteTime, DOKAN_FILE_INFO* DokanFileInfo) SetFileTime;
		/* DeleteFile           */ int function(wchar* FileName, DOKAN_FILE_INFO* DokanFileInfo) DeleteFile;
		/* DeleteDirectory      */ int function(wchar* FileName, DOKAN_FILE_INFO* DokanFileInfo) DeleteDirectory;
		/* MoveFile             */ int function(wchar* ExistingFileName, wchar* NewFileName, bool ReplaceExisting, DOKAN_FILE_INFO* DokanFileInfo) MoveFile;
		/* SetEndOfFile         */ int function(wchar* FileName, ulong Length, DOKAN_FILE_INFO* DokanFileInfo) SetEndOfFile;
		/* LockFile             */ int function(wchar* FileName, ulong ByteOffset, ulong Length, DOKAN_FILE_INFO* DokanFileInfo) LockFile;
		/* UnlockFile           */ int function(wchar* FileName, ulong ByteOffset, ulong Length, DOKAN_FILE_INFO* DokanFileInfo) UnlockFile;
		/* GetDiskFreeSpace     */ int function(ulong* FreeBytesAvailable, ulong* TotalNumberOfBytes, ulong* TotalNumberOfFreeBytes, DOKAN_FILE_INFO* DokanFileInfo) GetDiskFreeSpace;
		/* GetVolumeInformation */ int function(wchar* VolumeNameBuffer, uint VolumeNameSize, uint* VolumeSerialNumber, uint* MaximumComponentLength, uint *FileSystemFlags, wchar* FileSystemNameBuffer, uint FileSystemNameSize, DOKAN_FILE_INFO* DokanFileInfo) GetVolumeInformation;
		/* Unmount              */ int function(DOKAN_FILE_INFO* DokanFileInfo) Unmount;

		static assert (DOKAN_OPERATIONS.sizeof == 88);
	}
	
	enum {
		DOKAN_SUCCESS				=  0,
		DOKAN_ERROR					= -1, // General Error
		DOKAN_DRIVE_LETTER_ERROR	= -2, // Bad Drive letter
		DOKAN_DRIVER_INSTALL_ERROR	= -3, // Can't install driver
		DOKAN_START_ERROR			= -4, // Driver something wrong
		DOKAN_MOUNT_ERROR			= -5, // Can't assign a drive letter
	}

	int  function(DOKAN_OPTIONS* DokanOptions, DOKAN_OPERATIONS* DokanOperations) DokanMain;
	bool function(wchar DriveLetter) DokanUnmount;
	bool function(wchar* Expression, wchar* Name, bool IgnoreCase) DokanIsNameInExpression;
	uint function() DokanVersion;
	uint function() DokanDriverVersion;
	
	static HMODULE library;
	static this() {
		static char[] func(char[] name) { return "*cast(void **)&" ~ name ~ " = cast(void *)GetProcAddress(library, \"" ~ name ~ "\");"; }
		library = LoadLibraryA("dokan.dll");
		mixin(func("DokanMain"));
		mixin(func("DokanUnmount"));
		mixin(func("DokanIsNameInExpression"));
		mixin(func("DokanVersion"));
		mixin(func("DokanDriverVersion"));
	}
	static ~this() {
		FreeLibrary(library);
	}
}

class Dokan {
	wchar DriveLetter;
	bool DebugMode;

	extern (Windows) {
		static Dokan opCall(DOKAN_FILE_INFO* DokanFileInfo) { return (cast(Dokan)cast(void *)DokanFileInfo.DokanOptions.GlobalContext); }
		static const char[] check_context = "if (!DokanFileInfo.DokanOptions.GlobalContext) return -1;";

		static char[] StaticParameter0(char[] name) { return "static int Static_" ~ name ~ "(DOKAN_FILE_INFO* DokanFileInfo) { mixin(check_context); return Dokan(DokanFileInfo)." ~ name ~ "(DokanFileInfo); }"; }
		static char[] StaticParameter1(char[] name) { return "static int Static_" ~ name ~ "(wchar* FileName, DOKAN_FILE_INFO* DokanFileInfo) { mixin(check_context); return Dokan(DokanFileInfo)." ~ name ~ "(towchar(FileName), DokanFileInfo); }"; }
		
		static int Static_CreateFile(wchar* FileName, uint DesiredAccess, uint ShareMode, uint CreationDisposition, uint FlagsAndAttributes, DOKAN_FILE_INFO* DokanFileInfo) {
			mixin(check_context); return Dokan(DokanFileInfo).CreateFile(towchar(FileName), DesiredAccess, ShareMode, CreationDisposition, FlagsAndAttributes, DokanFileInfo);
		}

		static int Static_GetDiskFreeSpace(ulong* FreeBytesAvailable, ulong* TotalNumberOfBytes, ulong* TotalNumberOfFreeBytes, DOKAN_FILE_INFO* DokanFileInfo) {
			mixin(check_context); return Dokan(DokanFileInfo).GetDiskFreeSpace(*FreeBytesAvailable, *TotalNumberOfBytes, *TotalNumberOfFreeBytes, DokanFileInfo);
		}
		
		static int Static_GetVolumeInformation(wchar* VolumeNameBuffer, uint VolumeNameSize, uint* VolumeSerialNumber, uint* MaximumComponentLength, uint *FileSystemFlags, wchar* FileSystemNameBuffer, uint FileSystemNameSize, DOKAN_FILE_INFO* DokanFileInfo) {
			mixin(check_context);
			wchar[] VolumeName, FileSystemName;
			auto retval = Dokan(DokanFileInfo).GetVolumeInformation(VolumeName, *VolumeSerialNumber, *MaximumComponentLength, *FileSystemFlags, FileSystemName, DokanFileInfo);
			copywchar(VolumeNameBuffer[0..VolumeNameSize], VolumeName);
			copywchar(FileSystemNameBuffer[0..FileSystemNameSize], FileSystemName);
			return retval;
		}
		
		static int Static_FindFiles(wchar* PathName, FINDCALLBACK Callback, DOKAN_FILE_INFO* DokanFileInfo) {
			mixin(check_context); return Dokan(DokanFileInfo).FindFiles(towchar(PathName), Callback, DokanFileInfo);
		}
		
		static int Static_FindFilesWithPattern(wchar* PathName, wchar* Pattern, FINDCALLBACK Callback, DOKAN_FILE_INFO* DokanFileInfo) {
			mixin(check_context); return Dokan(DokanFileInfo).FindFilesWithPattern(towchar(PathName), towchar(Pattern), Callback, DokanFileInfo);
		}

		static int Static_LockFile(wchar* FileName, ulong ByteOffset, ulong Length, DOKAN_FILE_INFO* DokanFileInfo) {
			mixin(check_context); return Dokan(DokanFileInfo).LockFile(towchar(FileName), ByteOffset, Length, DokanFileInfo);
		}

		static int Static_UnlockFile(wchar* FileName, ulong ByteOffset, ulong Length, DOKAN_FILE_INFO* DokanFileInfo) {
			mixin(check_context); return Dokan(DokanFileInfo).UnlockFile(towchar(FileName), ByteOffset, Length, DokanFileInfo);
		}

		static int Static_GetFileInformation(wchar* FileName, BY_HANDLE_FILE_INFORMATION* Buffer, DOKAN_FILE_INFO* DokanFileInfo) {
			mixin(check_context); return Dokan(DokanFileInfo).GetFileInformation(towchar(FileName), *Buffer, DokanFileInfo);
		}

		static int Static_SetFileAttributes(wchar* FileName, uint FileAttributes, DOKAN_FILE_INFO* DokanFileInfo) {
			mixin(check_context); return Dokan(DokanFileInfo).SetFileAttributes(towchar(FileName), FileAttributes, DokanFileInfo);
		}
		static int Static_SetFileTime(wchar* FileName, FILETIME* CreationTime, FILETIME* LastAccessTime, FILETIME* LastWriteTime, DOKAN_FILE_INFO* DokanFileInfo) {
			mixin(check_context); return Dokan(DokanFileInfo).SetFileTime(towchar(FileName), *CreationTime, *LastAccessTime, *LastWriteTime, DokanFileInfo);
		}

		static int Static_MoveFile(wchar* ExistingFileName, wchar* NewFileName, bool ReplaceExisting, DOKAN_FILE_INFO* DokanFileInfo) {
			mixin(check_context); return Dokan(DokanFileInfo).MoveFile(
				towchar(ExistingFileName),
				towchar(NewFileName),
				ReplaceExisting,
				DokanFileInfo
			);
		}
		static int Static_SetEndOfFile(wchar* FileName, ulong Length, DOKAN_FILE_INFO* DokanFileInfo) {
			mixin(check_context); return Dokan(DokanFileInfo).SetEndOfFile(
				towchar(FileName),
				Length,
				DokanFileInfo
			);
		}

		static int Static_ReadFile(wchar* FileName, void* Buffer, uint NumberOfBytesToRead, uint* NumberOfBytesRead, ulong Offset, DOKAN_FILE_INFO* DokanFileInfo) {
			mixin(check_context); return Dokan(DokanFileInfo).ReadFile(
				towchar(FileName),
				Buffer,
				NumberOfBytesToRead,
				*NumberOfBytesRead,
				Offset,
				DokanFileInfo
			);			
		}

		static int Static_WriteFile(wchar* FileName, void* Buffer, uint NumberOfBytesToWrite, uint* NumberOfBytesWritten, ulong Offset, DOKAN_FILE_INFO* DokanFileInfo) {
			mixin(check_context); return Dokan(DokanFileInfo).WriteFile(
				towchar(FileName),
				Buffer,
				NumberOfBytesToWrite,
				*NumberOfBytesWritten,
				Offset,
				DokanFileInfo
			);			
		}

		mixin(StaticParameter1("FlushFileBuffers"));
		mixin(StaticParameter1("DeleteFile"));
		mixin(StaticParameter1("DeleteDirectory"));
		mixin(StaticParameter1("Cleanup"));
		mixin(StaticParameter1("OpenDirectory"));
		mixin(StaticParameter1("CreateDirectory"));
		mixin(StaticParameter1("CloseFile"));
		mixin(StaticParameter0("Unmount"));
	}

	int ReadFile(wchar[] FileName, void* Buffer, uint NumberOfBytesToRead, out uint NumberOfBytesRead, ulong Offset, DOKAN_FILE_INFO* DokanFileInfo) {
		writefln("!!Unprocessed ReadFile (FileName:'%s', NumberOfBytesToRead:%d, Offset:%d)", FileName, NumberOfBytesToRead, Offset);
		NumberOfBytesRead = NumberOfBytesToRead;
		return 0;
	}

	int WriteFile(wchar[] FileName, void* Buffer, uint NumberOfBytesToWrite, out uint NumberOfBytesWritten, ulong Offset, DOKAN_FILE_INFO* DokanFileInfo) {
		writefln("!!Unprocessed WriteFile (FileName:'%s', NumberOfBytesToWrite:%d, Offset:%d)", FileName, NumberOfBytesToWrite, Offset);
		NumberOfBytesWritten = NumberOfBytesToWrite;
		return 0;
	}

	int FlushFileBuffers(wchar[] FileName, DOKAN_FILE_INFO* DokanFileInfo) {
		writefln("!!Unprocessed FlushFileBuffers (FileName:'%s')", FileName);
		return 0;
	}

	int SetEndOfFile(wchar[] FileName, ulong Length, DOKAN_FILE_INFO* DokanFileInfo) {
		writefln("!!Unprocessed SetEndOfFile (FileName:'%s', Length:%d)", FileName, Length);
		return 0;
	}
	
	int MoveFile(wchar[] ExistingFileName, wchar[] NewFileName, bool ReplaceExisting, DOKAN_FILE_INFO* DokanFileInfo) {
		writefln("!!Unprocessed MoveFile (ExistingFileName:'%s', NewFileName:'%s', ReplaceExisting:%d)", ExistingFileName, NewFileName, ReplaceExisting);
		return 0;
	}
	
	int SetFileAttributes(wchar[] FileName, uint FileAttributes, DOKAN_FILE_INFO* DokanFileInfo) {
		writefln("!!Unprocessed SetFileAttributes (FileName:'%s', FileAttributes:%08X)", FileName, FileAttributes);
		return 0;
	}
	
	int SetFileTime(wchar[] FileName, in FILETIME CreationTime, in FILETIME LastAccessTime, in FILETIME LastWriteTime, DOKAN_FILE_INFO* DokanFileInfo) {
		writefln("!!Unprocessed SetFileTime (FileName:'%s', CreationTime:'%s', LastAccessTime:'%s', LastWriteTime:'%s')", FileName, cast(int)cast(void *)&CreationTime, cast(int)cast(void *)&LastAccessTime, cast(int)cast(void *)&LastWriteTime);
		return 0;
	}

	int LockFile(wchar[] FileName, ulong ByteOffset, ulong Length, DOKAN_FILE_INFO* DokanFileInfo) {
		writefln("!!Unprocessed LockFile (FileName:'%s', ByteOffset:%d, Length:%d)", FileName, ByteOffset, Length);
		return 0;
	}

	int UnlockFile(wchar[] FileName, ulong ByteOffset, ulong Length, DOKAN_FILE_INFO* DokanFileInfo) {
		writefln("!!Unprocessed UnlockFile (FileName:'%s', ByteOffset:%d, Length:%d)", FileName, ByteOffset, Length);
		return 0;
	}

	int GetFileInformation(wchar[] FileName, out BY_HANDLE_FILE_INFORMATION Buffer, DOKAN_FILE_INFO* DokanFileInfo) {
		writefln("!!Unprocessed GetFileInformation (FileName:'%s')", FileName);
		return 0;
	}
	
	int GetVolumeInformation(out wchar[] VolumeName, out uint VolumeSerialNumber, out uint MaximumComponentLength, out uint FileSystemFlags, out wchar[] FileSystemName, DOKAN_FILE_INFO* DokanFileInfo) {
		writefln("!!Unprocessed GetVolumeInformation");
		VolumeName             = "DokanVolume";
		FileSystemName         = "DokanFS";
		VolumeSerialNumber     = 0x_00_00_00_00;
		FileSystemFlags        = 0x_00_00_00_00;
		MaximumComponentLength = 255;
		return 0;
	}
	
	int GetDiskFreeSpace(out ulong FreeBytesAvailable, out ulong TotalNumberOfBytes, out ulong TotalNumberOfFreeBytes, DOKAN_FILE_INFO* DokanFileInfo) {
		writefln("!!Unprocessed GetDiskFreeSpace");
		FreeBytesAvailable     = 512 * (1024 * 1024);
		TotalNumberOfFreeBytes = 512 * (1024 * 1024);
		TotalNumberOfBytes     = 1024 * (1024 * 1024);
		return 0;
	}

	int FindFiles(wchar[] PathName, FINDCALLBACK Callback, DOKAN_FILE_INFO* DokanFileInfo) {
		writefln("!!Unprocessed FindFiles (PathName:'%s')", PathName);
		return 0;
	}

	int FindFilesWithPattern(wchar[] PathName, wchar[] Pattern, FINDCALLBACK Callback, DOKAN_FILE_INFO* DokanFileInfo) {
		writefln("!!Unprocessed FindFilesWithPattern (PathName:'%s', Pattern:'%s')", PathName, Pattern);
		return 0;
	}

	int CreateFile(wchar[] FileName, uint DesiredAccess, uint ShareMode, uint CreationDisposition, uint FlagsAndAttributes, DOKAN_FILE_INFO* DokanFileInfo) {
		writefln("!!Unprocessed CreateFile (FileName:'%s', DesiredAccess:%08X, SharedMode:%08X, CreationDisposition:%08X, FlagsAndAttributes:%08X)", FileName, DesiredAccess, ShareMode, CreationDisposition, FlagsAndAttributes);
		return 0;
	}

	int OpenDirectory(wchar[] FileName, DOKAN_FILE_INFO* DokanFileInfo) {
		writefln("!!Unprocessed OpenDirectory (FileName:'%s')", FileName);
		return 0;
	}

	int CreateDirectory(wchar[] FileName, DOKAN_FILE_INFO* DokanFileInfo) {
		writefln("!!Unprocessed CreateDirectory (FileName:'%s')", FileName);
		return 0;
	}

	int DeleteFile(wchar[] FileName, DOKAN_FILE_INFO* DokanFileInfo) {
		writefln("!!Unprocessed DeleteFile (FileName:'%s')", FileName);
		return 0;
	}

	int DeleteDirectory(wchar[] FileName, DOKAN_FILE_INFO* DokanFileInfo) {
		writefln("!!Unprocessed DeleteDirectory (FileName:'%s')", FileName);
		return 0;
	}

	int CloseFile(wchar[] FileName, DOKAN_FILE_INFO* DokanFileInfo) {
		writefln("!!Unprocessed CloseFile (FileName:'%s')", FileName);
		return 0;
	}

	int Cleanup(wchar[] FileName, DOKAN_FILE_INFO* DokanFileInfo) {
		writefln("!!Unprocessed Cleanup (FileName:'%s')", FileName);
		return 0;
	}
	
	int Unmount(DOKAN_FILE_INFO* DokanFileInfo) {
		writefln("!!Unprocessed Unmount");
		return 0;
	}

	static DOKAN_OPERATIONS dokanOperations = {
		&Static_CreateFile,
		&Static_OpenDirectory,
		&Static_CreateDirectory,
		&Static_Cleanup,
		&Static_CloseFile,
		&Static_ReadFile,
		&Static_WriteFile,
		&Static_FlushFileBuffers,
		&Static_GetFileInformation,
		&Static_FindFiles,
		&Static_FindFilesWithPattern,
		&Static_SetFileAttributes,
		&Static_SetFileTime,
		&Static_DeleteFile,
		&Static_DeleteDirectory,
		&Static_MoveFile,
		&Static_SetEndOfFile,
		&Static_LockFile,
		&Static_UnlockFile,
		&Static_GetDiskFreeSpace,
		&Static_GetVolumeInformation,
		&Static_Unmount,
	};
	
	this(wchar DriveLetter = 'z') {
		this.DriveLetter = DriveLetter;
	}
	
	int main() {
		DOKAN_OPTIONS    dokanOptions;
		dokanOptions.DriveLetter = DriveLetter;
		dokanOptions.ThreadCount = 0;
		dokanOptions.DebugMode = DebugMode;
		dokanOptions.UseStdErr = DebugMode;
		dokanOptions.UseAltStream = 0;
		dokanOptions.UseKeepAlive = 1;
		dokanOptions.GlobalContext = cast(ulong)cast(void *)this;
		//DokanUnmount(DriveLetter);
		int status = DokanMain(&dokanOptions, &dokanOperations);
		switch (status) {
			case DOKAN_SUCCESS             : writefln("Success\n"); break;
			case DOKAN_ERROR               : writefln("Error\n"); break;
			case DOKAN_DRIVE_LETTER_ERROR  : writefln("Bad Drive letter\n"); break;
			case DOKAN_DRIVER_INSTALL_ERROR: writefln("Can't install driver\n"); break;
			case DOKAN_START_ERROR         : writefln("Driver something wrong\n"); break;
			case DOKAN_MOUNT_ERROR         : writefln("Can't assign a drive letter\n"); break;
			default: writefln("Unknown error: %d\n", status); break;
		}
		return status;
	}
}

/*
int main(char[][] args) {
	scope dokan = new Dokan('m');
	return dokan.main();
}
*/
