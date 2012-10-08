module thBase.allocator;

import thBase.types;
import core.allocator;
import core.hashmap;
import thBase.traits;
import core.stdc.string;
import thBase.container.stack;
import thBase.container.vector;
import core.sync.mutex;
import thBase.policies.locking;
import thBase.format;

class AllocatorOutOfMemory : RCException
{
  public:
    IAllocator allocator;
    this(rcstring msg, IAllocator allocator)
    {
      this.allocator = allocator;
      super(msg);
    }
}

class FixedBlockAllocator(LockingPolicy) : IAllocator
{
  private: 
    void[] m_memoryBlock;
    bool m_bAllocated = false;
    LockingPolicy m_lock;

  public:

  this(void[] memoryBlock)
  {
    m_lock = LockingPolicy(PolicyInit.DEFAULT);
    m_memoryBlock = memoryBlock;
  }

  ~this()
  {
    assert(m_bAllocated == false, "memory is still allocated");
  }

  final void[] AllocateMemory(size_t size)
  {
    m_lock.Lock();
    scope(exit) m_lock.Unlock();
    assert(m_bAllocated == false, "memory block has already been allocated");
    assert(size <= m_memoryBlock.length, "to much memory requested");
    if(m_bAllocated || size > m_memoryBlock.length)
      return [];

    m_bAllocated = true;
    return m_memoryBlock.ptr[0..size];
  }

  final void FreeMemory(void* mem)
  {
    m_lock.Lock();
    scope(exit) m_lock.Unlock();
    assert(m_bAllocated == true && mem == m_memoryBlock.ptr, "memory block does not belong to this allocator");

    m_bAllocated = false;
  }
}

import core.stdc.stdio;

class FixedStackAllocator(LockingPolicy, Allocator) : IAllocator
{
  enum size_t alignment = size_t.sizeof;
  private:
    Allocator m_allocator;
    LockingPolicy m_lock;
    void[] m_memoryBlock;
    void* m_cur;
    void* m_last;
    size_t m_alignmentWasted; //wasted memory due to alignment

    debug {
      void* m_upperEnd;

      void PushBlockSize(size_t size)
      {
        m_upperEnd -= size_t.sizeof;
        size_t* dest = cast(size_t*)m_upperEnd;
        *dest = size;
      }

      thResult PopBlockSize(out size_t size)
      {
        if(m_upperEnd < m_memoryBlock.ptr + m_memoryBlock.length)
        {
          auto src = cast(size_t*)m_upperEnd;
          size = *src;
          m_upperEnd += size_t.sizeof;
          return thResult.SUCCESS;
        }
        return thResult.FAILURE;
      }
    }

  public:
    this(size_t stackSize, Allocator allocator)
    {
      m_allocator = allocator;
      m_lock = LockingPolicy(PolicyInit.DEFAULT);
      m_memoryBlock = m_allocator.AllocateMemory(stackSize);
      assert(m_memoryBlock.ptr !is null);
      m_cur = m_memoryBlock.ptr;
      debug {
        m_upperEnd = m_memoryBlock.ptr + m_memoryBlock.length;
      }
    }

    ~this()
    {
      assert(m_memoryBlock.ptr == m_cur, "some memory is still allocated");
      m_allocator.FreeMemory(m_memoryBlock.ptr);
    }

    final void[] AllocateMemory(size_t size)
    {
      m_lock.Lock();
      scope(exit) m_lock.Unlock();
      size_t padding = 0;
      size_t alignedSize = size;
      if(alignedSize % alignment != 0)
      {
        padding = alignment - (alignedSize % alignment);
        alignedSize += padding;
        m_alignmentWasted += padding;
        assert(alignedSize % alignment == 0);
      }
      debug
      {
        PushBlockSize(alignedSize);
        void* upperEnd = m_upperEnd;
      }
      else 
      {
        void* upperEnd = m_memoryBlock.ptr + m_memoryBlock.length;
      }
      if(m_cur + size > upperEnd)
      {
        debug {
          m_alignmentWasted -= padding;
          PopBlockSize(alignedSize);
          auto error = format("Out of memory %d requested %d left", alignedSize, upperEnd - m_cur);
          assert(0, error[]);
        }
        else
        {
          throw New!AllocatorOutOfMemory(format("Fixed stack allocator not enough space left requested: %d left: %d", alignedSize, upperEnd - m_cur), this);
        }
      }
      auto result = m_cur[0..size];

      m_cur += alignedSize;
      printf("allocate: %d overhead: %d ptr: %x\n", size, alignedSize - size, cast(size_t)result.ptr);
      return result;
    }

