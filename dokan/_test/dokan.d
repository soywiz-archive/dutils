module Dokan;

import std.c.windows.windows;
import std.utf;
import std.stdio;
import std.traits;

const DOKAN_DRIVER_NAME = "dokan.sys";

alias void* PWIN32_FIND_DATAW;
alias void* LPBY_HANDLE_FILE_INFORMATION;

static int strlen(T)(T ptr) { int count = 0; while (*ptr++) { } return count; }

class Dokan {
	DOKAN_OPTIONS options = {
		'm', // DriveLetter
		5,   // ThreadCount
		DOKAN_OPTION_DEBUG // Options
	};
	DOKAN_OPERATIONS operations;

	// Utils
	private {
		static Dokan ToObject(PDOKAN_FILE_INFO DokanFileInfo) { return cast(Dokan)cast(void *)DokanFileInfo.Context; }
		static string ToString(LPCWSTR str) { return std.utf.toUTF8(str[0..strlen(str)]); }
	}
	
	// Interface.
	abstract {
		int CreateFile(string FileName, DWORD DesiredAccess, DWORD ShareMode, DWORD CreationDisposition, DWORD FlagsAndAttributes, PDOKAN_FILE_INFO DokanFileInfo);
	}

	static bool Unmount(wchar DriveLetter) { return cast(bool)DokanUnmount(DriveLetter); }
	@property {
		static uint Version() { return DokanVersion(); }
		static uint DriverVersion() { return DokanDriverVersion(); }
	}

	int Main() {
		operations.CreateFile = function int(LPCWSTR FileName, DWORD DesiredAccess, DWORD ShareMode, DWORD CreationDisposition, DWORD FlagsAndAttributes, PDOKAN_FILE_INFO DokanFileInfo) {
			return ToObject(DokanFileInfo).CreateFile(ToString(FileName), DesiredAccess, ShareMode, CreationDisposition, FlagsAndAttributes, DokanFileInfo);
		};
		/*
		int function(
			LPWSTR           VolumeNameBuffer,       //
			DWORD            VolumeNameSize,         // in num of chars
			LPDWORD          VolumeSerialNumber,     //
			LPDWORD          MaximumComponentLength, // in num of chars
			LPDWORD          FileSystemFlags,        //
			LPWSTR           FileSystemNameBuffer,   //
			DWORD            FileSystemNameSize,     // in num of chars
			PDOKAN_FILE_INFO DokanFileInfo
		) GetVolumeInformation;
		*/

		operations.GetVolumeInformation = &__GetVolumeInformation;
		options.GlobalContext = cast(ulong)cast(void *)this;
		writefln("premain");
		return DokanMain(&options, &operations);
	}
}

extern (C) int __GetVolumeInformation(
	LPWSTR           VolumeNameBuffer,       //
	DWORD            VolumeNameSize,         // in num of chars
	LPDWORD          VolumeSerialNumber,     //
	LPDWORD          MaximumComponentLength, // in num of chars
	LPDWORD          FileSystemFlags,        //
	LPWSTR           FileSystemNameBuffer,   //
	DWORD            FileSystemNameSize,     // in num of chars
	PDOKAN_FILE_INFO DokanFileInfo
) {
	writefln("aaaaaaaaa");
	return 0;
	//return ToObject(DokanFileInfo).GetVolumeInformation(VolumeNameBuffer, VolumeNameSize, VolumeSerialNumber, MaximumComponentLength, FileSystemFlags, FileSystemNameBuffer, DokanFileInfo);
};

class DokanTest : Dokan {
	int CreateFile(string FileName, DWORD DesiredAccess, DWORD ShareMode, DWORD CreationDisposition, DWORD FlagsAndAttributes, PDOKAN_FILE_INFO DokanFileInfo) {
		return 0;
	}
}

void main() {
	//writefln("%p", cast(void*)DokanMain);
	auto dokan = new DokanTest;
	writefln("Exit: %d", dokan.Main());
}

static this() {
	auto lib = LoadLibraryA("dokan.dll");
	if (lib is null) throw(new Exception("Can't load 'dokan.dll'"));

	static void errorload(string name) { throw(new Exception(std.string.format("Can't find method '%s' in 'dokan.dll'", name))); }
	static string bind(string name) { return "*cast(void **)&" ~ name ~ " = cast(void *)GetProcAddress(lib, \"" ~ name ~ "\"); if (" ~ name ~ " is null) errorload(\"" ~ name ~ "\");"; }

	mixin(""
		~ bind("DokanMain")
		~ bind("DokanUnmount")
		~ bind("DokanIsNameInExpression")
		~ bind("DokanVersion")
		~ bind("DokanDriverVersion")
		~ bind("DokanResetTimeout")

		~ bind("DokanServiceInstall")
		~ bind("DokanServiceDelete")
		~ bind("DokanNetworkProviderInstall")
		~ bind("DokanNetworkProviderUninstall")
		~ bind("DokanSetDebugMode")
	);
}

