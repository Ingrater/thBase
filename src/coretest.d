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

  }
}