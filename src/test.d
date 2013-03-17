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

import core.stdc.string;
import thBase.timer;
import thBase.math3d.all;

  int main(string[] args)
  { 
    auto r = vec3(0,-1,0);
    auto v = vec3(1,0,0);
    auto res = v.cross(r);

    v = vec3(-1,0,0);
    res = v.cross(r);

    v = vec3(0,0,1);
    res = v.cross(r);

    v = vec3(0,0,-1);
    res = v.cross(r);
    return 0;
  }
}