    final void FreeMemory(void* mem)
    {
      m_lock.Lock();
      scope(exit) m_lock.Unlock();

      debug {
        assert(mem >= m_memoryBlock.ptr && mem < m_upperEnd, "memory given is not from this allocator");
        size_t size;
        thResult result = PopBlockSize(size);
        if(result == thResult.FAILURE)
        {
          debug
            assert(0, "nothing left to free");
          else
            return;
        }

        //printf("free %d %x\n", size, mem);

        if(m_cur - size != mem)
        {
          debug {
            assert(0, "trying to free out of order");
          }
          else
          {
            PushBlockSize(size);
            return;
          }
        }
      }

      m_cur = mem;
    }

    final bool CanFreeMemory(void* mem)
    {
      m_lock.Lock();
      scope(exit) m_lock.Unlock();
      debug {
        return mem >= m_memoryBlock.ptr && mem < m_upperEnd;
      }
      else
      {
        void* upperEnd = m_memoryBlock.ptr + m_memoryBlock.length;
        return mem >= m_memoryBlock.ptr && mem < upperEnd;
      }
    }

    final void FreeAllMemory()
    {
      m_lock.Lock();
      scope(exit) m_lock.Unlock();

      debug {
        m_upperEnd = m_memoryBlock.ptr + m_memoryBlock.length;
      }
      m_cur = m_memoryBlock.ptr;
    }
}

version(unittest)
{
  import thBase.devhelper;
}

unittest
{
  auto leak = LeakChecker("thBase.allocator unittest");
  {
    void[1024] mem = void;
    auto blockAlloc = New!(FixedBlockAllocator!(NoLockPolicy))(mem);
    auto stackAlloc = New!(FixedStackAllocator!(MutexLockPolicy, typeof(blockAlloc)))(mem.length, blockAlloc);
    scope(exit)
    {
      Delete(stackAlloc);
      Delete(blockAlloc);
    }
    
    void[] block1 = stackAlloc.AllocateMemory(24);
    assert(block1.ptr !is null);
    assert(cast(size_t)block1.ptr % stackAlloc.alignment == 0);
    assert(block1.length == 24);

    void[] block2 = stackAlloc.AllocateMemory(32);
    assert(block2.ptr !is null);
    assert(cast(size_t)block2.ptr % stackAlloc.alignment == 0);
    assert(block2.length == 32);

    void[] block3 = stackAlloc.AllocateMemory(18);
    assert(block3.ptr !is null);
    assert(cast(size_t)block3.ptr % stackAlloc.alignment == 0);
    assert(block3.length == 18);

    void[] block4 = stackAlloc.AllocateMemory(12);
    assert(block4.ptr !is null);
    assert(cast(size_t)block4.ptr % stackAlloc.alignment == 0);
    assert(block4.length == 12);

    assert(stackAlloc.CanFreeMemory(block4.ptr));
    stackAlloc.FreeMemory(block4.ptr);
    assert(stackAlloc.CanFreeMemory(block3.ptr));
    stackAlloc.FreeMemory(block3.ptr);
    assert(stackAlloc.CanFreeMemory(block2.ptr));
    stackAlloc.FreeMemory(block2.ptr);
    assert(stackAlloc.CanFreeMemory(block1.ptr));
    stackAlloc.FreeMemory(block1.ptr);
  }
}