alias ubyte  UCHAR;
alias wchar  WCHAR;
alias ushort USHORT;
alias uint   ULONG;
alias ulong  ULONG64;
alias long   LONGLONG;
alias ulong* PULONGLONG;

enum {
	DOKAN_OPTION_DEBUG      = 1,  // ouput debug message
	DOKAN_OPTION_STDERR     = 2,  // ouput debug message to stderr
	DOKAN_OPTION_ALT_STREAM = 4,  // use alternate stream
	DOKAN_OPTION_KEEP_ALIVE = 8,  // use auto unmount
	DOKAN_OPTION_NETWORK    = 16, // use network drive
	DOKAN_OPTION_REMOVABLE  = 32, // use removable drive
}

struct DOKAN_OPTIONS {
	WCHAR	DriveLetter;   // drive letter to be mounted
	USHORT	ThreadCount;   // number of threads to be used
	ULONG	Options;       // combination of DOKAN_OPTIONS_*
	ULONG64	GlobalContext; // FileSystem can use this variable
}
alias DOKAN_OPTIONS* PDOKAN_OPTIONS;

struct DOKAN_FILE_INFO {
	ULONG64	Context;      // FileSystem can use this variable
	ULONG64	DokanContext; // Don't touch this
	PDOKAN_OPTIONS DokanOptions; // A pointer to DOKAN_OPTIONS which was  passed to DokanMain.
	ULONG	ProcessId;    // process id for the thread that originally requested a given I/O operation
	UCHAR	IsDirectory;  // requesting a directory file
	UCHAR	DeleteOnClose; // Delete on when "cleanup" is called
	UCHAR	PagingIo;	// Read or write is paging IO.
	UCHAR	SynchronousIo;  // Read or write is synchronous IO.
	UCHAR	Nocache;
	UCHAR	WriteToEndOfFile; //  If true, write to the current end of file instead of Offset parameter.

}
alias DOKAN_FILE_INFO* PDOKAN_FILE_INFO;

// FillFileData
//   add an entry in FindFiles
//   return 1 if buffer is full, otherwise 0
//   (currently never return 1)
alias int function(PWIN32_FIND_DATAW, PDOKAN_FILE_INFO) PFillFindData;

struct DOKAN_OPERATIONS {

	// When an error occurs, return negative value.
	// Usually you should return GetLastError() * -1.


	// CreateFile
	//   If file is a directory, CreateFile (not OpenDirectory) may be called.
	//   In this case, CreateFile should return 0 when that directory can be opened.
	//   You should set TRUE on DokanFileInfo->IsDirectory when file is a directory.
	//   When CreationDisposition is CREATE_ALWAYS or OPEN_ALWAYS and a file already exists,
	//   you should return ERROR_ALREADY_EXISTS(183) (not negative value)
	int function(
		LPCWSTR          FileName,
		DWORD            DesiredAccess,
		DWORD            ShareMode,
		DWORD            CreationDisposition,
		DWORD            FlagsAndAttributes,
		//HANDLE         TemplateFile,
		PDOKAN_FILE_INFO DokanFileInfo
	) CreateFile;

	int function(
		LPCWSTR          FileName,
		PDOKAN_FILE_INFO DokanFileInfo
	) OpenDirectory;

	int function(
		LPCWSTR          FileName,
		PDOKAN_FILE_INFO DokanFileInfo
	) CreateDirectory;

	// When FileInfo->DeleteOnClose is true, you must delete the file in Cleanup.
	int function(
		LPCWSTR          FileName,
		PDOKAN_FILE_INFO DokanFileInfo
	) Cleanup;

	int function(
		LPCWSTR          FileName,
		PDOKAN_FILE_INFO DokanFileInfo
	) CloseFile;

	int function(
		LPCWSTR,  // FileName
		LPVOID,   // Buffer
		DWORD,    // NumberOfBytesToRead
		LPDWORD,  // NumberOfBytesRead
		LONGLONG, // Offset
		PDOKAN_FILE_INFO
	) ReadFile;
	

	int function(
		LPCWSTR,  // FileName
		LPCVOID,  // Buffer
		DWORD,    // NumberOfBytesToWrite
		LPDWORD,  // NumberOfBytesWritten
		LONGLONG, // Offset
		PDOKAN_FILE_INFO
	) WriteFile;


	int function(
		LPCWSTR, // FileName
		PDOKAN_FILE_INFO
	) FlushFileBuffers;


	int function(
		LPCWSTR,          // FileName
		LPBY_HANDLE_FILE_INFORMATION, // Buffer
		PDOKAN_FILE_INFO
	) GetFileInformation;
	

	int function(
		LPCWSTR,			// PathName
		PFillFindData,		// call this function with PWIN32_FIND_DATAW
		PDOKAN_FILE_INFO
	) FindFiles;  //  (see PFillFindData definition)


	// You should implement either FindFiles or FindFilesWithPattern
	int function(
		LPCWSTR,			// PathName
		LPCWSTR,			// SearchPattern
		PFillFindData,		// call this function with PWIN32_FIND_DATAW
		PDOKAN_FILE_INFO
	) FindFilesWithPattern;


