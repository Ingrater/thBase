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
  asm { int 3; }
}