module thBase.enumbitfield;

struct EnumBitfield(T)
{
  static assert(is(T == enum), "a enum bitfield can only be created with a enum");

  static if(T.sizeof == 1)
    ubyte value;
  else static if(T.sizeof == 2)
    ushort value;
  else static if(T.sizeof == 4)
    uint value;
  else static if(T.sizeof == 8)
    ulong value;
  else
    static assert(0, T.stringof ~ " has a unhandeled size of " ~ T.sizeof);

  this(T v1)
  {
    value = v1;
  }
  this(T v1, T v2)
  {
    value = v1 | v2;
  }
  this(T v1, T v2, T v3)
  {
    value = v1 | v2 | v3;
  }
  this(T v1, T v2, T v3, T v4)
  {
    value = v1 | v2 | v3 | v4;
  }
  this(T v1, T v2, T v3, T v4, T v5)
  {
    value = v1 | v2 | v3 | v4 | v5;
  }
  this(T v1, T v2, T v3, T v4, T v5, T v6)
  {
    value = v1 | v2 | v3 | v4 | v5 | v6;
  }

  void Add(T v1)
  {
    value |= v1;
  }
  void Add(T v1, T v2)
  {
    value |= v1 | v2;
  }
  void Add(T v1, T v2, T v3)
  {
    value |= v1 | v3 | v3;
  }
  void Add(T v1, T v2, T v3, T v4)
  {
    value |= v1 | v2 | v3 | v4;
  }
  void Add(T v1, T v2, T v3, T v4, T v5)
  {
    value |= v1 | v2 | v3 | v4 | v5;
  }
  void Add(T v1, T v2, T v3, T v4, T v5, T v6)
  {
    value |= v1 | v2 | v3 | v4 | v5 | v6;
  }

  void Remove(T v1)
  {
    value = value & ~v1;
  }
  void Remove(T v1, T v2)
  {
    value = value & ~(v1 | v2);
  }
  void Remove(T v1, T v2, T v3)
  {
    value = value & ~(v1 | v2 | v3);
  }
  void Remove(T v1, T v2, T v3, T v4)
  {
    value = value & ~(v1 | v2 | v3 | v4);
  }
  void Remove(T v1, T v2, T v3, T v4, T v5)
  {
    value = value & ~(v1 | v2 | v3 | v4 | v5);
  }
  void Remove(T v1, T v2, T v3, T v4, T v5, T v6)
  {
    value = value & ~(v1 | v2 | v3 | v4 | v5 | v6);
  }

  bool IsSet(T v1)
  {
    return (value & v1) == v1;
  }
  bool IsSet(T v1, T v2)
  {
    typeof(value) temp = v1 | v2;
    return (value & temp) == temp;
  }
  bool IsSet(T v1, T v2, T v3)
  {
    typeof(value) temp = v1 | v2 | v3;
    return (value & temp) == temp;
  }
  bool IsSet(T v1, T v2, T v3, T v4)
  {
    typeof(value) temp = v1 | v2 | v3 | v4;
    return (value & temp) == temp;
  }
  bool IsSet(T v1, T v2, T v3, T v4, T v5)
  {
    typeof(value) temp = v1 | v2 | v3 | v4 | v5;
    return (value & temp) == temp;
  }
  bool IsSet(T v1, T v2, T v3, T v4, T v5, T v6)
  {
    typeof(value) temp = v1 | v2 | v3 | v4 | v5 | v6;
    return (value & temp) == temp;
  }

  bool IsSubsetOf(EnumBitfield!T rh)
  {
    return (value & rh.value) != 0;
  }

  bool IsAnyBitSet()
  {
    return value != 0;
  }
}

EnumBitfield!T Flags(T)(T v1)
{
  return EnumBitfield!T(v1);
}

EnumBitfield!T Flags(T)(T v1, T v2)
{
  return EnumBitfield!T(v1, v2);
}

EnumBitfield!T Flags(T)(T v1, T v2, T v3)
{
  return EnumBitfield!T(v1, v2, v3);
}

EnumBitfield!T Flags(T)(T v1, T v2, T v3, T v4)
{
  return EnumBitfield!T(v1, v2, v3, v4);
}

EnumBitfield!T Flags(T)(T v1, T v2, T v3, T v4, T v5)
{
  return EnumBitfield!T(v1, v2, v3, v4, v5);
}

EnumBitfield!T Flags(T)(T v1, T v2, T v3, T v4, T v5, T v6)
{
  return EnumBitfield!T(v1, v2, v3, v4, v5, v6);
}