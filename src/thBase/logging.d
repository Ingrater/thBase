module thBase.logging;

import thBase.plugin;
import thBase.format;
import thBase.enumbitfield;
import thBase.container.vector;
import core.sync.mutex;

/**
 * the log level
 */
enum LogLevel
{
  Message    = 0x01, ///< any log output
  Info       = 0x02, ///< informational output
  Warning    = 0x04, ///< warning output
  Error      = 0x08, ///< continueable errors
  FatalError = 0x10  ///< non continueable errors
}

enum LogSubsystem
{
  Global = 1
}

alias void delegate(LogLevel level, ulong subsystem, scope string msg) LogHandler;
alias void function(LogLevel level, ulong subsystem, scope string msg) LogHandlerFunc;

version(Plugin)
{
  alias void function(LogLevel level, ulong subsystem, const(char)[] msg) ForwardToHandlersFunc;
}

version(Plugin) {}
else
{
  // List of handlers that process the log messages
  private __gshared Vector!(LogHandler) g_logHandlers;
  private __gshared Mutex g_mutex;
  private __gshared ulong logSubsystemFilter;
  private __gshared EnumBitfield!LogLevel logLevelFilter;

  private ulong g_currentSubsystem = LogSubsystem.Global; //TLS

  struct ScopedLogSubsystem
  {
    private ulong m_oldSubsystem;

    @disable this();

    this(ulong subsystem)
    {
      m_oldSubsystem = g_currentSubsystem;
      g_currentSubsystem = subsystem;
    }

    ~this()
    {
      g_currentSubsystem = m_oldSubsystem;
    }
  }
}

shared static this()
{
  version(Plugin)
  {
    ForwardToHandlers = cast(ForwardToHandlersFunc)g_pluginRegistry.GetValue("LogMessageForward");
  }
  else
  {
    g_mutex = New!Mutex();
    g_logHandlers = New!(typeof(g_logHandlers))();
    logLevelFilter.Add(LogLevel.Message, LogLevel.Info, LogLevel.Warning, LogLevel.Error, LogLevel.FatalError);
    g_pluginRegistry.AddValue("LogMessageForward", cast(void*)&ForwardToHandlers);
  }
}

shared static ~this()
{
  version(Plugin){}
  else 
  {
    Delete(g_logHandlers);
    Delete(g_mutex);
  }
}


version(Plugin) {}
else
{
  /**
   * Registers a new handler for log output
   * Params:
   *  logHandler = the function that will handle log output
   */
  public void RegisterLogHandler(LogHandler logHandler){
	  g_mutex.lock();
    scope(exit) g_mutex.unlock();
    g_logHandlers ~= (logHandler);
  }

  /// ditto
  public void RegisterLogHandler(LogHandlerFunc logHandler){
	  LogHandler logHandlerDg;
	  logHandlerDg.funcptr = logHandler;
	  g_mutex.lock();
    scope(exit) g_mutex.unlock();
    g_logHandlers ~= (logHandlerDg);
  }

  /**
   * Removes a log handler
   * Params:
   *  logHandler = the log handler to remove
   */
  public void UnregisterLogHandler(LogHandler logHandler)
  {
    g_mutex.lock();
    scope(exit) g_mutex.unlock();
    g_logHandlers.remove(logHandler);
  }

  /// ditto
  public void UnregisterLogHandler(LogHandlerFunc logHandler){
	  LogHandler logHandlerDg;
	  logHandlerDg.funcptr = logHandler;
	  g_mutex.lock();
    g_mutex.unlock();
    g_logHandlers.remove(logHandlerDg);
  }
}

version(Plugin)
{
  __gshared ForwardToHandlersFunc ForwardToHandlers;
}
else
{
  private void ForwardToHandlers(LogLevel level, ulong subsystem, const(char)[] message)
  {
	  g_mutex.lock();
    scope(exit)g_mutex.unlock();
	  foreach(handler; g_logHandlers)
    {
		  handler(level, subsystem, cast(string)message);
    }
  }
}

private void log(LogLevel level, ulong subsystem, string fmt, TypeInfo[] arg_types, void* args){	
  char[2048] buf;
  char[] message;

  auto needed = formatDoStatic(buf, fmt, arg_types, args);
  if(needed > buf.length)
  {
    message = NewArray!char(needed);
    formatDoStatic(message, fmt, arg_types, args);
  }
  else
  {
    message = buf[0..needed];
  }
  scope(exit)
  {
    if(message.ptr != buf.ptr)
      Delete(message.ptr);
  }

  ForwardToHandlers(level, subsystem, message);
}

/**
 * logs a message
 */
void logMessage(string fmt, ...)
{
  if((g_currentSubsystem & logSubsystemFilter) && logLevelFilter.IsSet(LogLevel.Message))
  {
    log(LogLevel.Message, g_currentSubsystem, fmt, _arguments, _argptr);
  }
}

/**
 * logs a information
 */
void logInfo(string fmt, ...)
{
  if((g_currentSubsystem & logSubsystemFilter) && logLevelFilter.IsSet(LogLevel.Info))
  {
    log(LogLevel.Info, g_currentSubsystem, fmt, _arguments, _argptr);
  }
}

/**
 * logs a warning
 */
void logWarning(string fmt, ...)
{
  if((g_currentSubsystem & logSubsystemFilter) && logLevelFilter.IsSet(LogLevel.Warning))
  {
    log(LogLevel.Warning, g_currentSubsystem, fmt, _arguments, _argptr);
  }
}

/**
 * logs a error
 */
void logError(string fmt, ...)
{
  if((g_currentSubsystem & logSubsystemFilter) && logLevelFilter.IsSet(LogLevel.Error))
  {
    log(LogLevel.Error, g_currentSubsystem, fmt, _arguments, _argptr);
  }
}

/**
 * logs a fatal error
 */
void logFatalError(string fmt, ...)
{
  if((g_currentSubsystem & logSubsystemFilter) && logLevelFilter.IsSet(LogLevel.FatalError))
  {
    log(LogLevel.FatalError, g_currentSubsystem, fmt, _arguments, _argptr);
  }
}

/**
 * Returns: the prefix for the given loglevel
 */
string prefix(LogLevel level)
{
  final switch(level)
  {
    case LogLevel.Message:
      return "";
    case LogLevel.Info:
      return "Info: ";
    case LogLevel.Warning:
      return "Warning: ";
    case LogLevel.Error:
      return "Error: ";
      break;
    case LogLevel.FatalError:
      return "Fatal Error: ";
      break;
  }
}