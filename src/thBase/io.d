module thBase.io;

import thBase.format;
import core.sys.windows.windows;
import core.sync.mutex;
import core.allocator;

__gshared HANDLE g_hStdOut;
__gshared Mutex g_outMutex;

class InitHelper
{
  shared static this()
  {
    g_hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);
    g_outMutex = New!Mutex();
  }

  shared static ~this()
  {
    Delete(g_outMutex);
  }
}

struct StdOutPutPolicy
{
  char[2048] buffer;
  uint pos = 0;

  void put(char character)
  {
    if(pos >= buffer.length)
    {
      flush();
    }
    buffer[pos] = character;
    pos++;
  }

  void flush()
  {
    if(g_hStdOut != INVALID_HANDLE_VALUE)
    {
      g_outMutex.lock();
      scope(exit) g_outMutex.unlock();
      WriteFile(g_hStdOut, buffer.ptr, pos, null, null);
    }
    pos = 0;
  }
}

size_t writef(string fmt, ...)
{
  StdOutPutPolicy put;
  size_t written = formatDo(put, fmt, _arguments, _argptr);
  put.flush();
  return written;
}

size_t writefln(string fmt, ...)
{
  StdOutPutPolicy put;
  size_t written = formatDo(put, fmt, _arguments, _argptr);
  put.put('\r');
  put.put('\n');
  put.flush();
  return written;
}

unittest
{
  writefln("thBase.io unittest %f %d ", 0.5f, 1337);
}