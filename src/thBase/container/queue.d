module thBase.container.queue;

import thBase.container.vector;
import thBase.types;
import thBase.scoped;
import thBase.algorithm : move;

import core.sync.semaphore;
import core.sync.mutex;
import core.allocator;

/**
 * a queue that is threadsafe for a single reader and single writer scenario
 */
final class SingleReaderSingleWriterQueue(T, size_t size) {
private:
	Semaphore m_Lock;
	T[size] m_Data;
	size_t m_NextWrite;
	size_t m_NextRead;
	
public:
	this(){
		m_Lock = new Semaphore();
		m_NextWrite = 0;
		m_NextRead = 0;
	}

	void enqueue(T elem){
    assert(m_NextWrite != m_NextRead);
		m_Data[m_NextWrite] = elem;
		m_NextWrite = (m_NextWrite + 1) % size;
		m_Lock.notify();
	}
	
	bool dequeue(ref T elem){
		if(m_Lock.tryWait()){
			elem = m_Data[m_NextRead];
			m_NextRead = (m_NextRead + 1) % size;
			return true;
		}
		return false;
	}
}

/**
 * This is a thread safe ring buffer you can put in any data
 * It is garantued that it will never read from invalid memory, even if you put in one big block of memory
 * and then read it in multiple steps
 */
final class ThreadSafeRingBuffer(AT = StdAllocator) {
private:
  Mutex m_Lock;
  void* m_Data;
  void* m_DataEnd;
  void* m_NextRead;
  void* m_NextWrite;
  void* m_JumpAt;
  AT* m_allocator;

public:

  this(size_t size, AT* allocator)
  {
    m_allocator = allocator;
    m_Lock = AllocatorNew!Mutex(*m_allocator);
    m_Data = cast(void*)AllocatorNewArray!byte(*m_allocator, size, InitializeMemoryWith.NOTHING).ptr;
    m_NextWrite = m_Data;
    m_NextRead = m_Data;
    m_DataEnd = m_Data + size;
    m_JumpAt = m_DataEnd;
  }

  static if(is(typeof(AT.globalInstance)))
  {
    this(size_t size)
    {
      this(size, &AT.globalInstance);
    }
  }

  ~this()
  {
    AllocatorDelete(*m_allocator, m_Data);
    AllocatorDelete(*m_allocator, m_Lock);
  }

  void enqueue(T)(auto ref T elem)
  {
    synchronized(m_Lock)
    {
      if(m_DataEnd - m_NextWrite < T.sizeof)
      {
        assert(m_NextRead <= m_NextWrite || m_NextRead == m_Data, "overflow");
        m_JumpAt = m_NextWrite;
        m_NextWrite = m_Data;
      }
      assert(!(m_NextRead > m_NextWrite && m_NextWrite + T.sizeof >= m_NextRead), "overflow");
      T* mem = cast(T*)m_NextWrite;
      uninitializedCopy(*mem, elem);
      m_NextWrite += T.sizeof;
      if(m_NextWrite > m_JumpAt)
        m_JumpAt = m_NextWrite;
    }
  }

  void enqueue(T)(auto ref T elem) shared
  {
    (cast(ThreadSafeRingBuffer!AT)this).enqueue(elem);
  }

  T* tryGet(T)()
  {
    synchronized(m_Lock)
    {
      void* readAt = m_NextRead;

      if(readAt == m_NextWrite)
        return null;

      if(readAt + T.sizeof > m_JumpAt)
      {
        assert(m_NextWrite <= m_NextRead, "overflow");
        readAt = m_Data;
        if(readAt == m_NextWrite)
          return null;
      }

      return cast(T*)readAt;
    }
  }

  T* tryGet(T)() shared
  {
    return (cast(ThreadSafeRingBuffer!AT)this).tryGet!T();
  }

  void skip(T)()
  {
    synchronized(m_Lock)
    {
      callDtor(cast(T*)m_NextRead);
      skipHelper(T.sizeof);
    }
  }

  void skip(T)() shared
  {
    (cast(ThreadSafeRingBuffer!AT)this).skip!T();
  }

  private:

  void skipHelper(size_t numBytes)
  {
    if(m_NextRead + numBytes > m_JumpAt)
    {
      assert(m_NextWrite <= m_NextRead, "overflow");
      m_NextRead = m_Data;
    }
    assert(!(m_NextRead < m_NextWrite && m_NextRead + numBytes > m_NextWrite), "overflow");
    m_NextRead += numBytes;
  }
}

version(unittest)
{
  import thBase.devhelper;
  import thBase.ctfe;
}