class TemporaryAllocator(LockingPolicy, Allocator, size_t ALIGNMENT = size_t.sizeof) : IAllocator
{
  private:
  LockingPolicy m_lock;
  Allocator m_allocator;

  debug 
  {
    //Hashmap to track the allocations in debug build
    composite!(Hashmap!(void*, size_t, PointerHashPolicy, StdAllocator)) m_AllocatedMemory;
  }

  static struct BlockInfo
  {
    this(void[] mem, void* cur)
    {
      this.mem = mem;
      this.cur = cur;
    }
    void[] mem;
    void* cur;
  }

  BlockInfo[] m_blocks;
  size_t m_memBlockSize;
  enum uint INITAL_BLOCK_SIZE = 4;

  void[] DoAllocateMemory(size_t size)
  {
    if(size > m_memBlockSize)
    {
      debug {
        assert(0, "The temporary memory allocator can not serve memory requests that have a bigger size then its block size");
      }
      else
      {
       return [];
      }
    }
    //find a free block
    uint memoryBlockIndex = m_blocks.length; //block index that can serve the memory request
    bool allocate = false;
    size_t alignmentOffset = 0;

    for(uint i=0; i<m_blocks.length; i++)
    {
      alignmentOffset = 0;
      size_t spaceLeft = m_blocks[i].mem.ptr + m_blocks[i].mem.length - m_blocks[i].cur;
      if(spaceLeft > size || m_blocks[i].mem is null)
      {
        alignmentOffset = ALIGNMENT - (cast(size_t)m_blocks[i].cur % ALIGNMENT);
        if(alignmentOffset == ALIGNMENT)
          alignmentOffset = 0;

        if(spaceLeft > size + alignmentOffset || m_blocks[i].mem is null)
        {
          memoryBlockIndex = i;
          allocate = m_blocks[i].mem is null;
          break;
        }
      }
    }

    if(allocate || memoryBlockIndex >= m_blocks.length)
    {
      AllocateMemoryBlock(memoryBlockIndex);
    }

    void[] mem = (m_blocks[memoryBlockIndex].cur + alignmentOffset)[0..size];
    m_blocks[memoryBlockIndex].cur += size + alignmentOffset;

    assert(cast(size_t)mem.ptr % ALIGNMENT == 0, "missaligned memory");
    return mem;
  }

  void AllocateMemoryBlock(uint index)
  {
    uint numMemoryBlocks = 0;
    if(index >= m_blocks.length || m_blocks is null)
    {
      numMemoryBlocks = m_blocks.length * 2;
      if(numMemoryBlocks == 0)
        numMemoryBlocks = INITAL_BLOCK_SIZE;
      assert(index < numMemoryBlocks);
    }
    void[] initialMem = m_allocator.AllocateMemory(m_memBlockSize);
    assert(m_memBlockSize > numMemoryBlocks * BlockInfo.sizeof, "out of memory");
    uint dataSize = m_memBlockSize - numMemoryBlocks * BlockInfo.sizeof;
    assert(initialMem.ptr !is null, "couldn't allocate more memory");

    //Do we need to allocate a new block array?
    if(numMemoryBlocks > m_blocks.length)
    {
      memset(initialMem.ptr + dataSize, 0, BlockInfo.sizeof * numMemoryBlocks);
      auto blocks = (cast(BlockInfo*)(initialMem.ptr + dataSize))[0..numMemoryBlocks];

      //do we need to copy over the contents of the old block array?
      if(m_blocks.length > 0)
      {
        memcpy(blocks.ptr, m_blocks.ptr, (arrayType!(typeof(blocks))).sizeof * m_blocks.length);
      }

      m_blocks = blocks;
    }

    m_blocks[index] = BlockInfo(initialMem[0..dataSize], initialMem.ptr );
         
    assert(m_blocks[index].mem.length == m_memBlockSize - BlockInfo.sizeof * numMemoryBlocks);
    assert(m_blocks[index].cur == m_blocks[index].mem.ptr);
  }

