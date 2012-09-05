module test;

import core.allocator;
import core.refcounted;

version(thBase_test)
{
  import thBase.conv;
  import core.stdc.stdio;

extern (C) void onAssertErrorMsg( string file, size_t line, string msg )
{
  debug
  {
    asm { int 3; }
  }
  throw New!Exception( msg, file, line );
}

import core.stdc.string;

  int main(string[] args)
  { 
    return 0;
  }
}