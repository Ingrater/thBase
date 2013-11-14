module thBase.math;

import thBase.traits;

enum FloatEpsilon = 0.00001f;
enum DoubleEpsilon = 0.000000001;

auto min(T,U)(T x, U y)
{
  return (x < y) ? x : y;
}

auto max(T,U)(T x, U y)
{
  return (x > y) ? x : y;
}

auto saturate(float x)
{
  return (x > 1.0f) ? 1.0f : ((x < 0.0f) ? 0.0f : x);
}

bool epsilonCompare(T)(T x, T y)
{
  static if(is(StripModifier!T == float))
  {
    return (x < y + FloatEpsilon) && (x > y - FloatEpsilon);
  }
  else static if(is(StripModifier!T == double))
  {
    return (x < y + DoubleEpsilon) && (x > y - DoubleEpsilon);
  }
  else static if(is(typeof(T.f)))
  {
    for(size_t i=0; i<T.f.length; i++)
    {
      if(!epsilonCompare(x.f[i],y.f[i]))
         return false;
    }
    return true;
  }
  else
  {
    static assert(0, T.stringof ~ " is not supported by epsilonCompare");
  }
}

bool epsilonCompare(T,E)(T x, T y, E epsilon)
{
  static if(is(StripModifier!T == float))
  {
    return (x < y + epsilon) && (x > y - epsilon);
  }
  else static if(is(StripModifier!T == double))
  {
    return (x < y + epsilon) && (x > y - epsilon);
  }
  else static if(is(typeof(T.f)))
  {
    for(size_t i=0; i<T.f.length; i++)
    {
      if(!epsilonCompare(x.f[i], y.f[i], epsilon))
        return false;
    }
    return true;
  }
  else
  {
    static assert(0, T.stringof ~ " is not supported by epsilonCompare");
  }
}

float fastsqrt(float f)
{
  version(D_InlineAsm_X86)
  {
    asm {
      movss XMM0, f;
      rsqrtss XMM1, XMM0;
      mulss XMM0, XMM1;
      movss f, XMM0;
    }
  }
  else version(D_InlineAsm_X64)
  {
    asm {
      movss XMM0, f;
      rsqrtss XMM1, XMM0;
      mulss XMM0, XMM1;
      movss f, XMM0;
    }
  }
  else
    static assert(0, "not implemented");
  return f;
}