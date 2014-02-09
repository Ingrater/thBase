module test;

import core.allocator;
import core.refcounted;

version(thBase_test)
{
  import thBase.conv;
  import core.stdc.stdio;

version(DigitalMars)
{
  extern (C) void onAssertErrorMsg( string file, size_t line, string msg )
  {
    debug
    {
      asm { int 3; }
    }
    throw New!Exception( msg, file, line );
  }
}

int convertToInt(float f)
{
  return cast(int)f;
}

int convertToIntSSE(float f)
{
  int result = void;
  asm {
    lea EAX, f;
    lea EBX, result;
    movss XMM0, [EAX];
    cvtss2si EAX, XMM0;
    mov [EBX], EAX;
  }
  return result;
}

import core.stdc.string;
import thBase.timer;
import thBase.math3d.all;
import thBase.timer;
import thBase.io;

  struct wrapper(T)
  {
    T m_value;
  }

  int main(string[] args)
  { 
    /*auto timer = cast(shared(Timer))New!Timer();
    scope(exit) Delete(timer);

    auto val1 = wrapper!(int)();
    auto val2 = wrapper!int();

    const(char)[] str = "hello world";*/

    return 0;
  }
}