module thBase.devhelper;
import thBase.format;
import thBase.stream;
import core.allocator;
import core.refcounted;
import core.sys.windows.stacktrace;
import core.atomic;

struct LeakChecker
{
  @disable this();

  StdAllocator.OnAllocateMemoryDelegate OldOnAllocateMemoryCallback;
  StdAllocator.OnFreeMemoryDelegate OldOnFreeMemoryCallback;
  StdAllocator.OnReallocateMemoryDelegate OldOnReallocateMemoryCallback;

  int m_iAllocCount = 0;
  int m_iFreeCount = 0;
  string description;
  string file;
  size_t line;

  this(string desc, string file = __FILE__, size_t line = __LINE__)
  {
    description = desc;
    this.file = file;
    this.line = line;
    OldOnAllocateMemoryCallback = StdAllocator.globalInstance.OnAllocateMemoryCallback;
    OldOnFreeMemoryCallback = StdAllocator.globalInstance.OnFreeMemoryCallback;
    OldOnReallocateMemoryCallback = StdAllocator.globalInstance.OnReallocateMemoryCallback;
    StdAllocator.globalInstance.OnAllocateMemoryCallback = &OnAllocateMemory;
    StdAllocator.globalInstance.OnFreeMemoryCallback = &OnFreeMemory;
    StdAllocator.globalInstance.OnReallocateMemoryCallback = &OnReallocateMemory;
  }

  ~this(){
    StdAllocator.globalInstance.OnAllocateMemoryCallback = OldOnAllocateMemoryCallback;
    StdAllocator.globalInstance.OnFreeMemoryCallback = OldOnFreeMemoryCallback;
    StdAllocator.globalInstance.OnReallocateMemoryCallback = OldOnReallocateMemoryCallback;
    if(m_iAllocCount > m_iFreeCount)
      throw New!RCException(format("%s did leak %d allocations. file: %s line: %d",description,m_iAllocCount - m_iFreeCount,file,line));
  }

  void* OnAllocateMemory(size_t size, size_t alignment)
  {
    m_iAllocCount++;
    if(OldOnAllocateMemoryCallback)
      return OldOnAllocateMemoryCallback(size,alignment);
    return null;
  }

  bool OnFreeMemory(void* ptr)
  {
    m_iFreeCount++;
    if(OldOnFreeMemoryCallback)
      return OldOnFreeMemoryCallback(ptr);
    return false;
  }

  void* OnReallocateMemory(void* ptr, size_t size)
  {
    m_iFreeCount++;
    m_iAllocCount++;
    if(OldOnReallocateMemoryCallback)
      return OldOnReallocateMemoryCallback(ptr,size);
    return null;
  }
}

version(GNU) //TODO find bug in gnu compiler
{}
else
{
unittest {
  try
  {
    auto outerleak = LeakChecker("leak checker unittest outer");
    {
      void* mem = null;
      try
      {
        auto leak = LeakChecker("leak checker unittest");
        mem = StdAllocator.globalInstance.AllocateMemory(64).ptr;
      }
      catch(Exception ex)
      {
        StdAllocator.globalInstance.FreeMemory(mem);
        mem = null;
        Delete(ex);
      }
      assert(mem is null,"leak detector did not throw exception");
    }
  }
  catch(Exception ex){
    Delete(ex);
    assert(0,"leak detector test did leak");
  }
}
}

class DebugRefCounted
{
private:
  shared(int) m_iRefCount = 0;
  IAllocator m_allocator;

  final void AddReference()
  {
    char[32] filename;
    auto len = formatStatic(filename, "%x.log", cast(void*)this);
    auto s = New!FileOutStream(filename[0..len], FileOutStream.Append.yes);
    scope(exit) Delete(s);
    atomicOp!"+="(m_iRefCount,1);
    s.format("--------------Adding reference %d----------------\n", m_iRefCount);
    ulong[20] addresses;
    rcstring[20] lines;
    auto addr = StackTrace.trace(addresses, 2);
    auto trace = StackTrace.resolve(addr, lines);
    foreach(t; trace)
    {
      s.format("%s\n", t[]);
    }
  }

  // RemoveRefernce needs to be private otherwise the invariant handler
  // gets called on a already destroyed and freed object
  final void RemoveReference()
  {
    char[32] filename;
    auto len = formatStatic(filename, "%x.log", cast(void*)this);
    auto s = New!FileOutStream(filename[0..len], FileOutStream.Append.yes);
    scope(exit) Delete(s);
    int result = atomicOp!"-="(m_iRefCount,1);
    s.format("--------------Removing reference %d----------------\n", m_iRefCount);
    ulong[20] addresses;
    rcstring[20] lines;
    auto addr = StackTrace.trace(addresses, 2);
    auto trace = StackTrace.resolve(addr, lines);
    foreach(t; trace)
    {
      s.format("%s\n", t[]);
    }
    assert(result >= 0,"ref count is invalid");
    if(result == 0)
    {
      this.Release(s);
    }
  }

protected:
  void Release(FileOutStream s)
  {
    s.format("------------------Deleted----------------------");
    assert(m_allocator !is null, "no allocator given during construction!");
    auto allocator = m_allocator;
    clear(this);
    allocator.FreeMemory(cast(void*)this);
  }

public:
  final void SetAllocator(IAllocator allocator)
  {
    m_allocator = allocator;
  }

  @property final int refcount()
  {
    return m_iRefCount;
  }
}

template DebugSmartPtrType(T : DebugSmartPtr!T)
{
  alias T DebugSmartPtrType;
}

struct DebugSmartPtr(T)
{
  static assert(is(T : DebugRefCounted),T.stringof ~ " is not a debug reference counted object");

  T ptr;
  alias ptr this;
  alias typeof(this) this_t;

  this(T obj)
  {
    ptr = obj;
    ptr.AddReference();
  }

  this(this)
  {
    if(ptr !is null)
      ptr.AddReference();
  }

  ~this()
  {
    if(ptr !is null)
      ptr.RemoveReference();
  }

  //ugly workaround
  private mixin template _workaround4424()
  {
    @disable void opAssign(typeof(this) );
  }
  mixin _workaround4424;

  //assignment to null
  void opAssign(U)(U obj) if(is(U == typeof(null)))
  {
    if(ptr !is null)
      ptr.RemoveReference();
    ptr = null;
  }

  //asignment from a normal reference
  void opAssign(U)(U obj) if(!is(U == typeof(null)) && (!is(U V : DebugSmartPtr!V) && (is(U == T) || is(U : T))))
  {
    if(ptr !is null)
      ptr.RemoveReference();
    ptr = obj;
    if(ptr !is null)
      ptr.AddReference();
  }

  //assignment from another smart ptr
  void opAssign(U)(auto ref U rh) if(is(U V : DebugSmartPtr!V) && is(DebugSmartPtrType!U : T))
  {
    if(ptr !is null)
      ptr.RemoveReference();
    ptr = rh.ptr;
    if(ptr !is null)
      ptr.AddReference();
  }
}