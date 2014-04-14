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
debug version(DigitalMars) version(Win64)
{
  extern(C) int _CrtDbgReport(int _ReportType, const char * _Filename, int _Linenumber, const char * _ModuleName, const char * _Format, ...);
}

void Init()
{
  if(IsDebuggerPresent())
    core.exception.assertHandler = &AssertHandler;
}

void AssertHandler( string file, size_t line, string msg ) nothrow
{
  char[2048] buffer;
  sprintf(buffer.ptr, "Assertion file '%.*s' line %d: %.*s\n", file.length, file.ptr, line, msg.length, msg.ptr);
  OutputDebugStringA(buffer.ptr);
  debug version(DigitalMars) version(Win64)
  {
    int userResponse = 1;
    userResponse = _CrtDbgReport(2, file.ptr, cast(int)line, null, "%.*s", msg.length, msg.ptr);
    if(userResponse)
      asm { int 3; }
  }
  else
  {
    version(GNU)
      asm { "int $0x3"; }
    else
      asm { int 3; }
  }
}