  public:

  this(size_t memBlockSize, Allocator allocator)
  {
    assert(memBlockSize >= 1024, "temp memory allocator with less then 1kb blocksize does not make much sense");
    assert(allocator !is null);
    m_lock = LockingPolicy(PolicyInit.DEFAULT);
    m_allocator = allocator;
    m_memBlockSize = memBlockSize;
    AllocateMemoryBlock(0);
    debug {
      m_AllocatedMemory = typeof(m_AllocatedMemory)(DefaultCtor());
      m_AllocatedMemory.construct!(StdAllocator)(StdAllocator.globalInstance);
    }
  }

  ~this()
  {
    debug {
      assert(m_AllocatedMemory.count == 0, "there is still memory allocated");
      m_AllocatedMemory.destruct();
    }
    FreePools();
  }

  private void FreePools()
  {
    void* lastBlock;
    foreach(ref block; m_blocks)
    {
      if(block.mem is null)
        break;
      if(block.mem.ptr + block.mem.length == m_blocks.ptr)
      {
        lastBlock = block.mem.ptr;
      }
      else
      {
        m_allocator.FreeMemory(block.mem.ptr);
      }
    }
    m_allocator.FreeMemory(lastBlock);
  }

  final void Reset()
  {
    debug {
      assert(m_AllocatedMemory.count == 0, "there is still memory allocated");
      m_AllocatedMemory.clear();
    }
    FreePools();
    m_blocks = [];
    AllocateMemoryBlock(0);
  }

  final void[] AllocateMemory(size_t size)
  {
    m_lock.Lock();
    scope(exit) m_lock.Unlock();

    auto result = DoAllocateMemory(size);
    debug {
      if(result !is null)
      {
        //BUG uses opIndex instead of opIndexAssign
        //m_AllocatedMemory[result.ptr] = result.length;
        m_AllocatedMemory.opIndexAssign(result.length, result.ptr);
      }
    }
    return result;
  }

  final void FreeMemory(void* mem)
  {
    m_lock.Lock();
    scope(exit) m_lock.Unlock();

    debug {
      assert(m_AllocatedMemory.exists(mem), "double or invalid free");
      m_AllocatedMemory.remove(mem);
    }
  }

  final bool CanFreeMemory(void* mem)
  {
    m_lock.Lock();
    scope(exit) m_lock.Unlock();

    foreach(ref block; m_blocks)
    {
      if(block.mem is null)
        return false;
      if(block.mem.ptr <= mem && block.cur > mem)
      {
        debug 
        {
          assert(m_AllocatedMemory.exists(mem), "pointer is not a pointer retunred by a AllocateMemory call");
        }
        return true;
      }
    }
    return false;
  }
}

unittest
{
  auto leak = LeakChecker("thBase.allocator unittest");
  {
    auto allocator = New!(TemporaryAllocator!(NoLockPolicy, StdAllocator))(1024, StdAllocator.globalInstance);
    scope(exit) Delete(allocator);
    void*[64] allocated;

    foreach(ref alloc; allocated)
    {
      auto mem = allocator.AllocateMemory(127);
      assert(mem.ptr !is null && mem.length == 127);
      memset(mem.ptr, 0xcd, mem.length);
      alloc = mem.ptr;
    }

    foreach(ref alloc; allocated)
    {
      assert(allocator.CanFreeMemory(alloc));
      allocator.FreeMemory(alloc);
    }

    allocator.Reset();

    foreach(ref alloc; allocated)
    {
      auto mem = allocator.AllocateMemory(127);
      assert(mem.ptr !is null && mem.length == 127);
      memset(mem.ptr, 0xcd, mem.length);
      alloc = mem.ptr;
    }

    foreach(ref alloc; allocated)
    {
      assert(allocator.CanFreeMemory(alloc));
      allocator.FreeMemory(alloc);
    }
  }
}

