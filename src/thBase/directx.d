module thBase.directx;

void ReleaseAndNull(T)(ref T ptr)
{
  if(ptr !is null)
  {
    ptr.Release();
    ptr = null;
  }
}

struct ComRef(T)
{
  T m_ref;

  alias m_ref this;

  this(T ptr)
  {
    m_ref = ptr;
    if(m_ref !is null)
      m_ref.AddRef();
  }

  this(this)
  {
    if(m_ref !is null)
      m_ref.AddRef();
  }

  ~this()
  {
    if(m_ref !is null)
      m_ref.Release();
  }

  void opAssign(ref ComRef rh)
  {
    if(m_ref is rh.m_ref)
      return;
    if(m_ref !is null)
      m_ref.Release();
    m_ref = rh.m_ref;
    if(m_ref !is null)
      rh.AddRef();
  }

  void opAssign(ComRef rh)
  {
    if(m_ref !is null)
      m_ref.Release();
    m_ref = rh.m_ref;
    rh.m_ref = null;
  }

  void opAssign(typeof(null))
  {
    if(m_ref !is null)
    {
      m_ref.Release();
      m_ref = null;
    }
  }

  static assert(ComRef!T.sizeof == (void*).sizeof);
}

ComRef!T InitiallyUnowned(T)(T obj)
{
  ComRef!T result;
  result.m_ref = obj;
  return result;
}