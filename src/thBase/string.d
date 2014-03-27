module thBase.string;

import std.uni;
import thBase.utf;
import thBase.traits;
import thBase.algorithm;
import core.traits;
import thBase.format;
import std.traits;
import core.stdc.string;
import core.refcounted;
import core.vararg;
import thBase.math : max;

public import thBase.allocator : ThreadLocalStackAllocator;

version(unittest) 
{
  import thBase.devhelper;
}

/++
Strips leading whitespace.
+/
S stripLeft(S)(S s)
if(thBase.traits.isSomeString!S)
{
  bool foundIt;
  size_t nonWhite;
  foreach(i, dchar c; s[])
  {
    if(!std.uni.isWhite(c))
    {
      foundIt = true;
      nonWhite = i;
      break;
    }
  }

  if(foundIt)
    return s[nonWhite .. s.length];

  return s[0 .. 0]; //Empty string with correct type.
}

/**
Flag indicating whether a search is case-sensitive.
*/
enum CaseSensitive { no, yes }

/++
Returns the index of the first occurence of $(D c) in $(D s). If $(D c)
is not found, then $(D -1) is returned.

$(D cs) indicates whether the comparisons are case sensitive.
+/
sizediff_t indexOf(ST)(ST s, dchar c, CaseSensitive cs = CaseSensitive.yes) if(thBase.traits.isSomeString!ST)
{
   if (cs == CaseSensitive.yes)
   {
     static if ((arrayType!ST).sizeof == 1)
     {
       if (std.ascii.isASCII(c))
       {                                               // Plain old ASCII
         auto p = cast(char*)memchr(s.ptr, c, s.length);
         if (p)
           return p - cast(char *)s.ptr;
         else
           return -1;
       }
     }

     // c is a universal character
     foreach (sizediff_t i, dchar c2; s[])
     {
       if (c == c2)
         return i;
     }
   }
   else
   {
     if (std.ascii.isASCII(c))
     {                                                   // Plain old ASCII
       auto c1 = cast(char) std.ascii.toLower(c);

       foreach (sizediff_t i, c2; s[])
       {
         auto c3 = std.ascii.toLower(c2);
         if (c1 == c3)
           return i;
       }
     }
     else
     {                                                   // c is a universal character
       auto c1 = std.uni.toLower(c);

       foreach (sizediff_t i, dchar c2; s[])
       {
         auto c3 = std.uni.toLower(c2);
         if (c1 == c3)
           return i;
       }
     }
   }
   return -1;
 }

/++
Returns the index of the last occurence of $(D c) in $(D s). If $(D c)
is not found, then $(D -1) is returned.

$(D cs) indicates whether the comparisons are case sensitive.
+/
sizediff_t lastIndexOf(ST)(ST s, dchar c, CaseSensitive cs = CaseSensitive.yes) if(thBase.traits.isSomeString!ST)
{
  if (cs == CaseSensitive.yes)
  {
    static if ((arrayType!ST).sizeof == 1)
    {
      if (std.ascii.isASCII(c))
      {                                               // Plain old ASCII
        foreach_reverse(sizediff_t i, char c2; s[])
        {
          if(c == c2)
            return i;
        }
        return -1;
      }
    }

    // c is a universal character
    foreach_reverse (sizediff_t i, dchar c2; s[])
    {
      if (c == c2)
        return i;
    }
  }
  else
  {
    if (std.ascii.isASCII(c))
    {                                                   // Plain old ASCII
      auto c1 = cast(char) std.ascii.toLower(c);

      foreach_reverse (sizediff_t i, c2; s[])
      {
        auto c3 = std.ascii.toLower(c2);
        if (c1 == c3)
          return i;
      }
    }
    else
    {                                                   // c is a universal character
      auto c1 = std.uni.toLower(c);

      foreach_reverse (sizediff_t i, dchar c2; s[])
      {
        auto c3 = std.uni.toLower(c2);
        if (c1 == c3)
          return i;
      }
    }
  }
  return -1;
}

/++
Returns the index of the first occurence of $(D sub) in $(D s). If $(D sub)
is not found, then $(D -1) is returned.

$(D cs) indicates whether the comparisons are case sensitive.
+/
sizediff_t indexOf(T, U)(T haystack, U needle, CaseSensitive cs = CaseSensitive.yes)
if(thBase.traits.isSomeString!T && thBase.traits.isSomeString!U 
   && isSomeChar!(arrayType!T) && isSomeChar!(arrayType!U))
{
  if (cs == CaseSensitive.yes)
  {
    return thBase.algorithm.find(haystack, needle);
  }
  else
  {
    return thBase.algorithm.find!
      ((dchar a, dchar b){return std.uni.toLower(a) == std.uni.toLower(b);})
      (haystack, needle);
  }
  assert(0,"not reachable");
}

