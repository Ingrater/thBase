module thBase.singleton;

import core.allocator;
import core.sync.mutex;

class Singleton(T, Allocator = StdAllocator)
{
  static bool s_instanceCreated = false; // TLS
  __gshared T s_instance;
  __gshared Mutex s_instanceMutex;

  shared static this()
  {
    s_instanceMutex = New!Mutex();
  }

  shared static ~this()
  {
    Delete(s_instanceMutex);
  }

  static T instance()
  {
    if(s_instanceCreated)
      return s_instance;
    synchronized(s_instanceMutex)
    {
      if(s_instance is null)
      {
        s_instance = New!T();
      }
      s_instanceCreated = true;
    }
    return s_instance;
  }
}