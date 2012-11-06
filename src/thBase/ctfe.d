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

uint FNVHash(string str)
{
  uint hash = 2166136261u;
  foreach(c; str)
  {
    hash ^= c;
    hash *= 16777619u;
  }

  return hash;
}

sizediff_t indexOfChar(string haystack, char needle)
{
  foreach(size_t i, c; haystack)
  {
    if(c == needle)
      return cast(sizediff_t)i;
  }
  return -1;
}