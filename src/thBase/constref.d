module thBase.constref;

import std.traits;

template ConstRef(T) if (is(T == class) || is(T == interface) || isArray!(T))
{
  static if (!is(T X == const(U), U) && !is(T X == immutable(U), U))
  {
    alias T ConstRef;
  }
  else static if (isArray!(T))
  {
    alias const(ElementType!(T))[] ConstRef;
  }
  else
  {
    struct ConstRef
    {
      private union
      {
        T original;
        U stripped;
      }
      void opAssign(T another)
      {
        stripped = cast(U) another;
      }
      void opAssign(ConstRef another)
      {
        stripped = another.stripped;
      }
      static if (is(T == const U))
      {
        // safely assign immutable to const
        void opAssign(ConstRef!(immutable U) another)
        {
          stripped = another.stripped;
        }
      }
      this(T initializer)
      {
        opAssign(initializer);
      }
      @property T get(){
				return original;
			}
      T opDot() {
        return original;
      }
    }
  }
}