	int function(
		LPCWSTR, // FileName
		DWORD,   // FileAttributes
		PDOKAN_FILE_INFO
	) SetFileAttributes;


	int function(
		LPCWSTR,		// FileName
		const FILETIME*, // CreationTime
		const FILETIME*, // LastAccessTime
		const FILETIME*, // LastWriteTime
		PDOKAN_FILE_INFO
	) SetFileTime;


	// You should not delete file on DeleteFile or DeleteDirectory.
	// When DeleteFile or DeleteDirectory, you must check whether
	// you can delete or not, and return 0 (when you can delete it)
	// or appropriate error codes such as -ERROR_DIR_NOT_EMPTY,
	// -ERROR_SHARING_VIOLATION.
	// When you return 0 (ERROR_SUCCESS), you get Cleanup with
	// FileInfo->DeleteOnClose set TRUE, you delete the file.
	int function(
		LPCWSTR, // FileName
		PDOKAN_FILE_INFO
	) DeleteFile;

	int function( 
		LPCWSTR, // FileName
		PDOKAN_FILE_INFO
	) DeleteDirectory;


	int function(
		LPCWSTR, // ExistingFileName
		LPCWSTR, // NewFileName
		BOOL,	// ReplaceExisiting
		PDOKAN_FILE_INFO
	) MoveFile;


	int function(
		LPCWSTR,  // FileName
		LONGLONG, // Length
		PDOKAN_FILE_INFO
	) SetEndOfFile;


	int function(
		LPCWSTR,  // FileName
		LONGLONG, // Length
		PDOKAN_FILE_INFO
	) SetAllocationSize;


	int function(
		LPCWSTR, // FileName
		LONGLONG, // ByteOffset
		LONGLONG, // Length
		PDOKAN_FILE_INFO
	) LockFile;


	int function(
		LPCWSTR, // FileName
		LONGLONG,// ByteOffset
		LONGLONG,// Length
		PDOKAN_FILE_INFO
	) UnlockFile;


	// Neither GetDiskFreeSpace nor GetVolumeInformation
	// save the DokanFileContext->Context.
	// Before these methods are called, CreateFile may not be called.
	// (ditto CloseFile and Cleanup)

	// see Win32 API GetDiskFreeSpaceEx
	int function(
		PULONGLONG, // FreeBytesAvailable
		PULONGLONG, // TotalNumberOfBytes
		PULONGLONG, // TotalNumberOfFreeBytes
		PDOKAN_FILE_INFO
	) GetDiskFreeSpace;


	// see Win32 API GetVolumeInformation
	int function(
		LPWSTR           VolumeNameBuffer,       //
		DWORD            VolumeNameSize,         // in num of chars
		LPDWORD          VolumeSerialNumber,     //
		LPDWORD          MaximumComponentLength, // in num of chars
		LPDWORD          FileSystemFlags,        //
		LPWSTR           FileSystemNameBuffer,   //
		DWORD            FileSystemNameSize,     // in num of chars
		PDOKAN_FILE_INFO DokanFileInfo
	) GetVolumeInformation;


	int function(PDOKAN_FILE_INFO) Unmount;
}
alias DOKAN_OPERATIONS* PDOKAN_OPERATIONS;

// DokanMain returns error codes
enum {
	DOKAN_SUCCESS               =  0,
	DOKAN_ERROR                 = -1, // General Error
	DOKAN_DRIVE_LETTER_ERROR    = -2, // Bad Drive letter
	DOKAN_DRIVER_INSTALL_ERROR  = -3, // Can't install driver
	DOKAN_START_ERROR           = -4, // Driver something wrong
	DOKAN_MOUNT_ERROR           = -5, // Can't assign a drive letter
}

int  function(PDOKAN_OPTIONS DokanOptions, PDOKAN_OPERATIONS DokanOperations) DokanMain;
BOOL function(WCHAR DriveLetter) DokanUnmount;

// DokanIsNameInExpression
//   check whether Name can match Expression
//   Expression can contain wildcard characters (? and *)
// @Expression  matching pattern
// @Name        file name
BOOL function(LPCWSTR Expression, LPCWSTR Name, BOOL IgnoreCase) DokanIsNameInExpression;

ULONG function() DokanVersion;
ULONG function() DokanDriverVersion;

// DokanResetTimeout
//   extends the time out of the current IO operation in driver.
// timeout in millisecond
BOOL function(ULONG Timeout, PDOKAN_FILE_INFO DokanFileInfo) DokanResetTimeout;

// for internal use
// don't call
private {
	BOOL function(LPCWSTR ServiceName, DWORD ServiceType, LPCWSTR ServiceFullPath) DokanServiceInstall;
	BOOL function(LPCWSTR ServiceName) DokanServiceDelete;
	BOOL function() DokanNetworkProviderInstall;
	BOOL function() DokanNetworkProviderUninstall;
	BOOL function(ULONG Mode) DokanSetDebugMode;
}
