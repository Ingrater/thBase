module thBase.policies.locking;

import core.sync.mutex;
import thBase.types;
import core.allocator;

struct NoLockPolicy
{
  //@disable this(); //BUG
  this(PolicyInit init){}
  void Lock(){}
  void Unlock(){}
}

struct MutexLockPolicy
{
  private Mutex m_mutex;
  //@disable this(); //BUG
  
  this(PolicyInit init)
  {
    m_mutex = New!Mutex();
  }

  ~this()
  {
    Delete(m_mutex);
  }

  void Lock()
  {
    m_mutex.lock();
  }

  void Unlock()
  {
    m_mutex.unlock();
  }
}