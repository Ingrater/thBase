module thBase.format;

import std.traits;
import core.refcounted;
import thBase.conv;
import thBase.types;
import thBase.file;
import thBase.utf;
import thBase.constref;
import core.stdc.string;

class FormatException : RCException
{
  this(rcstring msg, string file = __FILE__, size_t line = __LINE__)
  {
    super(msg,file,line);
  }
}

struct BufferPutPolicy(T)
{
  T[] buffer;
  size_t pos = 0;

  this(T[] buffer)
  {
    this.buffer = buffer;
  }

  void put(T character)
  {
    if(pos < buffer.length)
    {
      buffer[pos] = character;
      pos++;
    }
  }
}

struct RawFilePutPolicy(T)
{
  RawFile *pFile;
  T[256] buffer;
  ushort pos = 0;

  @disable this();

  this(ref RawFile file)
  {
    pFile = &file;
  }

  ~this()
  {
    if(pos > 0)
      pFile.writeArray(buffer[0..pos]);
  }

  void put(T character)
  {
    if(pos >= buffer.length)
    {
      pFile.writeArray(buffer);
      pos = 0;
    }
    buffer[pos] = character;
    pos++;
  }
}

struct NothingPutPolicy(T)
{
  void put(T character)
  {
  }
}

size_t formatImpl(T,PP)(T f, uint num,ref PP putPolicy, bool allowCut) if(isFloatingPoint!T)
{
  long start = cast(long)f;
  size_t needed = formatImpl(start,putPolicy);
  if(num == 0)
    return needed;

  f -= cast(T)start;
  if( f < cast(T)0)
    f *= cast(T)-1;
  
  putPolicy.put('.');   
  needed++;
  
  if(allowCut)
  {
    char[64] buf;
    uint len = 0;
    for(uint i=0; i<num; i++)
    {
      f = f * cast(T)10.0;
      int digit = cast(int)f;
      f -= cast(T)digit;
      buf[len++] = cast(char)('0' + digit);
    }
    while(len > 1 && buf[len-1] == '0')
      len--;
    for(uint i=0; i<len; i++)
      putPolicy.put(buf[i]);
    needed += len;
  }
  else
  {
    for(uint i=0; i<num; i++)
    {
      f = f * cast(T)10.0;
      int digit = cast(int)f;
      f -= cast(T)digit;
      putPolicy.put(cast(char)('0' + digit));
      needed++;
    }
  }

  return needed;
}

unittest
{
  char[64] buf;

  auto put = BufferPutPolicy!char(buf);
  size_t needed = formatImpl(1.0f,2,put,false);
  assert(buf[0..needed] == "1.00");

  put = BufferPutPolicy!char(buf);
  needed = formatImpl(1.0f,2,put,true);
  assert(buf[0..needed] == "1.0");

  put = BufferPutPolicy!char(buf);
  needed = formatImpl(-123.4567890,6,put,false);
  assert(buf[0..needed] == "-123.456789"); 
}

size_t formatImpl(T,PP)(T i, ref PP putPolicy) if(isIntegral!T)
{
  size_t needed = 0;
  static if(isSigned!T)
  {
    if(i < cast(T)0)
    {
      putPolicy.put('-');
      needed++;
      i *= cast(T)-1;
    }
  }
  char[64] buf = void;
  uint numDigits = 0;

  T digit; 
  T rest = i; 

  do
  {
    digit = rest % cast(T)10;
    rest = rest / cast(T)10;
    buf[numDigits] = cast(char)('0'+digit);
    numDigits++;
  }
  while(rest > cast(T)0);

  foreach_reverse(c;buf[0..numDigits])
  {
    putPolicy.put(c);
  }
  needed += numDigits;

  return needed;
}

size_t formatHex(T, PP)(T i, ref PP putPolicy) if(isIntegral!T && !isSigned!T)
{
  size_t needed = 0;
  char[64] buf = void;
  uint numDigits = 0;

  T digit; 
  T rest = i; 

  do
  {
    digit = rest % cast(T)16;
    rest = rest / cast(T)16;
    if(digit < 10)
      buf[numDigits] = cast(char)('0'+digit);
    else
      buf[numDigits] = cast(char)('A'+(digit-10));
    numDigits++;
  }
  while(rest > cast(T)0);

  putPolicy.put('0');
  putPolicy.put('x');
  needed += 2;
  foreach_reverse(c;buf[0..numDigits])
  {
    putPolicy.put(c);
  }
  needed += numDigits;

  return needed;
}

