module thBase.asserthandler;
import core.exception;

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
  version(GNU)
    asm { "int $0x3"; }
  else
    asm { int 3; }
}