class ChunkAllocator(LockingPolicy, AT = StdAllocator) : IAllocator
{
  private:
    composite!(Stack!(void[], AT)) m_FreeChunks;
    composite!(Vector!(void[], AT)) m_Regions;
    LockingPolicy m_lock;
    debug
    {
      composite!(Hashmap!(void*, size_t, PointerHashPolicy, StdAllocator)) m_AllocatedMemory;
    }
    AT m_allocator;
    size_t m_numChunksPerRegion, m_chunkSize, m_alignment;

    void AllocateNewChunks()
    {
      void[] region = m_allocator.AllocateMemory(m_numChunksPerRegion * m_chunkSize + m_alignment);
      assert(region.ptr !is null, "Out of memory");
      void[] alignedRegion;
      if(m_alignment > 0)
      {
        size_t alignmentOffset = (cast(size_t)region.ptr % m_alignment == 0) ? 0 : m_alignment - (cast(size_t)region.ptr % m_alignment);
        alignedRegion = (region.ptr+alignmentOffset)[0..(m_numChunksPerRegion * m_chunkSize)];
      }
      else
        alignedRegion = region;
      for(void* cur = alignedRegion.ptr; cur < alignedRegion.ptr + alignedRegion.length; cur += m_chunkSize)
      {
        m_FreeChunks.push(cur[0..m_chunkSize]);
      }
      m_Regions.push_back(region);
    }
    
  public:
    this(size_t chunkSize, size_t numChunks, size_t alignment, AT allocator)
    {
      assert(chunkSize > 0);
      assert(numChunks > 0);
      assert(chunkSize % alignment == 0, "chunk size has to be a multiple of alignment");
      m_lock = LockingPolicy(PolicyInit.DEFAULT);
      m_chunkSize = chunkSize;
      m_numChunksPerRegion = numChunks;
      m_allocator = allocator;
      m_alignment = alignment;

      m_FreeChunks = typeof(m_FreeChunks)(DefaultCtor());
      m_FreeChunks.construct(numChunks, allocator);

      m_Regions = typeof(m_Regions)(DefaultCtor());
      m_Regions.construct(allocator);

      debug 
      {
        m_AllocatedMemory = typeof(m_AllocatedMemory)(DefaultCtor());
        m_AllocatedMemory.construct(StdAllocator.globalInstance);
      }
    }

    static if(is(typeof(AT.globalInstance)))
    {
      this(size_t chunkSize, size_t numChunks, size_t alignment = size_t.sizeof)
      {
        this(chunkSize, numChunks, alignment, AT.globalInstance);
      }
    }

    ~this()
    {
      debug
      {
       assert(m_AllocatedMemory.count == 0, "there is still memory allocated");
      }
      foreach(region; m_Regions[])
      {
        m_allocator.FreeMemory(region.ptr);
      }
    }

    final void[] AllocateMemory(size_t size)
    {
      m_lock.Lock();
      scope(exit) m_lock.Unlock();

      assert(size <= m_chunkSize, "a chunk allocator can not allocate memory blocks bigger then its chunk size");
      if(m_FreeChunks.empty)
      {
        AllocateNewChunks();
      }

      void[] mem = m_FreeChunks.pop();
      assert(mem.length == m_chunkSize);
      debug
      {
        m_AllocatedMemory.opIndexAssign(size, mem.ptr);
      }
      return mem[0..size];
    }

    final void FreeMemory(void* mem)
    {
      m_lock.Lock();
      scope(exit) m_lock.Unlock();

      debug
      {
        assert(m_AllocatedMemory.exists(mem), "double or invalid free");
        m_AllocatedMemory.remove(mem);
      }

      m_FreeChunks.push(mem[0..m_chunkSize]);
    }

    final bool CanFreeMemory(void* mem)
    {
      m_lock.Lock();
      scope(exit) m_lock.Unlock();

      foreach(ref region; m_Regions[])
      {
        if(region.ptr <= mem && region.ptr + region.length > mem)
        {
          debug {
            assert(m_AllocatedMemory.exists(mem), "pointer was not returned by a AllocateMemory call");
          }
          return true;
        }
      }
      return false;
    }

