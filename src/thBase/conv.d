module thBase.conv;

import std.traits;
import thBase.traits;
public import thBase.types;
import core.refcounted;
import thBase.utf;

class ConvException : RCException
{
  this(rcstring message, string file = __FILE__, int line = __LINE__)
  {
    super(message,file,line);
  }
}

//TT = target type
//ST = source type

//parse any string type to an integer type
thResult to(TT,ST)(ST arg, out TT result) if(isIntegral!TT && thBase.traits.isSomeString!ST)
{
  auto str = arg[];
  TT sign = 1;

  static if(isSigned!TT)
  {
    if(str[0] == '-')
    {
      sign = -1;
      str=str[1..$];
    }
    else if(str[0] == '+')
    {
      str=str[1..$];
    }
  }

  foreach(c;str)
  {
    if(c < '0' || c > '9')
    {
      return thResult.FAILURE;
    }
  }

  TT number = 0;
  TT power = 1;
  foreach_reverse(c;str)
  {
    TT digit = cast(TT)(c - '0');
    number += digit * power;
    power *= 10;
  }
  result = cast(TT)(number * sign);
  return thResult.SUCCESS;
}

TT to(TT,ST)(ST arg) if(isIntegral!TT && isSigned!TT && thBase.traits.isSomeString!ST)
{
  TT result = void;
  if(to!(TT,ST)(arg,result) == thResult.FAILURE)
  {
    throw New!ConvException(_T("Error converting string to signed integral type"));
  }
  return result;
}

unittest {
  int result;
  long lresult;
  uint uiresult;
  assert(to!(int)("123",result) == thResult.SUCCESS);
  assert(result == 123);
  assert(to!(int)("+657",result) == thResult.SUCCESS);
  assert(result == 657);
  assert(to!(int)("-450",result) == thResult.SUCCESS);
  assert(result == -450);
  assert(to!(long)("-bla",lresult) == thResult.FAILURE);
  assert(to!(uint)("-456",uiresult) == thResult.FAILURE);
  assert(to!(uint)("123456",uiresult) == thResult.SUCCESS);
  assert(uiresult == 123456);
}

thResult to(TT,ST)(ST arg, out TT result) if(isFloatingPoint!TT && thBase.traits.isSomeString!ST)
{
  auto str = arg[];
  TT sign = cast(TT)1;
  size_t needed = 0;

  if(str[0] == '-')
  {
    sign = cast(TT)-1;
    str=str[1..$];
  }
  else if(str[0] == '+')
  {
    str=str[1..$];
  }

  size_t commaPos = 0;
  for(;commaPos < str.length && str[commaPos] != '.';commaPos++){}

  long preComma = 0;
  if(to!long(str[0..commaPos],preComma) != thResult.SUCCESS)
  {
    return thResult.FAILURE;
  }

  TT number = cast(TT)preComma;

  if(commaPos < str.length-1)
  {
    TT power = cast(TT)0.1;
    str = str[(commaPos+1)..$];
    foreach(c;str)
    {
      if(c < '0' || c > '9')
      {
        return thResult.FAILURE;
      }

      number += cast(TT)(c - '0') * power;
      power *= cast(TT)0.1;
    }
  }

  result = number * sign;
  return thResult.SUCCESS;
}

unittest 
{
  float fresult;
  double dresult;
  assert(to("-12.345",fresult) == thResult.SUCCESS);
  assert(fresult == -12.345f);
  assert(to("450",dresult) == thResult.SUCCESS);
  assert(dresult == 450.0);
  assert(to("760.",fresult) == thResult.SUCCESS);
  assert(fresult == 760.0);
}

TT to(TT,ST)(ST arg) if(isFloatingPoint!TT && thBase.traits.isSomeString!ST)
{
  TT result = void;
  if(to!(TT,ST)(arg,result) == thResult.FAILURE)
  {
    throw New!ConvException(_T("Error converting string to floating point type"));
  }
  return result;
}

TT to(TT,ST)(ST arg) if(isRCString!TT && (is(ST == dchar[]) || is(ST == immutable(dchar)[])))
{
  char[4] cs;
  size_t len = 0;
  foreach(dchar c; arg)
  {
    size_t charLen = encode(cs, c);
    len += charLen;
  }

  auto result = TT(len);
  auto mem = cast(char[])result[];
  len = 0;
  foreach(dchar c; arg)
  {
    size_t charLen = encode(cs, c);
    mem[len..len+charLen] = cs[0..charLen];
    len += charLen;
  }
  return result;
}

string EnumToStringGenerate(T,string templateVar = "T", string pre = "")(string var){
	string res = "final switch(" ~ var ~ "){";
	foreach(m;__traits(allMembers,T)){
		res ~= "case " ~ templateVar ~ "." ~ m ~ ": return \"" ~ pre ~ m ~ "\";";
	}
	res ~= "}";
	return res;
}

string EnumToString(T)(T value){
	mixin(EnumToStringGenerate!(T)("value"));
}

unittest
{
  enum Test : uint
  {
    Value1,
    Value2,
    Value3
  }

  assert(EnumToString(Test.Value1) == "Value1");
  assert(EnumToString(Test.Value2) == "Value2");
  assert(EnumToString(Test.Value3) == "Value3");
}