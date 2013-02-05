module thBase.casts;

auto static_cast(T,U)(U source)
{
  static if(is(T == class))
  {
    static assert(is(U == class), "can not statically cast from " ~ U.stringof ~ " to " ~ T.stringof ~ " because " ~ U.stringof ~ " is not a class");
    static assert(is(T : U), T.stringof ~ " is not derived from " ~ U.stringof);
    debug
    {
      T result = cast(T)source;
      assert(result !is null, "runtime cast failed");
      return result;
    }
    else
    {
      return cast(T)(cast(void*)source);
    }
  }
  else
  {
    static assert(0, "not implemented");
  }
}

auto int_cast(T, U)(U source)
{
  static assert(IsIntegral!T, "Target Type " ~ T.stringof ~ " is not a integral type");
  static assert(IsIntegral!U, "Source Type " ~ U.stringof ~ " is not a integral type");
  //TODO check if cast will lead to a overflow
}