unittest {
  char buf[64];

  auto put = BufferPutPolicy!char(buf);
  size_t needed = formatImpl(-123,put);
  assert(buf[0..needed] == "-123");
  
  put = BufferPutPolicy!char(buf);
  needed = formatImpl(9734,put);
  assert(buf[0..needed] == "9734");
}

private void formatArray(T,PP)(ref PP putPolicy, ref void* argptr, ref size_t needed)
{
  auto data = *cast(const(T)[]*)argptr;
  argptr += (const(T)[]).sizeof;
  putPolicy.put('[');
  if(data.length > 0)
  {
    T value = data[0];
    static if(is(T == float) || is(T == double))
      needed += formatImpl!(T,PP)(value, 6, putPolicy, true);
    else
      needed += formatImpl!(T,PP)(value, putPolicy);
    foreach(e; data[1..$])
    {
      value = e;
      putPolicy.put(',');
      putPolicy.put(' ');
      static if(is(T == float) || is(T == double))
        needed += formatImpl!(T, PP)(value, 6, putPolicy, true) + 2;
      else
        needed += formatImpl!(T, PP)(value, putPolicy) + 2;
    }
  }
  putPolicy.put(']');
  needed += 2;
}

size_t formatDo(PP)(ref PP putPolicy, const(char)[] fmt, TypeInfo[] arguments, void* argptr)
{
  size_t needed = 0;
  size_t argNum = 0;
  for(size_t i=0;i<fmt.length;i++)
  {
    if(fmt[i] != '%')
    {
      putPolicy.put(fmt[i]);
      needed++;
    }
    else {
      if(i+1 < fmt.length && fmt[i+1] == '%')
      {
        putPolicy.put('%');
        i++;
      }
      else if(i+1 >= fmt.length)
      {
        throw New!FormatException(_T("Incomplete format specifier %"));
      }
      else {
        //parse format specifier
        
        if(argNum >= arguments.length)
        {
          throw New!FormatException(_T("Number of format specifiers does not match number of passed arguments"));
        }

        if(fmt[i+1] == 'f')
        {
		      ConstRef!(const(TypeInfo)) strippedType = arguments[argNum];
          TypeInfo.Type tt = strippedType.type;
          while(tt == TypeInfo.Type.Const || tt == TypeInfo.Type.Immutable || tt == TypeInfo.Type.Shared)
          {
            strippedType = strippedType.next();
            if(strippedType.get is null)
            {
              throw New!FormatException(_T("Invalid TypeInfo"));
            }
            tt = strippedType.type();
          }

          if(strippedType.get == typeid(float))
          {
            needed += formatImpl(*cast(float*)argptr,6,putPolicy,true);
            argptr += float.sizeof;
          }
          else if(strippedType.get == typeid(double))
          {
            needed += formatImpl(*cast(double*)argptr,6,putPolicy,true);
            argptr += double.sizeof;
          }
          else
          {
            throw New!FormatException(_T("Wrong type '") ~ arguments[argNum].toString() ~ _T("' for format specifier %f"));
          }
          i++;
        }
        else if(fmt[i+1] == 'd' || fmt[i+1] == 'i')
        {
		      ConstRef!(const(TypeInfo)) strippedType = arguments[argNum];
          TypeInfo.Type tt = strippedType.type;
          while(tt == TypeInfo.Type.Const || tt == TypeInfo.Type.Immutable || tt == TypeInfo.Type.Shared)
          {
            strippedType = strippedType.next();
            if(strippedType.get is null)
            {
              throw New!FormatException(_T("Invalid TypeInfo"));
            }
            tt = strippedType.type();
          }
          if(strippedType.get == typeid(byte))
          {
            needed += formatImpl(*cast(byte*)argptr,putPolicy);
            argptr += byte.sizeof;
          }
          else if(strippedType.get == typeid(ubyte))
          {
            needed += formatImpl(*cast(ubyte*)argptr,putPolicy);
            argptr += ubyte.sizeof;
          }
          else if(strippedType.get == typeid(short))
          {
            needed += formatImpl(*cast(short*)argptr,putPolicy);
            argptr += short.sizeof;
          }
          else if(strippedType.get == typeid(ushort))
          {
            needed += formatImpl(*cast(ushort*)argptr,putPolicy);
            argptr += ushort.sizeof;
          }
          else if(strippedType.get == typeid(int))
          {
            needed += formatImpl(*cast(int*)argptr,putPolicy);
            argptr += int.sizeof;
          }
          else if(strippedType.get == typeid(uint))
          {
            needed += formatImpl(*cast(uint*)argptr,putPolicy);
            argptr += uint.sizeof;
          }
          else if(strippedType.get == typeid(long))
          {
            needed += formatImpl(*cast(long*)argptr,putPolicy);
            argptr += long.sizeof;
          }
          else if(strippedType.get == typeid(ulong))
          {
            needed += formatImpl(*cast(ulong*)argptr,putPolicy);
            argptr += ulong.sizeof;
          }
          else
          {
            throw New!FormatException(_T("Wrong type '") ~ arguments[argNum].toString() ~ _T("' for format specifier %") ~ fmt[i+1]);
          }
          i++;
        }
        else if(fmt[i+1] == 's')
        {
		      ConstRef!(const(TypeInfo)) strippedType = arguments[argNum];
          TypeInfo.Type tt = strippedType.type;
          while(tt == TypeInfo.Type.Const || tt == TypeInfo.Type.Immutable || tt == TypeInfo.Type.Shared)
          {
            strippedType = strippedType.next();
            if(strippedType.get is null)
            {
              throw New!FormatException(_T("Invalid TypeInfo"));
            }
            tt = strippedType.type();
          }

          if(strippedType.type == TypeInfo.Type.Array)
          {
            do {
			        strippedType = strippedType.next();
              if(strippedType.get is null)
              {
                throw New!FormatException(_T("Invalid TypeInfo"));
              }
              tt = strippedType.type();
		        }
            while(tt == TypeInfo.Type.Const || tt == TypeInfo.Type.Immutable || tt == TypeInfo.Type.Shared);

            switch(tt)
            { 
              case TypeInfo.Type.Char:
                {
                  auto str = *cast(const(char)[]*)argptr;
                  argptr += (const(char)[]).sizeof;
                  needed += str.length;
                  foreach(c;str)
                    putPolicy.put(c);
                }
                break;
              case TypeInfo.Type.DChar:
                {
                  auto str = *cast(const(dchar)[]*)argptr;
                  argptr += (const(dchar)[]).sizeof;
                  char[4] cs;
                  foreach(dchar c; str)
                  {
                    size_t len = encode(cs, c);
                    for(size_t j=0; j<len; j++)
                      putPolicy.put(cs[j]);
                    needed += len;
                  }
                }
                break;
              case TypeInfo.Type.Float:
                formatArray!(float, PP)(putPolicy, argptr, needed);
                break;
              case TypeInfo.Type.Double:
                formatArray!(double, PP)(putPolicy, argptr, needed);
                break;
              case TypeInfo.Type.Int:
                formatArray!(int, PP)(putPolicy, argptr, needed);
                break;
              case TypeInfo.Type.UInt:
                formatArray!(uint, PP)(putPolicy, argptr, needed);
                break;
              case TypeInfo.Type.Short:
                formatArray!(short, PP)(putPolicy, argptr, needed);
                break;
              case TypeInfo.Type.UShort:
                formatArray!(ushort, PP)(putPolicy, argptr, needed);
                break;
              case TypeInfo.Type.Long:
                formatArray!(long, PP)(putPolicy, argptr, needed);
                break;
              case TypeInfo.Type.ULong:
                formatArray!(ulong, PP)(putPolicy, argptr, needed);
                break;
              case TypeInfo.Type.Byte:
                formatArray!(byte, PP)(putPolicy, argptr, needed);
                break;
              case TypeInfo.Type.UByte:
                formatArray!(ubyte, PP)(putPolicy, argptr, needed);
                break;
              default:
                {
                   throw New!FormatException(_T("Wrong type '") ~ arguments[argNum].toString() ~ _T("' for format specifier %") ~ fmt[i+1]);
                }
            }
          }
          else if(strippedType.type == TypeInfo.Type.Pointer)
          {
            auto value = *cast(const(char)**)argptr;
            argptr += (const(char)*).sizeof;
            strippedType = strippedType.next();
            tt = strippedType.type;
            while(tt == TypeInfo.Type.Const || tt == TypeInfo.Type.Immutable || tt == TypeInfo.Type.Shared)
            {
              strippedType = strippedType.next();
              if(strippedType is null)
              {
                throw New!FormatException(_T("Invalid TypeInfo"));
              }
              tt = strippedType.type();
            }
            
            if(tt == TypeInfo.Type.Char)
            {
              auto len = strlen(value);
              foreach(c; value[0..len])
                putPolicy.put(c);
              needed += len;
            }
            else
            {
              throw New!FormatException(_T("Wrong type '") ~ arguments[argNum].toString() ~ _T("' for format specifier %") ~ fmt[i+1]);
            }
          }
          else if(strippedType.get == typeid(bool))
          {
            string value = *cast(bool*)argptr ? "true" : "false";
            argptr += bool.sizeof;
            foreach(c; value)
              putPolicy.put(c);
            needed += value.length;
          }
          else if(strippedType.get == typeid(float))
          {
            needed += formatImpl(*cast(float*)argptr, 6, putPolicy, true);
            argptr += float.sizeof;
          }
          else if(strippedType.get == typeid(double))
          {
            needed += formatImpl(*cast(double*)argptr, 6, putPolicy, true);
            argptr += double.sizeof;
          }
          else if(strippedType.get == typeid(byte))
          {
            needed += formatImpl(*cast(byte*)argptr,putPolicy);
            argptr += byte.sizeof;
          }
          else if(strippedType.get == typeid(ubyte))
          {
            needed += formatImpl(*cast(ubyte*)argptr,putPolicy);
            argptr += ubyte.sizeof;
          }
          else if(strippedType.get == typeid(short))
          {
            needed += formatImpl(*cast(short*)argptr,putPolicy);
            argptr += short.sizeof;
          }
          else if(strippedType.get == typeid(ushort))
          {
            needed += formatImpl(*cast(ushort*)argptr,putPolicy);
            argptr += ushort.sizeof;
          }
          else if(strippedType.get == typeid(int))
          {
            needed += formatImpl(*cast(int*)argptr,putPolicy);
            argptr += int.sizeof;
          }
          else if(strippedType.get == typeid(uint))
          {
            needed += formatImpl(*cast(uint*)argptr,putPolicy);
            argptr += uint.sizeof;
          }
          else if(strippedType.get == typeid(long))
          {
            needed += formatImpl(*cast(long*)argptr,putPolicy);
            argptr += long.sizeof;
          }
          else if(strippedType.get == typeid(ulong))
          {
            needed += formatImpl(*cast(ulong*)argptr,putPolicy);
            argptr += ulong.sizeof;
          }
          else {
            auto tio = cast(TypeInfo_Class)arguments[argNum];
            if(tio !is null)
            {
              auto o = cast(Object)argptr;
              argptr += tio.tsize();
              auto str = o.toString();
              needed += str.length;
              foreach(c;str[])
                putPolicy.put(c);
            }
            else {
              //TODO printing structs is not possible because it will leak
              //auto tis = cast(TypeInfo_Struct)arguments[argNum];

              throw New!FormatException(_T("Wrong type '") ~ arguments[argNum].toString() ~ _T("' for format specifier %s"));
            }
          }
          i++;
        }
        else if(fmt[i+1] == 'x')
        {
          ConstRef!(const(TypeInfo)) type = arguments[argNum];
          while(type.classinfo is typeid(TypeInfo_Const) || type.classinfo is typeid(TypeInfo_Invariant) || type.classinfo is typeid(TypeInfo_Shared))
          {
            type = type.next;
          }

          if(type.get == typeid(byte))
          {
            needed += formatHex(*cast(ubyte*)argptr,putPolicy);
            argptr += byte.sizeof;
          }
          else if(type.get == typeid(ubyte))
          {
            needed += formatHex(*cast(ubyte*)argptr,putPolicy);
            argptr += ubyte.sizeof;
          }
          else if(type.get == typeid(short))
          {
            needed += formatHex(*cast(ushort*)argptr,putPolicy);
            argptr += short.sizeof;
          }
          else if(type.get == typeid(ushort))
          {
            needed += formatHex(*cast(ushort*)argptr,putPolicy);
            argptr += ushort.sizeof;
          }
          else if(type.get == typeid(int))
          {
            needed += formatHex(*cast(uint*)argptr,putPolicy);
            argptr += int.sizeof;
          }
          else if(type.get == typeid(uint))
          {
            needed += formatHex(*cast(uint*)argptr,putPolicy);
            argptr += uint.sizeof;
          }
          else if(type.get == typeid(long))
          {
            needed += formatHex(*cast(ulong*)argptr,putPolicy);
            argptr += long.sizeof;
          }
          else if(type.get == typeid(ulong))
          {
            needed += formatHex(*cast(ulong*)argptr,putPolicy);
            argptr += ulong.sizeof;
          }
          else if(type.classinfo is typeid(TypeInfo_Pointer) || type.classinfo is typeid(TypeInfo_Class) || type.classinfo is typeid(TypeInfo_Interface))
          {
            needed += formatHex(*cast(size_t*)argptr,putPolicy);
            argptr += size_t.sizeof;
          }
          else
          {
            throw New!FormatException(_T("Wrong type '") ~ arguments[argNum].toString() ~ _T("' for format specifier %") ~ fmt[i+1]);
          }
          i++;
        }
        else if(fmt[i+1] == 'c')
        {
		      ConstRef!(const(TypeInfo)) strippedType = arguments[argNum];
          TypeInfo.Type tt = strippedType.type;
          while(tt == TypeInfo.Type.Const || tt == TypeInfo.Type.Immutable)
          {
            strippedType = strippedType.next();
            if(strippedType is null)
            {
              throw New!FormatException(_T("Invalid TypeInfo"));
            }
            tt = strippedType.type();
          }

          if(strippedType.get == typeid(char))
          {
            auto c = *cast(const(char)*)argptr;
            argptr += (const(char)).sizeof;
            putPolicy.put(c);
            needed++;
          }
          else if(strippedType.get == typeid(wchar))
          {
            auto c = *cast(const(wchar)*)argptr;
            argptr += (const(wchar)).sizeof;
            char[4] cs;
            size_t len = encode(cs, c);
            for(size_t j=0; j<len; j++)
              putPolicy.put(cs[j]);
            needed++;
          }
          else if(strippedType.get == typeid(dchar))
          {
            auto c = *cast(const(dchar)*)argptr;
            argptr += (const(dchar)).sizeof;
            char[4] cs;
            size_t len = encode(cs, c);
            for(size_t j=0; j<len; j++)
              putPolicy.put(cs[j]);
            needed++;
          }
          else
          {
            throw New!FormatException(_T("Wrong type '") ~ arguments[argNum].toString() ~ _T("' for format specifier %") ~ fmt[i+1]);
          }
          i++;
        }
        else if(fmt[i+1] == '.')
        {
          size_t fpos = i+2;
          for(;fpos < fmt.length && fmt[fpos] != 'f'; fpos++){}
          if(fpos >= fmt.length)
          {
            throw New!FormatException(_T("Missing end for %.<number>f format specifier"));
          }

          if(fpos == i+2)
          {
            throw New!FormatException(_T("Missing number for %.<number>f format specifier"));
          }

          uint percision = 0;
          if(to(fmt[(i+2)..(fpos)],percision) == thResult.FAILURE)
          {
            throw New!FormatException(_T("Invalid number for %.<number>f format specifier"));
          }

          if(arguments[argNum] == typeid(float))
          {
            needed += formatImpl(*cast(float*)argptr, percision, putPolicy, false);
            argptr += float.sizeof;
          }
          else if(arguments[argNum] == typeid(double))
          {
            needed += formatImpl(*cast(double*)argptr, percision, putPolicy, false);
            argptr += double.sizeof;
          }
          else {
            throw New!FormatException(_T("Wrong type '") ~ arguments[argNum].toString() ~ _T("' for format specifier %.<number>f"));
          }
          i += fpos - i;
        }
        else {
          throw New!FormatException(_T("Unknown format specifier %") ~ fmt[i+1]);
        }
        argNum++;
      }
    }
  }

  return needed;
}

