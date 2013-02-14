module thBase.casts;

import std.traits;

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
  static assert(isIntegral!T, "Target Type " ~ T.stringof ~ " is not a integral type");
  static assert(isIntegral!U, "Source Type " ~ U.stringof ~ " is not a integral type");
  static if(is(T == U))
    return source;
  else
  {
    static if(isSigned!T)
    {
      static if(isSigned!U)
      {
        //both target and source are signed
        assert(source >= T.min && source <= T.max, "integer overflow during conversion");
      }
      else
      {
        //target is signed, source is unsigned
        assert(source <= T.max, "integer overflow during conversion");
      }
    }
    else
    {
      static if(isSigned!U)
      {
        //target is unsigned, source is signed
        assert(source >= 0 && source <= T.max, "integer overflow during conversion");
      }
      else
      {
        //target is unsigned, source is unsinged
        assert(source <= T.max, "integer overflow during conversion");
      }
    }
    return cast(T)source;
  }
}