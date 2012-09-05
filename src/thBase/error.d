module thBase.error;

import core.allocator;
import thBase.allocator;
import thBase.policies.locking;
import thBase.format;
import thBase.string;

private void[] g_errorMemory; //error memory tls
private FixedBlockAllocator!NoLockPolicy g_blockAllocator;
private FixedStackAllocator!(MutexLockPolicy, FixedBlockAllocator!NoLockPolicy) g_stackAllocator;
private ErrorContext* g_currentError; //current error tls

class InitHelper
{
  static this()
  {
    g_errorMemory = cast(void[])NewArray!byte(1024);
    g_blockAllocator = New!(typeof(g_blockAllocator))(g_errorMemory);
    g_stackAllocator = New!(typeof(g_stackAllocator))(1024,g_blockAllocator);
  }

  static ~this()
  {
    Delete(g_stackAllocator);
    Delete(g_blockAllocator);
    Delete(g_errorMemory);
  }
}

struct ErrorContext 
{
  ErrorContext* m_prev;
  string[] m_data;

  void writeTo(scope void delegate(const(char)[]) writefunc)
  {
    foreach(s; m_data)
    {
      writefunc(s);
      writefunc(" ");
    }
    writefunc("\n");
    if(m_prev !is null)
    {
      m_prev.writeTo(writefunc);
    }
  }

  static ErrorContext* create(ARGS...)(ARGS args)
  {
    static assert(ARGS.length > 0, "at least 1 argument required");
    enum size_t neededMemory = ErrorContext.sizeof + string.sizeof * ARGS.length;

    void[] mem = g_stackAllocator.AllocateMemory(neededMemory);
    string[] data = (cast(string*)mem.ptr)[0..ARGS.length];
    foreach(i,arg;args)
    {
      data[i] = arg;
    }
    ErrorContext* error = cast(ErrorContext*)(mem.ptr + string.sizeof * ARGS.length);
    error.m_prev = g_currentError;
    error.m_data = data;
    g_currentError = error;
    return error;
  }
}

struct ErrorScope
{
  ErrorContext* m_context;

  @disable this();

  this(ErrorContext* context)
  {
    m_context = context;
  }

  ~this()
  {
    assert(m_context == g_currentError);
    g_currentError = m_context.m_prev;
    g_stackAllocator.FreeMemory(m_context.m_data.ptr);
  }
}

rcstring FormatError(string fmt, ...)
{
  auto appender = StringAppendBuffer!()(4096, 1024);
  appender.doFormat(fmt, _arguments, _argptr);
  appender ~= "\nError Context:";
  for(ErrorContext* cur = g_currentError; cur !is null; cur = cur.m_prev)
  {
    appender ~= "\n";
    foreach(string msg; cur.m_data)
    {
      appender ~= " ";
      appender ~= msg;
    }
  }
  return appender.str;
}

version(unittest)
{
  import core.stdc.stdio;
  import thBase.devhelper;
}

unittest
{
  void func3()
  {
    auto error = ErrorScope(ErrorContext.create("func3","arg4","arg5","arg6"));
    auto msg = FormatError("Test error %f %d",0.5f,12);
    msg ~= "\n\0";
    printf("%s",msg.ptr);
  }

  void func2()
  {
    auto error = ErrorScope(ErrorContext.create("func2","arg3"));
    func3();
  }

  void func1()
  {
    auto error = ErrorScope(ErrorContext.create("func1","arg1","arg2"));
    func2();
  }

  auto leak = LeakChecker("thBase.error unittest");
  {
    func1();
  }
}