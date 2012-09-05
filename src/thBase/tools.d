module thBase.tools;

import thBase.format;
import thBase.traits;

private auto toStringHelper(T)(auto ref T arg)
{
  static if(is(T == string))
  {
    return arg;
  }
  else static if(isRCString!T)
  {
    return arg[];
  }
  else static if(is(T == class))
  {
    return arg.toString();
  }
  else
  {
    static assert(0, "not implemented");
  }
}

private string argHelper(T)(auto ref T arg)
{
  static if(is(T == string))
  {
    return arg;
  }
  else static if(isRCString!T)
  {
    return arg[];
  }
  else
  {
    static assert(0, "not implemented");
  }
}

rcstring text(T1)(T1 arg1)
{
  auto s1 = toStringHelper(arg1);
  return format("%s", argHelper(s1));
}

rcstring text(T1, T2)(T1 arg1, T2 arg2)
{
  auto s1 = toStringHelper(arg1);
  auto s2 = toStringHelper(arg2);

  return format("%s %s", argHelper(s1), argHelper(s2));
}

rcstring text(T1, T2, T3)(T1 arg1, T2 arg2, T3 arg3)
{
  auto s1 = toStringHelper(arg1);
  auto s2 = toStringHelper(arg2);
  auto s3 = toStringHelper(arg3);

  return format("%s %s %s", argHelper(s1), argHelper(s2), argHelper(s3));
}

rcstring text(T1, T2, T3, T4)(T1 arg1, T2 arg2, T3 arg3, T4 arg4)
{
  auto s1 = toStringHelper(arg1);
  auto s2 = toStringHelper(arg2);
  auto s3 = toStringHelper(arg3);
  auto s4 = toStringHelper(arg4);

  return format("%s %s %s %s", argHelper(s1), argHelper(s2), argHelper(s3), argHelper(s4));
}

rcstring text(T1, T2, T3, T4, T5)(T1 arg1, T2 arg2, T3 arg3, T4 arg4, T5 arg5)
{
  auto s1 = toStringHelper(arg1);
  auto s2 = toStringHelper(arg2);
  auto s3 = toStringHelper(arg3);
  auto s4 = toStringHelper(arg4);
  auto s5 = toStringHelper(arg5);

  return format("%s %s %s %s %s", argHelper(s1), argHelper(s2), argHelper(s3), argHelper(s4), argHelper(s5));
}