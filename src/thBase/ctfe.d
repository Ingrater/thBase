module thBase.ctfe;

import thBase.format : formatImpl;

struct StringPutPolicy(T)
{
  string buffer;

  void put(T character)
  {
    buffer ~= character;
  }
}

string toString(T)(T val)
{
  StringPutPolicy!char p;
  formatImpl(val,p);
  return p.buffer;
}