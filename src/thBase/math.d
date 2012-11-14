module thBase.math;

enum FloatEpsilon = 0.00001f;

auto min(T,U)(T x, U y)
{
  return (x < y) ? x : y;
}

auto max(T,U)(T x, U y)
{
  return (x > y) ? x : y;
}