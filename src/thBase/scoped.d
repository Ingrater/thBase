module thBase.scoped;

struct ScopedLock(T)
{
  private T* m_obj;
  @disable this();

  this(ref T object)
  {
    m_obj = &object;
    m_obj.lock();
  }

  ~this()
  {
    assert(m_obj !is null);
    m_obj.unlock();
  }
}

struct NoArgs {};

/**
 * A scoped reference, deletes the reference upon leaving a scope
 */
struct scopedRef(T, Allocator = StdAllocator)
{
  static assert(is(T == class), "scoped ref can only deal with classes not with " ~ T.stringof);
  T m_ref;
  
  static if(!is(typeof(Allocator.globalInstance)))
  {
    private Allocator m_allocator;
  }

  alias m_ref this;

  @disable this();

  static if(is(typeof(Allocator.globalInstance)))
  {
    this(ARGS...)(ARGS args)
    {
      static if(ARGS.length == 1 && is(ARGS[0] == NoArgs))
        m_ref = new T();
      else
        m_ref = new T(args);
    }
  }
  else
  {
    /**
    * Constructor
    * Params:
    *  r = the reference
    *  allocator = the allocator
    */
    this(T r, Allocator allocator)
    {
      m_ref = r;
      m_allocator = allocator;
    }
  }

  ~this()
  {
    if(m_ref !is null)
    {
      static if(is(typeof(Allocator.globalInstance)))
        AllocatorDelete(Allocator.globalInstance, m_ref);
      else
        AllocatorDelete(m_allocator, m_ref);
    }
  }

  /**
   * Relases the internally held reference and returns it
   */
  T releaseRef() pure nothrow
  {
    T temp = m_ref;
    m_ref = null;
    return temp;
  }

  /**
   * swaps this scopedRef with another scopedRef
   */
  void swap(ref scopedRef!T rh) pure nothrow
  {
    auto temp = this.m_ref;
    this.m_ref = rh.m_ref;
    rh.m_ref = temp;
  }
}

version(unittest)
{
  import thBase.devhelper;
}

unittest
{
  auto leak = LeakChecker("thBase.scoped.scopedRef unittest");
  {
    auto ref1 = scopedRef!Object(NoArgs());
    auto ref2 = scopedRef!Object(NoArgs());
    Delete(ref2.releaseRef());
  }
}