size_t formatDoStatic(char[] buffer, const(char)[] fmt, TypeInfo[] arguments, void* argptr)
{
  auto put = BufferPutPolicy!char(buffer);
  return formatDo(put,fmt,arguments,argptr);
}

size_t formatStatic(char[] buffer, const(char)[] fmt, ...)
{
  auto put = BufferPutPolicy!char(buffer);
  return formatDo(put,fmt,_arguments,_argptr);
}

unittest {
  char[256] buf;
  size_t needed = formatStatic(buf, "Hello %.4f World", 1.23456f);
  assert(buf[0..needed] == "Hello 1.2345 World");

  needed = formatStatic(buf, "Hello %d World", 1234);
  assert(buf[0..needed] == "Hello 1234 World");

  needed = formatStatic(buf, "Hello %s World", "beautiful");
  assert(buf[0..needed] == "Hello beautiful World");
}

rcstring format(const(char)[] fmt, ...)
{
  auto dummy = NothingPutPolicy!char();
  size_t needed = formatDo(dummy,fmt,_arguments,_argptr);
  auto result = rcstring(needed);
  auto put = BufferPutPolicy!char(cast(char[])result[]);
  formatDo(put,fmt,_arguments,_argptr);
  return result;
}

auto formatAllocator(AT)(AT allocator, const(char)[] fmt, ...)
{
  assert(allocator !is null);
  auto dummy = NothingPutPolicy!char();
  size_t needed = formatDo(dummy, fmt, _arguments, _argptr);
  auto result = RCArray!(immutable(char), IAllocator)(needed, allocator);
  auto put = BufferPutPolicy!char(cast(char[])result[]);
  formatDo(put,fmt,_arguments,_argptr);
  return result;
}