unittest
{
  auto leak = LeakChecker("string indexOf unittest");
  {
    string haystack = "Hello beautiful World";
    auto result = haystack.indexOf(_T("World"));
    assert(result == 16);

    result = haystack.indexOf(_T("world"));
    assert(result == -1);

    result = haystack.indexOf(_T("world"),CaseSensitive.no);
    assert(result == 16);
  }
}

struct StringAppendBuffer(T = immutable(char), Allocator = StdAllocator)
if( isSomeChar!T )
{
private:
  size_t m_CurPos;
  size_t m_GrowBy;
  alias RCArrayData!(T, Allocator) data_t;
  alias StripModifier!T BT;
  SmartPtr!data_t m_Data;
  BT[] m_Buffer;
  Allocator m_allocator;

public:
  @disable this();

  static if(is(typeof(Allocator.globalInstance)))
  {
    this(size_t startSize, size_t growBy)
    {
      m_allocator = Allocator.globalInstance;
      m_GrowBy = growBy;
      m_Data = data_t.AllocateArray(startSize, m_allocator, InitializeMemoryWith.NOTHING);
      m_Buffer = cast(BT[])m_Data[];
      m_CurPos = 0;
    }
  }

  this(size_t startSize, size_t growBy, Allocator allocator)
  {
    assert(allocator !is null);
    m_allocator = allocator;
    m_GrowBy = growBy;
    m_Data = data_t.AllocateArray(startSize, m_allocator, InitializeMemoryWith.NOTHING);
    m_Buffer = cast(BT[])m_Data[];
    m_CurPos = 0;
  }

  void opOpAssign(string op,U)(U c) if( op == "~" && is(StripModifier!U == BT))
  {
    EnsureSpaceLeft(1);
    m_Buffer[m_CurPos] = c;
    m_CurPos++;
  }

  void opOpAssign(string op,U)(U s) if( op == "~" && thBase.traits.isSomeString!U)
  {
    EnsureSpaceLeft(s.length);
    m_Buffer[m_CurPos..(m_CurPos+s.length)] = s[];
    m_CurPos += s.length;
  }

  void format(string fmt, ... )
  {
    doFormat(fmt, _arguments, _argptr);
  }

  void doFormat(string fmt, TypeInfo[] arguments, va_list argptr)
  {
    size_t needed = formatDoStatic(m_Buffer[m_CurPos..$], fmt, arguments, argptr);
    if(needed > m_Buffer.length - m_CurPos)
    {
      EnsureSpaceLeft(needed);
      needed = formatDoStatic(m_Buffer[m_CurPos..$], fmt, arguments, argptr);
    }
    assert(m_CurPos + needed <= m_Buffer.length);
    m_CurPos += needed;
  }

  @property auto str()
  {
    return RCArray!(T, Allocator)(m_Data,(m_Data[])[0..m_CurPos]);
  }

  auto substr(size_t start, size_t end)
  {
    assert(start <= end && end <= m_CurPos);
    return RCArray!(T, Allocator)(m_Data,(m_Data[])[start..end]);
  }

  size_t getMarker()
  {
    return m_CurPos;
  }

  void resetToMarker(size_t marker)
  {
    assert(marker <= m_CurPos);
    m_CurPos = marker;
  }

private:
  void EnsureSpaceLeft(size_t count)
  {
    if( m_Buffer.length - m_CurPos <= count )
    {
      sizediff_t growBy = (count > m_GrowBy) ? count + m_GrowBy : m_GrowBy;
      auto newData = data_t.AllocateArray(m_Buffer.length + growBy, m_allocator, InitializeMemoryWith.NOTHING);
      (cast(BT[])(newData[]))[0..m_CurPos] = m_Buffer[0..m_CurPos];
      m_Data = newData;
      m_Buffer = cast(BT[])m_Data[];
    }
  }

}

unittest 
{
  auto leak = LeakChecker("StringAppendBuffer unittest");
  {
    rcstring test;
    {
      auto buf = StringAppendBuffer!(immutable(char))(0,8);
      for(int i=0; i<10; i++)
        buf ~= 'c';
      for(int i=0; i<10; i++)
        buf ~= "bla";
      for(int i=0; i<5; i++)
        buf ~= _T("blup");
      buf.format("%d %.2f",123,1.23f);
      test = buf.str;
    }
    assert(test[] == "ccccccccccblablablablablablablablablablablupblupblupblupblup123 1.23"); 
  }
}

