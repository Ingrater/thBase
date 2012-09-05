module thBase.math;

auto min(T,U)(T x, U y)
{
  return (x < y) ? x : y;
}

auto max(T,U)(T x, U y)
{
  return (x > y) ? x : y;
}