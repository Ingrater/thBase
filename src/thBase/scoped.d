module thBase.scoped;

/**
 * A scoped reference, deletes the reference upon leaving a scope
 */
struct scopedRef(T, Allocator = StdAllocator)
{
  static assert(is(T == class) || is(T == interface), "scoped ref can only deal with classes or pointers not with " ~ T.stringof);
  T m_ref;
  private Allocator m_allocator;

  alias m_ref this;

  @disable this();

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

  static if(is(typeof(Allocator.globalInstance)))
  {
    /**
    * Constructor
    * Params:
    *  r = the reference
    */
    this(T r)
    {
      this(r, Allocator.globalInstance);
    }
  }

  ~this()
  {
    if(m_ref !is null)
    {
      AllocatorDelete(m_allocator, m_ref);
    }
  }

  /**
   * Relases the internally held reference and returns it
   */
  T releaseRef()
  {
    T temp = m_ref;
    m_ref = null;
    return temp;
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
    auto ref1 = scopedRef!Object(New!Object());
    auto ref2 = scopedRef!Object(New!Object());
    Delete(ref2.releaseRef());
  }
}