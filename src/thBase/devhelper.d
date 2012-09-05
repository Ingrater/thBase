module thBase.devhelper;
import thBase.format;
import core.allocator;
import core.refcounted;

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