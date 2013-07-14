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
__gshared Stdout stdout;

class InitHelper
{
  shared static this()
  {
    g_hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);
    g_outMutex = New!Mutex();
    stdin = New!Stdin();
    stdout = New!Stdout();
  }

  shared static ~this()
  {
    Delete(stdin);
    Delete(stdout);
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
    bool m_readDone = false;

    void ensureBytesLeft(size_t size)
    {
      if(!m_readDone && size > m_remaining)
      {
        DWORD bytesRead = 0;
        m_buffer[0..m_remaining] = m_buffer[m_curReadPos..m_curReadPos + m_remaining];
        ReadConsoleA(m_stdInHandle, m_buffer.ptr + m_remaining, int_cast!uint(m_buffer.length - m_remaining), &bytesRead, null);
        if(bytesRead < m_buffer.length - m_remaining)
          m_readDone = true;
        m_remaining += bytesRead;
        m_curReadPos = 0;
        auto read = cast(char[])m_buffer;
        if((cast(char[])m_buffer)[m_remaining-1] == '\n') m_remaining--;
        if((cast(char[])m_buffer)[m_remaining-1] == '\r') m_remaining--;
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
      m_mutex.lock();
      scope(exit) m_mutex.unlock();
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
      m_mutex.lock();
      scope(exit) m_mutex.unlock();
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

    bool stopAtEol = false;

    final void resetLine()
    {
      m_mutex.lock();
      scope(exit) m_mutex.unlock();
      m_readDone = false;
    }
}

class Stdout : IOutputStream
{
  private:
    HANDLE m_stdOutHandle;
    void[2048] m_buffer = void;
    size_t m_bytesBuffered;

  public:
    ~this()
    {
      flush();
    }

    final void flush()
    {
      g_outMutex.lock();
      scope(exit) g_outMutex.unlock();
      if(m_bytesBuffered > 0)
      {
        WriteFile(g_hStdOut, m_buffer.ptr, int_cast!uint(m_bytesBuffered), null, null);
        m_bytesBuffered = 0;
      }
    }

    final override size_t writeImpl(const(void[]) data)
    {
      g_outMutex.lock();
      scope(exit) g_outMutex.unlock();
      if(data.length > m_buffer.length)
      {
        flush();
        WriteFile(g_hStdOut, data.ptr, int_cast!uint(data.length), null, null);
        return data.length;
      }
      else if(m_buffer.length - m_bytesBuffered < data.length)
        flush();
      m_buffer[m_bytesBuffered..m_bytesBuffered + data.length] = data[];
      m_bytesBuffered += data.length;
      return data.length;
    }
};