    @property final size_t memoryPoolSize()
    {
      return m_Regions.size() * m_chunkSize * m_numChunksPerRegion;
    }

    @property final size_t allocatedMemorySize()
    {
      return memoryPoolSize() - (m_FreeChunks.size() * m_chunkSize);
    }
}

unittest
{
  auto leak = LeakChecker("thBase.allocator.ChunkAllocator unittest");
  {
    auto allocator = New!(ChunkAllocator!(NoLockPolicy))(1024, 4);
    scope(exit) Delete(allocator);

    void*[9] allocated;
    foreach(size_t i, ref alloc; allocated)
    {
      void[] mem = allocator.AllocateMemory(512+i);
      assert(mem.ptr !is null && mem.length == 512+i);
      memset(mem.ptr, 0xcd, mem.length);
      alloc = mem.ptr;
    }

    assert(allocator.memoryPoolSize == 4 * 3 * 1024);
    assert(allocator.allocatedMemorySize == 9 * 1024);

    foreach(alloc; allocated)
    {
      assert(allocator.CanFreeMemory(alloc));
      allocator.FreeMemory(alloc);
    }

    assert(allocator.memoryPoolSize == 4 * 3 * 1024);
    assert(allocator.allocatedMemorySize == 0);

    for(int i=0; i<4; i++)
    {
      void[] mem = allocator.AllocateMemory(512+i);
      assert(mem.ptr !is null && mem.length == 512+i);
      memset(mem.ptr, 0xcd, mem.length);
      allocated[i] = mem.ptr;
    }

    assert(allocator.memoryPoolSize == 4 * 3 * 1024);
    assert(allocator.allocatedMemorySize == 4 * 1024);

    for(int i=0; i<4; i++)
    {
      assert(allocator.CanFreeMemory(allocated[i]));
      allocator.FreeMemory(allocated[i]);
    }

    assert(allocator.memoryPoolSize == 4 * 3 * 1024);
    assert(allocator.allocatedMemorySize == 0);
  }
}

class RedirectAllocator(SmallAllocator, BigAllocator, LockingPolicy) : IAllocator
{
  public:
    enum Delete
    {
      Small,
      Big,
      Both,
      None
    }

  private:
    size_t m_maxSize;
    SmallAllocator m_smallAllocator;
    BigAllocator m_bigAllocator;
    LockingPolicy m_lock;
    composite!(Hashmap!(void*, size_t, PointerHashPolicy, StdAllocator)) m_bigAllocations;
    Delete m_delete;
    
  public:
    this(size_t maxSize, SmallAllocator smallAllocator, BigAllocator bigAllocator, Delete del)
    {
      assert(maxSize > 0);
      m_lock = LockingPolicy(PolicyInit.DEFAULT);
      m_maxSize = maxSize;
      m_smallAllocator = smallAllocator;
      m_bigAllocator = bigAllocator;
      m_delete = del;

      m_bigAllocations = typeof(m_bigAllocations)(DefaultCtor());
      m_bigAllocations.construct(StdAllocator.globalInstance);
    }

    ~this()
    {
      if(m_delete == Delete.Small || m_delete == Delete.Both)
        core.allocator.Delete(m_smallAllocator);
      if(m_delete == Delete.Big || m_delete == Delete.Both)
        core.allocator.Delete(m_bigAllocator);
    }

    final void[] AllocateMemory(size_t size)
    {
      if(size > m_maxSize)
      {
        m_lock.Lock();
        scope(exit) m_lock.Unlock();

        void mem[] = m_bigAllocator.AllocateMemory(size);
        m_bigAllocations.opIndexAssign(size, mem.ptr);
        return mem;
      }
      return m_smallAllocator.AllocateMemory(size);
    }

