module thBase.format;

import std.traits;
import core.refcounted;
import thBase.conv;
import thBase.types;
import thBase.file;
import thBase.utf;
import thBase.constref;
import core.stdc.string;
import core.vararg;

const(TypeInfo) unqualTypeInfo(const(TypeInfo) info)
{
  auto tt = info.type;
  if(tt == TypeInfo.Type.Const || tt == TypeInfo.Type.Immutable || tt == TypeInfo.Type.Shared)
    return unqualTypeInfo(info.nextTypeInfo);
  return info;
}

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
  size_t needed = 0;
  if(f < cast(T)0)
  {
    putPolicy.put('-');
    needed++;
    f *= cast(T)-1;
  }

  long start = cast(long)f;
  needed += formatImpl(start,putPolicy);
  if(num == 0)
    return needed;

  f -= cast(T)start;
  
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

private va_list formatArray(T,PP)(ref PP putPolicy, va_list argptr, ref size_t needed)
{
  auto data = va_arg!(const(T)[])(argptr);
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
  return argptr;
}

size_t formatDo(PP)(ref PP putPolicy, const(char)[] fmt, TypeInfo[] arguments, va_list argptr)
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
        needed++;
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
		      auto strippedType = unqualTypeInfo(arguments[argNum]);
          TypeInfo.Type tt = strippedType.type;

          switch(tt)
          {
            case TypeInfo.Type.Float:
              needed += formatImpl(va_arg!float(argptr), 6, putPolicy, true);
              break;
            case TypeInfo.Type.Double:
              needed += formatImpl(va_arg!double(argptr), 6, putPolicy, true);
              break;
            case TypeInfo.Type.Real:
              needed += formatImpl(va_arg!real(argptr), 6, putPolicy, true);
              break;
            default:
              throw New!FormatException(_T("Wrong type '") ~ arguments[argNum].toString() ~ _T("' for format specifier %f"));
          }
          i++;
        }
        else if(fmt[i+1] == 'd' || fmt[i+1] == 'i')
        {
		      auto strippedType = unqualTypeInfo(arguments[argNum]);
          TypeInfo.Type tt = strippedType.type;

          switch(tt)
          {
            case TypeInfo.Type.Byte:
              needed += formatImpl(va_arg!byte(argptr), putPolicy);
              break;
            case TypeInfo.Type.UByte:
              needed += formatImpl(va_arg!ubyte(argptr), putPolicy);
              break;
            case TypeInfo.Type.Short:
              needed += formatImpl(va_arg!short(argptr), putPolicy);
              break;
            case TypeInfo.Type.UShort:
              needed += formatImpl(va_arg!ushort(argptr), putPolicy);
              break;
            case TypeInfo.Type.Int:
              needed += formatImpl(va_arg!int(argptr), putPolicy);
              break;
            case TypeInfo.Type.UInt:
              needed += formatImpl(va_arg!uint(argptr), putPolicy);
              break;
            case TypeInfo.Type.Long:
              needed += formatImpl(va_arg!long(argptr), putPolicy);
              break;
            case TypeInfo.Type.ULong:
              needed += formatImpl(va_arg!ulong(argptr), putPolicy);
              break;
            default:
              throw New!FormatException(_T("Wrong type '") ~ arguments[argNum].toString() ~ _T("' for format specifier %") ~ fmt[i+1]);
          }
          i++;
        }
        else if(fmt[i+1] == 's')
        {
		      auto strippedType = unqualTypeInfo(arguments[argNum]);
          TypeInfo.Type tt = strippedType.type;

          switch(tt)
          {
            case TypeInfo.Type.Array:
            {
              auto elementType = unqualTypeInfo(strippedType.nextTypeInfo);
              auto et = elementType.type;

              switch(et)
              { 
                case TypeInfo.Type.Char:
                  {
                    auto dstr = va_arg!(const(char)[])(argptr);
                    needed += dstr.length;
                    foreach(c;dstr)
                      putPolicy.put(c);
                  }
                  break;
                case TypeInfo.Type.DChar:
                  {
                    auto str = va_arg!(const(dchar)[])(argptr);
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
                  argptr = formatArray!(float, PP)(putPolicy, argptr, needed);
                  break;
                case TypeInfo.Type.Double:
                  argptr = formatArray!(double, PP)(putPolicy, argptr, needed);
                  break;
                case TypeInfo.Type.Int:
                  argptr = formatArray!(int, PP)(putPolicy, argptr, needed);
                  break;
                case TypeInfo.Type.UInt:
                  argptr = formatArray!(uint, PP)(putPolicy, argptr, needed);
                  break;
                case TypeInfo.Type.Short:
                  argptr = formatArray!(short, PP)(putPolicy, argptr, needed);
                  break;
                case TypeInfo.Type.UShort:
                  argptr = formatArray!(ushort, PP)(putPolicy, argptr, needed);
                  break;
                case TypeInfo.Type.Long:
                  argptr = formatArray!(long, PP)(putPolicy, argptr, needed);
                  break;
                case TypeInfo.Type.ULong:
                  argptr = formatArray!(ulong, PP)(putPolicy, argptr, needed);
                  break;
                case TypeInfo.Type.Byte:
                  argptr = formatArray!(byte, PP)(putPolicy, argptr, needed);
                  break;
                case TypeInfo.Type.UByte:
                  argptr = formatArray!(ubyte, PP)(putPolicy, argptr, needed);
                  break;
                default:
                  {
                     throw New!FormatException(_T("Wrong type '") ~ arguments[argNum].toString() ~ _T("' for format specifier %") ~ fmt[i+1]);
                  }
              }
            }
            break;
          case TypeInfo.Type.Pointer:
            {
              auto value = va_arg!(const(char)*)(argptr);
              auto targetType = unqualTypeInfo(strippedType.nextTypeInfo);
              auto t = targetType.type;
            
              if(t == TypeInfo.Type.Char)
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
            break;
          case TypeInfo.Type.Bool:
            {
              string value = va_arg!bool(argptr) ? "true" : "false";
              foreach(c; value)
                putPolicy.put(c);
              needed += value.length;
            }
            break;
          case TypeInfo.Type.Float:
            needed += formatImpl(va_arg!float(argptr), 6, putPolicy, true);
            break;
          case TypeInfo.Type.Double:
            needed += formatImpl(va_arg!double(argptr), 6, putPolicy, true);
            break;
          case TypeInfo.Type.Byte:
            needed += formatImpl(va_arg!byte(argptr), putPolicy);
            break;
          case TypeInfo.Type.UByte:
            needed += formatImpl(va_arg!ubyte(argptr), putPolicy);
            break;  
          case TypeInfo.Type.Short:
            needed += formatImpl(va_arg!short(argptr), putPolicy);
            break;
          case TypeInfo.Type.UShort:
            needed += formatImpl(va_arg!ushort(argptr), putPolicy);
            break;
          case TypeInfo.Type.Int:
            needed += formatImpl(va_arg!int(argptr), putPolicy);
            break;
          case TypeInfo.Type.UInt:
            needed += formatImpl(va_arg!uint(argptr), putPolicy);
            break;
          case TypeInfo.Type.Long:
            needed += formatImpl(va_arg!long(argptr), putPolicy);
            break;
          case TypeInfo.Type.ULong:
            needed += formatImpl(*cast(ulong*)argptr,putPolicy);
            break;
          case TypeInfo.Type.Class:
            {
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
                throw New!FormatException(_T("Wrong type '") ~ arguments[argNum].toString() ~ _T("' for format specifier %s"));
              }
            }
            break;
          default:
            throw New!FormatException(_T("Wrong type '") ~ arguments[argNum].toString() ~ _T("' for format specifier %s"));
          }
          i++;
        }
        else if(fmt[i+1] == 'x')
        {
          auto strippedType = unqualTypeInfo(arguments[argNum]);
          auto tt = strippedType.type;

          switch(tt)
          {
            case TypeInfo.Type.Byte:
            case TypeInfo.Type.UByte:
              needed += formatHex(va_arg!ubyte(argptr), putPolicy);
              break;
            case TypeInfo.Type.Short:
            case TypeInfo.Type.UShort:
              needed += formatHex(va_arg!ushort(argptr), putPolicy);
              break;
            case TypeInfo.Type.Int:
            case TypeInfo.Type.UInt:
              needed += formatHex(va_arg!uint(argptr), putPolicy);
              break;
            case TypeInfo.Type.Long:
            case TypeInfo.Type.ULong:
              needed += formatHex(va_arg!ulong(argptr), putPolicy);
              break;
            case TypeInfo.Type.Pointer:
            case TypeInfo.Type.Class:
            case TypeInfo.Type.Interface:
              needed += formatHex(va_arg!size_t(argptr), putPolicy);
              break;
            default: 
              throw New!FormatException(_T("Wrong type '") ~ arguments[argNum].toString() ~ _T("' for format specifier %") ~ fmt[i+1]);
          }
          i++;
        }
        else if(fmt[i+1] == 'c')
        {
		      auto strippedType = unqualTypeInfo(arguments[argNum]);
          auto tt = strippedType.type;

          switch(tt)
          {
            case TypeInfo.Type.Char:
              putPolicy.put(va_arg!char(argptr));
              needed++;
              break;
            case TypeInfo.Type.WChar:
              {
                auto c = va_arg!wchar(argptr);
                char[4] cs;
                size_t len = encode(cs, c);
                for(size_t j=0; j<len; j++)
                  putPolicy.put(cs[j]);
                needed += len;
              }
              break;
            case TypeInfo.Type.DChar:
              {
                auto c = va_arg!dchar(argptr);
                char[4] cs;
                size_t len = encode(cs, c);
                for(size_t j=0; j<len; j++)
                  putPolicy.put(cs[j]);
                needed += len;
              }
              break;
            default:
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
          if(to(fmt[(i+2)..(fpos)], percision) == thResult.FAILURE)
          {
            throw New!FormatException(_T("Invalid number for %.<number>f format specifier"));
          }

          auto strippedType = unqualTypeInfo(arguments[argNum]);
          auto tt = strippedType.type;

          switch(tt)
          {
            case TypeInfo.Type.Float:
              needed += formatImpl(va_arg!float(argptr), percision, putPolicy, false);
              break;
            case TypeInfo.Type.Double:
              needed += formatImpl(va_arg!double(argptr), percision, putPolicy, false);
              break;
            case TypeInfo.Type.Real:
              needed += formatImpl(va_arg!real(argptr), percision, putPolicy, false);
              break;
            default:
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

size_t formatDoStatic(char[] buffer, const(char)[] fmt, TypeInfo[] arguments, va_list argptr)
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

  ubyte value = 123;
  needed = formatStatic(buf, "%s %d", true, value);
  assert(buf[0..needed] == "true 123");
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
string formatDoBufferAllocator(AT)(AT allocator, const(char)[] fmt, TypeInfo[] arguments, va_list argptr)
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
  auto str = format("a %d b %f c %.3f d %s e %x %s",123,123.12345678,345.6789,"bla",test,"cstr".ptr);
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
  auto str4 = format("%.3f, %.3f, %.3f", 0.404, -0.404, -0.808);
  assert(str4 == "0.404, -0.404, -0.808");
}