bool equal(T,U)(T s1, U s2, CaseSensitive cs = CaseSensitive.yes)
if(thBase.traits.isSomeString!T && thBase.traits.isSomeString!U 
   && is(StripModifier!(arrayType!T) == StripModifier!(arrayType!U)))
{
  auto data1 = s1[];
  auto data2 = s2[];
  if(cs == CaseSensitive.yes)
  {
    if(s1.length != s2.length)
      return false;
    size_t to = (s1.length < s2.length) ? s1.length : s2.length;
    for(size_t i=0; i<to; ++i)
    {
      if(data1[i] != data2[i])
        return false;
    }
  }
  else
  {
    size_t i=0;
    size_t j=0;
    while( i < data1.length && j < data2.length )
    {
      if(std.uni.toLower(decode(data1,i)) != std.uni.toLower(decode(data2,j)))
      {
        return false;
      }
    }
    if( data1.length > i || data2.length > j)
      return false;
  }
  return true;
}

unittest {
  auto leak = LeakChecker("string equal unittest");
  {
    assert(equal(_T("Маша"),_T("Маша"),CaseSensitive.yes));
    assert(equal(_T("Маша"),_T("маша"),CaseSensitive.no));
    assert(!equal(_T("Маша"),_T("маша"),CaseSensitive.yes));
    assert(!equal(_T("Hello World"),_T("Hello Wor"),CaseSensitive.yes));
    assert(!equal(_T("Hello Wor"),_T("Hello World"),CaseSensitive.yes));
    assert(!equal(_T("Hello World"),_T("Hello Wor"),CaseSensitive.no));
    assert(!equal(_T("Hello Wor"),_T("Hello World"),CaseSensitive.no));
  }
}

bool startsWith(T,U)(T str, U start, CaseSensitive cs = CaseSensitive.yes)
if(thBase.traits.isSomeString!T && thBase.traits.isSomeString!U 
   && is(StripModifier!(arrayType!T) == StripModifier!(arrayType!U)))
{
  auto data1 = str[];
  auto data2 = start[];
  if(cs == CaseSensitive.yes)
  {
    if(str.length < start.length)
      return false;
    size_t to = start.length;
    for(size_t i=0; i<to; ++i)
    {
      if(data1[i] != data2[i])
        return false;
    }
  }
  else
  {
    size_t i=0;
    size_t j=0;
    while( i < data1.length && j < data2.length )
    {
      if(std.uni.toLower(decode(data1,i)) != std.uni.toLower(decode(data2,j)))
      {
        return false;
      }
    }
    if( data2.length > j ) //second string not completely read
      return false;
  }
  return true;
}

unittest 
{
  auto leak = LeakChecker("string starts with unittest");
  {
    assert(!startsWith(_T("Hello World"), _T("hello"), CaseSensitive.yes ));
    assert(startsWith(_T("Hello World"), _T("hello"), CaseSensitive.no ));
    assert(!startsWith(_T("Hello"), _T("Hello World"), CaseSensitive.yes ));
    assert(!startsWith(_T("Hello"), _T("Hello World"), CaseSensitive.no ));
  }
}

bool endsWith(T,U)(T str, U end, CaseSensitive cs = CaseSensitive.yes)
if(thBase.traits.isSomeString!T && thBase.traits.isSomeString!U 
   && is(StripModifier!(arrayType!T) == StripModifier!(arrayType!U)))
{
  auto data1 = str[];
  auto data2 = end[];
  if(cs == CaseSensitive.yes)
  {
    if(str.length < end.length)
      return false;
    sizediff_t to = str.length - end.length;
    for(sizediff_t i = str.length-1; i>=to; --i)
    {
      if(data1[i] != data2[i-to])
        return false;
    }
  }
  else
  {
    size_t i = 0;
    size_t j = 0;
    while( i < data1.length && j < data2.length)
    {
      if(std.uni.toLower(decodeReverse(data1,i)) != std.uni.toLower(decodeReverse(data2,j)))
      {
        return false;
      }
    }
    if( data2.length > j ) //second string not completely read
      return false;
  }
  return true;
}