    final void FreeMemory(void* mem)
    {
      m_lock.Lock();
      scope(exit) m_lock.Unlock();
      if(m_bigAllocations.exists(mem))
      {
        m_bigAllocations.remove(mem);
        m_bigAllocator.FreeMemory(mem);
      }
      else
      {
        m_smallAllocator.FreeMemory(mem);
      }
    }
}

unittest
{
  auto leak = LeakChecker("thBase.allocator.RedirectAllocator unittest");
  {
    alias RedirectAllocator!(ChunkAllocator!(NoLockPolicy), StdAllocator, NoLockPolicy) allocator_t;
    auto allocator = New!allocator_t
                         (1024, New!(ChunkAllocator!(NoLockPolicy))(1024,4), StdAllocator.globalInstance, allocator_t.Delete.Small);
    scope(exit) Delete(allocator);

    void*[4] allocated;
    size_t[4] sizes;
    sizes[0] = 512;
    sizes[1] = 1024;
    sizes[2] = 2048;
    sizes[3] = 3333;

    foreach(size_t i, ref alloc; allocated)
    {
      void[] mem = allocator.AllocateMemory(sizes[i]);
      assert(mem.ptr !is null && mem.length == sizes[i]);
      alloc = mem.ptr;
    }

    foreach(alloc; allocated)
    {
      allocator.FreeMemory(alloc);
    }
  }
}

class ThreadLocalChunkAllocator : IAllocator
{
  private:
    __gshared Mutex m_globalMutex;
    __gshared Vector!(ThreadLocalChunkAllocator) m_allocatorList;
    static ThreadLocalChunkAllocator m_threadLocalAllocator;

    composite!(ChunkAllocator!(MutexLockPolicy)) m_allocator;

  public:

    enum size_t GLOBAL_CHUNK_SIZE = 128 * 1024;
    enum size_t GLOBAL_CHUNK_COUNT = 16;
    enum size_t GLOBAL_ALIGNMENT = 16; //sufficient for both SSE and doubles

    this(size_t chunkSize, size_t numChunks, size_t alignment)
    {
      m_allocator = typeof(m_allocator)(DefaultCtor());
      m_allocator.construct(chunkSize, numChunks, alignment);
    }

    final void[] AllocateMemory(size_t size)
    {
      return m_allocator.AllocateMemory(size);
    }

    final void FreeMemory(void* mem)
    {
      if(m_allocator.CanFreeMemory(mem))
      {
        m_allocator.FreeMemory(mem);
      }
      else
      {
        synchronized(m_globalMutex)
        {
          bool freed = false;
          foreach(allocator; m_allocatorList[])
          {
            if(allocator.m_allocator.CanFreeMemory(mem))
            {
              allocator.FreeMemory(mem);
              freed = true;
              break;
            }
          }
          assert(freed, "couldn't free memory");
        }
      }
    }

    shared static this()
    {
      m_globalMutex = New!Mutex();
      m_allocatorList = New!(typeof(m_allocatorList))();
    }

    shared static ~this()
    {
      Delete(m_globalMutex);
      Delete(m_allocatorList);
    }

    static this()
    {
      synchronized(m_globalMutex)
      {
        m_threadLocalAllocator = New!(ThreadLocalChunkAllocator)(GLOBAL_CHUNK_SIZE, GLOBAL_CHUNK_COUNT, GLOBAL_ALIGNMENT);
        m_allocatorList.push_back(m_threadLocalAllocator);
      }
    }

    static ~this()
    {
      synchronized(m_globalMutex)
      {
        m_allocatorList.remove(m_threadLocalAllocator);
        Delete(m_threadLocalAllocator);
        m_threadLocalAllocator = null;
      }
    }

    @property static ThreadLocalChunkAllocator globalInstance()
    {
      return m_threadLocalAllocator;
    }
}

/**
 * Returns a new temporary allocator which should only be used in the thread it was created in
 * The returned allocator needs to be deleted if is not needed any more
 *
 * Big memory requests are handed to the standard allocator, small memory requests are done by a temporary allocator
 * The temporary allocator gets its memory from a thread local chunk allocator which gets its memory from the standard allocator
 * That way temporary small allocations are blazingly fast. A allocation is small if it is smaller then ThreadLocalChunkAllocator.GLOBAL_CHUNK_SIZE
 **/
