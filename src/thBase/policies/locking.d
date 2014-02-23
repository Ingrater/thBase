module thBase.policies.locking;

import core.sync.mutex;
import thBase.types;
import core.allocator;

struct NoLockPolicy
{
  //@disable this(); //BUG
  this(PolicyInit init){}
  void lock(){}
  void unlock(){}
}

struct MutexLockPolicy
{
  private composite!Mutex m_mutex;
  //@disable this(); //BUG
  
  this(PolicyInit init)
  {
    m_mutex = typeof(m_mutex)(DefaultCtor());
  }

  void lock()
  {
    m_mutex.lock();
  }

  void unlock()
  {
    m_mutex.unlock();
  }
}