unittest
{
  auto leak = LeakChecker("thBase.string.endsWith unittest");
  {
    assert(endsWith(_T("Мaшa"), _T("Мaшa"), CaseSensitive.yes) == true);
    assert(endsWith(_T("Мaшa"), _T("Мaшa"), CaseSensitive.no) == true);
    assert(endsWith(_T("Мaшa"), _T("шa"), CaseSensitive.no) == true);
    assert(endsWith(_T("Мaшa"), _T("aa"), CaseSensitive.no) == false);
    assert(endsWith(_T("World"), _T("Hello World"), CaseSensitive.no) == false);
    assert(endsWith(_T("Hello World"), _T("World"), CaseSensitive.no) == true);
  }
}

struct Tokenizer(T)
{
  static assert(thBase.traits.isArray!T, "template argument is not an array");
  @disable this();

  alias StripModifier!(arrayType!T) element_t;

  private T m_array;
  private T m_cur;
  private element_t m_splitChar;

  this(T array, element_t splitChar)
  {
    m_array = array;
    m_splitChar = splitChar;
    popFront();
  }

  @property T front()
  {
    return m_cur;
  }

  void popFront()
  {
    auto index = indexOf(m_array, m_splitChar);
    if(index < 0)
    {
      index = m_array.length;
      m_cur = m_array;
      T initHelper;
      m_array = initHelper;
    }
    else
    {
      m_cur = m_array[0..index];
      m_array = m_array[(index+1)..m_array.length];
    }
  }

  @property bool empty()
  {
    return (m_array.length == 0) && (m_cur.length == 0);
  }
}

unittest
{
  auto leak = LeakChecker("Tokenizer unittest");
  {
    auto str = _T("Hello D World");
    auto tok = Tokenizer!rcstring(str, ' ');
    int i=0;
    foreach(word; tok)
    {
      switch(i)
      {
        case 0:
          assert(word == "Hello");
          break;
        case 1:
          assert(word == "D");
          break;
        case 2:
          assert(word == "World");
          break;
        default:
          assert(0, "to many tokens");
          break;
      }
      i++;
    }
    assert(i == 3, "tokens missing");
  }
}

Tokenizer!T split(T)(T str, Tokenizer!T.element_t splitChar)
{
  return Tokenizer!T(str, splitChar);
}

struct LineSplitter(T)
{
  static assert(thBase.traits.isArray!T, "template argument is not an array");
private:
  T m_str;
  T m_cur;

public:
  @disable this();

  this(T str)
  {
    m_str = str;
    popFront();
  }

  T front()
  {
    return m_cur;
  }

  void popFront()
  {
    auto index = indexOf(m_str, '\n');
    if(index < 0)
    {
      T initHelper;
      m_cur = m_str;
      m_str = initHelper;
    }
    else
    {
      m_cur = m_str[0..index];
      if(m_cur[m_cur.length-1] == '\r')
      {
        m_cur = m_cur[0..(m_cur.length-1)];
      }
      m_str = m_str[(index+1)..m_str.length];
    }
  }

  bool empty()
  {
    return (m_str.length == 0) && (m_cur.length == 0);
  }
}

LineSplitter!T splitLines(T)(T str)
{
  return LineSplitter!T(str);
}

unittest
{
  auto leak = LeakChecker("splitLines unittest");
  {
    auto str1 = _T("Hello\nD\nWorld");
    int i=0;
    foreach(line; splitLines(str1))
    {
      switch(i)
      {
        case 0:
          assert(line == "Hello");
          break;
        case 1:
          assert(line == "D");
          break;
        case 2:
          assert(line == "World");
          break;
        default:
          assert(0, "to many lines");
          break;
      }
      i++;
    }
    assert(i == 3, "lines missing");

    auto str2 = _T("Hello\r\nD\r\nWorld");
    i = 0;
    foreach(line; splitLines(str1))
    {
      switch(i)
      {
        case 0:
          assert(line == "Hello");
          break;
        case 1:
          assert(line == "D");
          break;
        case 2:
          assert(line == "World");
          break;
        default:
          assert(0, "to many lines");
          break;
      }
      i++;
    }
    assert(i == 3, "lines missing");
  }
}

struct ZeroTerminatedStringHolder
{
  SmartPtr!(RCArrayData!(char)) m_str;

  alias str this;

  @disable this();

  this(const(char)[] src)
  {
    m_str = RCArrayData!char.AllocateArray(src.length+1, StdAllocator.globalInstance, InitializeMemoryWith.NOTHING);
    auto data = m_str[];
    if(src.length > 0)
    {
      data[0..src.length] = src[];
    }
    data[src.length] = '\0';
  }

