module thBase.traits;

import std.traits;
public import core.traits;
import core.refcounted;
import thBase.ctfe;

template isRCString(T) if(is(T U : RCArray!(U,A),A))
{
  static if(is(T.BT == char) || is(T.BT == wchar) || is(T.BT == dchar))
    enum bool isRCString = true;
  else
    enum bool isRCString = false;
}

template isRCString(T) if(!is(T U : RCArray!(U,A),A))
{
  enum bool isRCString = false;
}

template isSomeString(T)
{
  static if(std.traits.isSomeString!T || isRCString!T)
    enum bool isSomeString = true;
  else
    enum bool isSomeString = false;
}

unittest 
{
  static assert(isSomeString!string);
  static assert(isSomeString!(char[]));
  static assert(isSomeString!rcstring);
  static assert(isSomeString!(RCArray!(immutable(char), IAllocator)));
}

template isArray(T)
{
  enum bool isArray = isRCArray!T || std.traits.isArray!T;
}

unittest 
{
  static assert(isArray!(RCArray!(immutable(char))) == true);
  static assert(isArray!(char[]) == true);
}

unittest {
  static assert(is(arrayType!(RCArray!(immutable(char))) == immutable(char)));
  static assert(is(arrayType!(const(char)[]) == const(char)));
  static assert(is(StripModifier!(arrayType!(RCArray!(immutable(char)))) == char),StripModifier!(arrayType!(RCArray!(immutable(char)))).stringof);

  static assert(is(StripModifier!(const(void[])) == void[]));

  static assert(is(StripModifier!(arrayType!rcstring) == char));

  static assert(isRCArray!rcstring == true);
  static assert(isRCArray!string == false);
  static assert(isRCArray!(RCArray!(byte, IAllocator)) == true);

  static assert(is(RCArrayType!rcstring == immutable(char)));
  static assert(is(RCArrayType!(RCArray!(byte, IAllocator)) == byte));

  static assert(isRCString!(RCArray!(immutable(char), IAllocator)));
}

private bool HasPostblitMember(T)()
{
  foreach(m; __traits(allMembers,T))
  {
    static if((m.length < 2 || m[0..2] != "__") && m != "this"){
      static if(__traits(compiles,typeof(__traits(getMember, T, m)))){
        static if(HasPostblit!(typeof(__traits(getMember, T, m))))
          return true;
      }
    }
  }
  return false;
}

template HasPostblit(T)
{
  static if(!is(T == struct))
    enum bool HasPostblit = false;
  else static if(is(typeof(T.__postblit)))
    enum bool HasPostblit = true;
  else 
    enum bool HasPostblit = HasPostblitMember!T();
}

unittest
{
  static struct Test1
  {
    float f;
    int i;
  }

  static struct Test2
  {
    Test1 t;
    alias rcstring s;
    double d;
  }

  static struct Test3
  {
    this(this)
    {
    }
  }

  static struct Test4
  {
    int i;
    Test3 t3;
  }

  static struct Test5
  {
    float f;
    double d;
    rcstring s;
  }

  static assert(HasPostblit!Test1 == false);
  static assert(HasPostblit!Test2 == false);
  static assert(HasPostblit!Test3 == true);
  static assert(HasPostblit!rcstring == true);
  static assert(HasPostblit!Test4 == true);
  static assert(HasPostblit!Test5 == true);
}

/* fullyQualifiedName is taken from phobos std.traits */
/**
* Get the fully qualified name of a symbol.
* Example:
* ---
* import std.traits;
* static assert(fullyQualifiedName!(fullyQualifiedName) == "std.traits.fullyQualifiedName");
* ---
*/
template fullyQualifiedName(alias T)
{
  static if (is(typeof(__traits(parent, T))))
  {
    static if (T.stringof.length >= 9 && T.stringof[0..8] == "package ")
    {
      enum fullyQualifiedName = fullyQualifiedName!(__traits(parent, T)) ~ '.' ~ T.stringof[8..$];
    }
    else static if (T.stringof.length >= 8 && T.stringof[0..7] == "module ")
    {
      enum fullyQualifiedName = fullyQualifiedName!(__traits(parent, T)) ~ '.' ~ T.stringof[7..$];
    }
    else static if (T.stringof.indexOfChar('(') == -1)
    {
      enum fullyQualifiedName = fullyQualifiedName!(__traits(parent, T)) ~ '.' ~ T.stringof;
    }
    else
      enum fullyQualifiedName = fullyQualifiedName!(__traits(parent, T)) ~ '.' ~ T.stringof[0..T.stringof.indexOfChar('(')];
  }
  else
  {
    static if (T.stringof.length >= 9 && T.stringof[0..8] == "package ")
    {
      enum fullyQualifiedName = T.stringof[8..$];
    }
    else static if (T.stringof.length >= 8 && T.stringof[0..7] == "module ")
    {
      enum fullyQualifiedName = T.stringof[7..$];
    }
    else static if (T.stringof.indexOfChar('(') == -1)
    {
      enum fullyQualifiedName = T.stringof;
    }
    else
      enum fullyQualifiedName = T.stringof[0..T.stringof.indexOfChar('(')];
  }
}