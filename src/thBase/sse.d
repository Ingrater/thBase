module thBase.sse;

version(USE_SSE)
{
  shared static this()
  {
    //TODO check core.cpuid for SSE 4.1
  }
}

template shuffleIndex(char component)
{
  static if(component == 'x')
  {
    enum ubyte shuffleIndex = 0;
  }
  else static if(component == 'y')
  {
    enum ubyte shuffleIndex = 1;
  }
  else static if(component == 'z')
  {
    enum ubyte shuffleIndex = 2;
  }
  else static if(component == 'w')
  {
    enum ubyte shuffleIndex = 3;
  }
  else
  {
    static assert(0, component ~ " is not a valid shuffle index");
  }
}

template shuffleConstant(string op)
{
  static assert(op.length == 4);
  enum ubyte shuffleConstant = (shuffleIndex!op[0] << 6) | (shuffleIndex!op[1] << 4) | (shuffleIndex!op[2] << 2) | (shuffleIndex!op[3]);
}