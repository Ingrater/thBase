module thBase.io;

import thBase.format;
import core.sys.windows.windows;
import core.sync.mutex;
import core.allocator;
import thBase.stream;
import thBase.casts;

__gshared HANDLE g_hStdOut;
__gshared Mutex g_outMutex;
__gshared Stdin stdin;

class InitHelper
{
  shared static this()
  {
    g_hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);
    g_outMutex = New!Mutex();
    stdin = New!Stdin();
  }

  shared static ~this()
  {
    Delete(stdin);
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

class Stdin : IInputStream
{
  private:
    HANDLE m_stdInHandle;
    Mutex m_mutex;
    void[2048] m_buffer = void;
    size_t m_remaining = 0;
    size_t m_curReadPos = 0;

    void ensureBytesLeft(size_t size)
    {
      if(size > m_remaining)
      {
        DWORD bytesRead = 0;
        m_buffer[0..m_remaining] = m_buffer[m_curReadPos..m_curReadPos + m_remaining];
        ReadConsoleA(m_stdInHandle, m_buffer.ptr + m_remaining, int_cast!uint(m_buffer.length - m_remaining), &bytesRead, null);
        m_remaining += bytesRead;
      }
    }

  public:
    this()
    {
      m_mutex = New!Mutex();
      m_stdInHandle = GetStdHandle(STD_INPUT_HANDLE);
    }

    ~this()
    {
      Delete(m_mutex);
    }

    size_t skip(size_t bytes)
    {
      ensureBytesLeft(bytes);
      auto oldRemaining = m_remaining;
      if(bytes > m_remaining)
      {
        m_remaining = 0;
      }
      else
      {
        m_remaining -= bytes;
      }
      size_t bytesSkipped = oldRemaining - m_remaining;
      m_curReadPos += bytesSkipped;
      return bytesSkipped;
    }

    protected size_t readImpl(void[] buffer)
    {
      ensureBytesLeft(buffer.length);
      auto oldRemaining = m_remaining;
      if(buffer.length > m_remaining)
      {
        m_remaining = 0;
      }
      else
      {
        m_remaining -= buffer.length;
      }
      size_t bytesRead = oldRemaining - m_remaining;
      buffer[0..bytesRead] = m_buffer[m_curReadPos..m_curReadPos+bytesRead];
      m_curReadPos += bytesRead;
      return bytesRead;
    }
}