/**
 * Formats a string to a buffer allocated with a given allocator
 * Params:
 *  allocator = the allocator to use for allocating the buffer
 *  fmt = the format specifier
 *  arguments = the arguments types
 *  argptr = the argument pointer
 * Returns: The allocated buffer with the format results
 */
string formatDoBufferAllocator(AT)(AT allocator, const(char)[] fmt, TypeInfo[] arguments, void* argptr)
{
  assert(allocator !is null);
  auto dummy = NothingPutPolicy!char();
  size_t needed = formatDo(dummy, fmt, arguments, argptr);
  auto result = AllocatorNewArray!char(allocator, needed);
  auto put = BufferPutPolicy!char(cast(char[])result[]);
  formatDo(put, fmt, arguments, argptr);
  return cast(string)result;
}

/**
 * Formats a string to a buffer allocated with a given allocator
 * Params:
 *  allocator = The allocator to allocate the buffer with
 *  fmt = the format specifier
 * Returns: The allocated buffer with the format results
 */
string formatBufferAllocator(AT)(AT allocator, const(char)[] fmt, ...)
{
  return formatDoBufferAllocator!AT(allocator, fmt, _arguments, _argptr);
}

unittest
{
  void* test = cast(void*)(0x1234ABCD);
  auto cstr = "cstr";
  auto str = format("a %d b %f c %.3f d %s e %x %s",123,123.12345678,345.6789,"bla",test,cstr.ptr);
  assert(str[] == "a 123 b 123.123456 c 345.678 d bla e 0x1234ABCD cstr");
  float[3] farray;
  farray[0] = 1.25f;
  farray[1] = 0.5f;
  farray[2] = 3.75f;
  double[3] darray;
  darray[0] = 1.25;
  darray[1] = 0.5;
  darray[2] = 3.75;
  int[3] iarray;
  iarray[0] = 0;
  iarray[1] = 1;
  iarray[2] = 2;
  auto str2 = format("%s %s %s", farray, darray, iarray);
  assert(str2[] == "[1.25, 0.5, 3.75] [1.25, 0.5, 3.75] [0, 1, 2]"); 
  auto str3 = format("%s:%d", cast(const(char*))"hello".ptr, cast(ushort)80);
  assert(str3 == "hello:80");
}