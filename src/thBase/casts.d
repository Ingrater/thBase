module thBase.casts;

auto static_cast(T,U)(U source)
{
  return cast(T)(cast(void*)source);
}