module thBase.asserthandler;
import core.exception;
import thBase.windows;
import core.sys.windows.windows;
import core.stdc.stdio : sprintf;

shared static this()
{
  Init();
}

// DMD does currently not link against the microsoft debug c runtime
version(none) version(Win64)
{
  extern(C) alias int function(int _ReportType, const char * _Filename, int _Linenumber, const char * _ModuleName, const char * _Format, ...) _CrtDbgReport_t;
  __gshared _CrtDbgReport_t _CrtDbgReport;
}

void Init()
{
  core.exception.assertHandler = &AssertHandler;
  version(none) version(Win64)
  {
    auto handle = LoadLibraryA("msvcrt.dll".ptr);
    _CrtDbgReport = cast(_CrtDbgReport_t)GetProcAddress(handle, "_CrtDbgReport".ptr);
  }
}

void AssertHandler( string file, size_t line, string msg ) nothrow
{
  char[2048] buffer;
  sprintf(buffer.ptr, "Assertion file '%.*s' line %d: %.*s\n", file.length, file.ptr, line, msg.length, msg.ptr);
  OutputDebugStringA(buffer.ptr);
  int userResponse = 1;
  version(none) version(DigitalMars) version(Win64)
  {
    if(_CrtDbgReport != null)
    {
      userResponse = _CrtDbgReport(2, file.ptr, cast(int)line, null, "%.*s", msg.length, msg.ptr);
    }
  }
  version(GNU)
    asm { "int $0x3"; }
  else
    asm { int 3; }
}