  @property const(char)* str()
  {
    return m_str[].ptr;
  }

  @property const(char)* str() const
  {
    return m_str[].ptr;
  }
}

string stackCString(string invar, string outvar)
{
  string result = "char[] " ~ outvar ~ "; char[256] "~outvar~"smallBuf;";
  result ~=       "if(" ~ invar ~ ".length < "~outvar~"smallBuf.length)";
  result ~=         outvar ~ " = "~outvar~"smallBuf[];";
  result ~=       "else ";
  result ~=         outvar ~ " = (cast(char*)ThreadLocalStackAllocator.globalInstance.AllocateMemory(" ~ invar ~ ".length+1))[0.." ~ invar ~ ".length+1];";
  result ~=       "scope(exit) if(" ~ invar ~ ".length >= "~outvar~"smallBuf.length) ThreadLocalStackAllocator.globalInstance.FreeMemory(" ~ outvar ~ ".ptr);";
  result ~=       outvar ~ "[0.."~invar~".length] = "~invar~"[];";
  result ~=       outvar ~ "["~invar~".length] = 0;";
  return result;
}

auto toCString(const(char)[] str)
{
  return ZeroTerminatedStringHolder(str);
}

auto toCString(rcstring str)
{
  return ZeroTerminatedStringHolder(str[]);
}

unittest 
{
  import core.stdc.string;

  void compare(const(char)* cstr1, const(char)* cstr2)
  {
    assert(strcmp(cstr1, cstr2) == 0);
  }

  auto leak = LeakChecker("toCString unittest");
  {
    compare(toCString("Hello World"), cast(const(char)*)"Hello World".ptr);
  }
}

rcstring fromCString(const(char) *str){
	if(str is null)
		return _T("");
	return rcstring(str[0..strlen(str)]);
}

unittest 
{
  auto leak = LeakChecker("fromCString unittest");
  {
    auto str = fromCString(cast(const(char)*)"Hello World".ptr);
    assert(str == "Hello World");
  }
}


rcstring toLower(const(char)[] str)
{
  return toLowerAllocator(str, StdAllocator.globalInstance);
}

RCArray!(immutable(char), Allocator) toLowerAllocator(Allocator)(const(char)[] str, Allocator allocator)
{
  alias RCArrayData!(immutable(char), Allocator) data_t;
  auto data = data_t.AllocateArray(str.length, allocator, InitializeMemoryWith.NOTHING);
  auto text = cast(char[])data[];
  size_t len = toLowerImpl(str, text);
  return RCArray!(immutable(char), Allocator)(data, (data[])[0..len]);
}

size_t toLowerImpl(const(char)[] str, char[] dest) @trusted
{
  char[4] buf;
  size_t cur = 0;
  foreach(dchar c; str)
  {
    size_t len = encode(buf, std.uni.toLower(c));
    dest[cur..(cur+len)] = buf[0..len];
    cur += len;
  }
  return cur;
}

rcstring replace(T, U)(T str, U searchFor, U replaceWith) 
if(thBase.traits.isSomeString!T && !thBase.traits.isSomeString!U)
{
  static if(is(U == char))
  {
    auto result = rcstring(str[]);
    foreach(ref char c; cast(char[])result[])
    {
      if(c == searchFor)
        c = replaceWith;
    }
    return result;
  }
  else
  {
    static assert(0, "not implemented");
  }
}

unittest
{
  assert("abcdefaba".replace('a','f') == "fbcdeffbf");
}

auto replace(S1, S2, S3)(S1 str, S2 searchFor, S3 replaceWith)
if(thBase.traits.isSomeString!S1 && thBase.traits.isSomeString!S2 && thBase.traits.isSomeString!S3)
{
  auto remainder = str[];
  ptrdiff_t pos = remainder.indexOf(searchFor);
  static if(isRCArray!S1)
  {
    if(pos < 0)
      return str;
  }

  auto appender = StringAppendBuffer!()(str.length, max(8, replaceWith.length - searchFor.length * 8));
  do
  {
    appender ~= remainder[0..pos];
    appender ~= replaceWith[];
    remainder = remainder[pos + searchFor.length .. $];
    pos = remainder.indexOf(searchFor);
  }
  while(pos >= 0);
  appender ~= remainder;
  return appender.str;
}

unittest
{
  assert("\\\\this\\\\is\\\\a\\\\\\\\path".replace("\\\\","/") == "/this/is/a//path");
}