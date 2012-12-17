module thBase.rtti;

struct thMemberInfo 
{
  string name;
  TypeInfo type;
  size_t offset;
}

template RttiInfo(alias T)
{
  pragma(msg, makeRttiInfo2!T());
  __gshared RttiInfo = mixin(makeRttiInfo2!T());
}

template isRttiMember(alias symbol)
{
  static if(is(typeof(symbol.offsetof)))
  {
    enum bool isRttiMember = true;
  }
  else
    enum bool isRttiMember = false;
}

size_t rttiMemberCount(T)()
{
  size_t count = 0;
  foreach(m; __traits(allMembers, T))
  {
    static if(isRttiMember!(__traits(getMember, T, m)))
    {
      count++;
    }
  }
  return count;
}

thMemberInfo[rttiMemberCount!T()] makeRttiInfo(T)()
{
  thMemberInfo[rttiMemberCount!T()] result;

  size_t i=0;
  foreach(m; __traits(allMembers, T))
  {
    static if(isRttiMember!(__traits(getMember, T, m)))
    {
      result[i++] = thMemberInfo(m.stringof, null,  __traits(getMember, T, m).offsetof);
    }
  }
  return result;
}

string makeRttiInfo2(alias T)()
{
  string result = "[  ";
  size_t i=0;
  foreach(m; __traits(allMembers, T))
  {
    static if(isRttiMember!(__traits(getMember, T, m)))
    {
      result ~= "thMemberInfo(" ~ m.stringof ~ ", typeid(" ~ typeof(__traits(getMember, T, m)).stringof ~ "),  T." ~ m ~ ".offsetof),\n";
    }
    /*else static if(__traits(compiles, mixin("__gshared v = &__traits(getMember, T, m);")))
    {
      result ~= "thMemberInfo(" ~ m.stringof ~ ", typeid(" ~ typeof(__traits(getMember, T, m)).stringof ~ "),  cast(size_t)&T." ~ m ~ "),\n";
    }*/
  }
  return result[0..$-2] ~ "]";
}

version(unittest)
{
  import thBase.io;
}

struct bla
{
}

__gshared int g_test;
static int s_test;

/*unittest
{
  static struct TestStruct
  {
    float f;
    int i;
    double d;
  }

  auto p = &s_test;

  thMemberInfo[] test = RttiInfo!TestStruct[];
  //thMemberInfo[] test2 = RttiInfo!(thBase.rtti)[];

  foreach(t; test)
  {
    writefln("member name: %s, type info %s, offset %d", t.name, t.type.toString()[], t.offset);
  }
}*/