auto GetNewTemporaryAllocator()
{
  alias TemporaryAllocator!(NoLockPolicy, ThreadLocalChunkAllocator) TemporaryAllocator_t; 
  alias RedirectAllocator!(TemporaryAllocator_t, StdAllocator, NoLockPolicy) RedirectAllocator_t;
  auto temporaryAllocator = New!TemporaryAllocator_t(ThreadLocalChunkAllocator.GLOBAL_CHUNK_SIZE, ThreadLocalChunkAllocator.globalInstance);

  return New!RedirectAllocator_t
             (ThreadLocalChunkAllocator.GLOBAL_CHUNK_SIZE, 
              temporaryAllocator, StdAllocator.globalInstance, 
              RedirectAllocator_t.Delete.Small);
}

/**
 * A thread local fixed stack allocator
 * Memory needs to be freed in reverse order then it was allocated
 * Should be used to allocate big amounts of temporary data that otherwise would be declared on the stack
 */
class ThreadLocalStackAllocator : IAllocator
{
  private:
  __gshared Mutex m_globalMutex;
  __gshared Vector!(ThreadLocalStackAllocator) m_allocatorList;

  static ThreadLocalStackAllocator m_threadLocalAllocator;

  FixedStackAllocator!(MutexLockPolicy, StdAllocator) m_allocator;

  public:

  enum size_t THREAD_LOCAL_STACK_SIZE = 1024 * 1024 * 10; //10mb

  this()
  {
    m_allocator = New!(typeof(m_allocator))(THREAD_LOCAL_STACK_SIZE, StdAllocator.globalInstance);
  }

  ~this()
  {
    Delete(m_allocator);
  }

  final void[] AllocateMemory(size_t size)
  {
    return m_allocator.AllocateMemory(size);
  }

  final void FreeMemory(void* mem)
  {
    if(m_allocator.CanFreeMemory(mem))
    {
      m_allocator.FreeMemory(mem);
    }
    else
    {
      synchronized(m_globalMutex)
      {
        bool freed = false;
        foreach(allocator; m_allocatorList[])
        {
          if(allocator.m_allocator.CanFreeMemory(mem))
          {
            allocator.FreeMemory(mem);
            freed = true;
            break;
          }
        }
        assert(freed, "couldn't free memory");
      }
    }
  }

  shared static this()
  {
    m_globalMutex = New!Mutex();
    m_allocatorList = New!(typeof(m_allocatorList))();
  }

  shared static ~this()
  {
    Delete(m_globalMutex);
    Delete(m_allocatorList);
  }

  static this()
  {
    m_threadLocalAllocator = New!ThreadLocalStackAllocator();
  }

  static ~this()
  {
    Delete(m_threadLocalAllocator);
  }

  @property static ThreadLocalStackAllocator globalInstance()
  {
    return m_threadLocalAllocator;
  }
}

unittest
{
  auto stackAlloc = ThreadLocalStackAllocator.globalInstance;

  void[] block1 = stackAlloc.AllocateMemory(24);
  assert(block1.ptr !is null);
  assert(block1.length == 24);

  void[] block2 = stackAlloc.AllocateMemory(32);
  assert(block2.ptr !is null);
  assert(block2.length == 32);

  void[] block3 = stackAlloc.AllocateMemory(18);
  assert(block3.ptr !is null);
  assert(block3.length == 18);

  void[] block4 = stackAlloc.AllocateMemory(12);
  assert(block4.ptr !is null);
  assert(block4.length == 12);

  stackAlloc.FreeMemory(block4.ptr);
  stackAlloc.FreeMemory(block3.ptr);
  stackAlloc.FreeMemory(block2.ptr);
  stackAlloc.FreeMemory(block1.ptr);
}