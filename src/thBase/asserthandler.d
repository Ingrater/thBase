module thBase.asserthandler;
import core.exception;
import thBase.windows;

shared static this()
{
  Init();
}

void Init()
{
  setAssertHandler(&AssertHandler);
}

void AssertHandler( string file, size_t line, string msg )
{
  OutputDebugStringA(msg.ptr);
  version(GNU)
    asm { "int $0x3"; }
  else
    asm { int 3; }
}