unittest 
{

  enum TypeEnum : int
  {
    TYPE_INVALID = 0,
    TYPE1,
    TYPE2
  }

  static struct TypeStruct
  {
    @disable this();
    this(TypeEnum type)
    {
      this.type = type;
    }
    TypeEnum type;
  }

  static struct Type1
  {
    TypeStruct type;
    int data;

    this(int data)
    {
      type = TypeStruct(TypeEnum.TYPE1);
      this.data = data;
    }
  }

  static struct Type2
  {
    TypeStruct type;
    float data;

    this(float data)
    {
      type = TypeStruct(TypeEnum.TYPE2);
      this.data = data;
    }
  }

  static assert(TypeStruct.sizeof == 4, "TypeStruct.sizeof is " ~ toString(TypeStruct.sizeof));
  static assert(Type1.sizeof == 8, "Type1.sizeof is " ~ toString(Type1.sizeof));
  static assert(Type2.sizeof == 8, "Type2.sizeof is " ~ toString(Type2.sizeof));

  auto leak = LeakChecker("container.queue.ThreadSafeRingBuffer unittest");
  {
    auto ringBuffer = New!(ThreadSafeRingBuffer!StdAllocator)(28);
    scope(exit) Delete(ringBuffer);

    for(int i=0; i<2; i++) //the second run will produce a overflow
    {
      ringBuffer.enqueue(Type1(5+i));
      ringBuffer.enqueue(Type2(4.0f+cast(float)i));

      TypeStruct* type = ringBuffer.tryGet!TypeStruct();
      assert(type !is null);
      assert(type.type == TypeEnum.TYPE1);

      Type1* type1 = ringBuffer.tryGet!Type1();
      assert(type1 !is null);
      assert(type1.data == 5+i);

      ringBuffer.skip!Type1();

      type = ringBuffer.tryGet!TypeStruct();
      assert(type !is null);
      assert(type.type == TypeEnum.TYPE2);

      Type2* type2 = ringBuffer.tryGet!Type2();
      assert(type2 !is null);
      assert(type2.data == 4.0f+cast(float)i);

      ringBuffer.skip!Type2();

      type = ringBuffer.tryGet!TypeStruct(); //there should be nothing left
      assert(type is null);
    }
  }
}

class Queue(T, LockingPolicy = NoLockPolicy, Allocator = StdAllocator)
{
private:
  composite!(Vector!(T, Allocator)) m_data;
  LockingPolicy m_lock;

  size_t m_insertIndex = 0;
  size_t m_takeIndex = 0;

public:
  this()
  {
    m_lock = LockingPolicy(PolicyInit.DEFAULT);
    m_data = typeof(m_data)(DefaultCtor());
    m_data.resize(4);
  }

  /// \brief takes a element from the beginning of the queue
  T take()
  {
    auto slock = ScopedLock!LockingPolicy(m_lock);
    assert(count() > 0, "no more elements left in the queue");
    T result;
    swap(result, m_data[m_takeIndex]);
    m_takeIndex++;
    if(m_takeIndex == m_data.length)
    {
      if(m_takeIndex == m_insertIndex)
        m_insertIndex = 0;
      m_takeIndex = 0;
    }
    return result;
  }

  /// \brief appends a new element at the end of the queue
  void append(T val)
  {
    auto slock = ScopedLock!LockingPolicy(m_lock);
    if(m_takeIndex > m_insertIndex)
    {
      assert(m_takeIndex - m_insertIndex >= 1);
      if(m_takeIndex - m_insertIndex == 1)
      {
        m_data.insertAtIndex(m_insertIndex, move(val));
        m_insertIndex++;
        m_takeIndex++;
      }
      else
      {
        swap(m_data[m_insertIndex], val);
        m_insertIndex++; // no overflow possible
      }
    }
    else
    {
      if(m_insertIndex == m_data.length() - 1 && m_takeIndex == 0)
      {
        m_data.insertAtIndex(m_insertIndex, move(val));
        m_insertIndex++;
      }
      else
      {
        swap(m_data[m_insertIndex], val);
        m_insertIndex++;
        if(m_insertIndex == m_data.length)
          m_insertIndex = 0;
      }
    }
  }

  /// \brief returns the number of elements remaining in the queue
  size_t count()
  {
    auto slock = ScopedLock!LockingPolicy(m_lock);
    size_t insertIndex = m_insertIndex;
    if(insertIndex < m_takeIndex)
      insertIndex += m_data.length;
    assert(insertIndex >= m_takeIndex);
    return insertIndex - m_takeIndex;
  }

};