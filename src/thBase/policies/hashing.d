module thBase.policies.hashing;

public import core.allocator : PointerHashPolicy;

import std.traits;

struct ReferenceHashPolicy
{
  static uint Hash(T)(T obj) if(is(T == interface) || is(T == class))
  {
    return PointerHashPolicy.Hash(cast(void*)obj);
  }
}

struct StringHashPolicy
{
  static uint Hash(T)(T str) if(std.traits.isSomeString!T)
  {
    return core.hashmap.hashOf(str.ptr, str.length * str[0].sizeof);
  }
}