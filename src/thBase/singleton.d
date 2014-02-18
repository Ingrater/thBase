module thBase.singleton;

import core.allocator;

class Singleton(T, Allocator = StdAllocator)
{
  static bool s_instanceCreated = false; // TLS
  __gshared T s_instance;

  static T instance()
  {
    if(s_instanceCreated)
      return s_instance;
    synchronized(this)
    {
      if(s_instance !is null)
      {
        s_instance = New!T();
      }
      s_instanceCreated = true;
    }
    return s_instance;
  }
}