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