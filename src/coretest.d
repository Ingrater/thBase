module coretest;

import core.refcounted;
import thBase.devhelper;

unittest
{
  auto leak = LeakChecker("coretest");
  {

    RCArray!(immutable(char), IAllocator) str1;
    {
      auto str2 = rcstring("Hello World");
      str1 = str2;
    }

    assert(!_T("")); //empty string should evaluate to false

    static rcstring testFunc1(rcstring str)
    {
      str ~= "World!";
      return str;
    }

    rcstring str3 = "Hello ";
    str3 = testFunc1(str3);
  }
}