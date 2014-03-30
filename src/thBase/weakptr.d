module thBase.weakptr;

import thBase.scoped;
import thBase.algorithm : swap;
import core.sync.mutex;
import thBase.casts;

private struct WeakRefIndex
{
  uint indexAndHash = 0xFF_FF_FF_FF;

  enum uint indexMask = 0xFF_FF_FF;

  uint index() const { return indexAndHash & indexMask; }
  void index(uint value) { indexAndHash = (indexAndHash & ~indexMask) | (value & indexMask); }

  uint hash() const { return (indexAndHash & ~indexMask) >> 24; }
  void hash(uint value) { indexAndHash = (indexAndHash & indexMask) | ((value & 0xFF) << 24); }

  void swap(ref WeakRefIndex rh)
  {
    thBase.algorithm.swap(this.indexAndHash, rh.indexAndHash);
  }

  static immutable(WeakRefIndex) invalidValue;
};

static assert(WeakRefIndex.sizeof == 4, "WeakRefIndex should be 4 bytes big");

unittest 
{
  WeakRefIndex t;
  assert(t.hash == 0xFF);
  assert(t.index == 0xFF_FF_FF);
  t.hash = 0;
  assert(t.hash == 0);
  assert(t.index == 0xFF_FF_FF);
  t.index = 0;
  assert(t.hash == 0);
  assert(t.index == 0);
  t.hash = 0xFF;
  assert(t.hash == 0xFF);
  assert(t.index == 0);
}

class WeakReferencedLocal(T)
{
  static assert(is(T == class), "can only weak reference classes");
protected:
  __gshared T[] s_weakTable;
  __gshared ubyte[] s_hashTable;
  __gshared uint s_weakTableSize;
  __gshared uint s_weakTableNumEntries;
  __gshared Mutex s_mutex;

  shared static this()
  {
    s_mutex = New!Mutex();
  }

  shared static ~this()
  {
    Delete(s_mutex);
  }
}

alias WeakReferencedExport = WeakReferencedLocal;

/// \brief base class for all weak referenced objects
class WeakReferenced(T, alias Base = WeakReferencedLocal) : Base!T
{
protected:
  WeakRefIndex m_weakRefIndex;

  shared static ~this()
  {
    Delete(s_hashTable);
    Delete(s_weakTable);
  }

  static WeakRefIndex findWeakRefIndex()
  {
    auto lock = ScopedLock!Mutex(s_mutex);
    if(s_weakTableNumEntries == s_weakTableSize)
    {
      uint newSize = (s_weakTableSize == 0) ? 4 : s_weakTableSize * 2;
      auto oldWeakTable = s_weakTable;
      auto oldHashTable = s_hashTable;
      s_weakTable = NewArray!T(newSize);
      s_hashTable = NewArray!ubyte(newSize);
      s_weakTable[0..s_weakTableSize] = oldWeakTable[];
      s_hashTable[0..s_weakTableSize] = oldHashTable[];
      Delete(oldWeakTable);
      Delete(oldHashTable);
      s_weakTableSize = newSize;
    }
    uint index = 0;
    for(; index < s_weakTableSize; index++)
    {
      if(s_weakTable[index] is null)
        break;
    }
    assert(index < s_weakTableSize, "table is full");
    assert(index <= 0x00FFFFFF, "index does not fit into 24 bits");
    WeakRefIndex result;
    s_weakTableNumEntries++;
    result.index = index;
    result.hash = ++s_hashTable[index];
    if(result.hash == 0xFF)
    {
      result.hash = 0;
      s_hashTable[index] = 0;
    }
    return result;
  }

public:
  this()
  {
    auto lock = ScopedLock!Mutex(s_mutex);
    m_weakRefIndex = findWeakRefIndex();
    s_weakTable[m_weakRefIndex.index] = static_cast!T(this);
  }

  ~this()
  {
    auto lock = ScopedLock!Mutex(s_mutex);
    s_weakTable[m_weakRefIndex.index] = null;
    s_weakTableNumEntries--;
  }

  /// \brief gets the weak ref index for debugging purposes
  uint getWeakRefIndex()
  {
    return m_weakRefIndex.index;
  }

  /// \brief swap all weak references of this and another weak referenced object
  void swapPlaces(WeakReferenced!(T, Base) other)
  {
    auto lock = ScopedLock!Mutex(s_mutex);
    swap(s_weakTable[m_weakRefIndex.index], s_weakTable[other.m_weakRefIndex.index]);
    swap(m_weakRefIndex, other.m_weakRefIndex);
  }
}

struct WeakPtr(T, alias ExportType = WeakReferencedLocal)
{
protected:
  WeakRefIndex m_weakRefIndex;
  debug
  {
    T m_pLastLookupResult;
    T[]* m_pTable;
    ubyte[]* m_pHashTable;
  }

public:
  /// \brief constructor from an object
  this(T ptr)
  {
    if(ptr !is null)
    {
      m_weakRefIndex = ptr.m_weakRefIndex;
    }

    debug
    {
      m_pLastLookupResult = ptr;
      m_pTable = &WeakReferenced!(T, ExportType).s_weakTable;
      m_pHashTable = &WeakReferenced!(T, ExportType).s_hashTable;
    }
  }

  /// \brief returns the pointer to the object, might be null
  inout(T) get() inout
  {
    // strip-start "WeakRefImpl"
    if(m_weakRefIndex == WeakRefIndex.invalidValue)
    {
      return null;
    }
    else 
    {
      auto lock = ScopedLock!Mutex(WeakReferenced!(T, ExportType).s_mutex);
      uint index = m_weakRefIndex.index;
      auto ptr = WeakReferenced!(T, ExportType).s_weakTable[index];
      if(ptr !is null && WeakReferenced!(T, ExportType).s_hashTable[index] == m_weakRefIndex.hash)
      {
        debug
        {
          (cast(WeakPtr!(T, ExportType))this).m_pLastLookupResult = ptr;
        }
        return cast(inout(T))ptr;
      }
      else
      {
        // the weakRef is invalid, so invalidate it
        (cast(WeakPtr!(T, ExportType))this).m_weakRefIndex = WeakRefIndex.invalidValue;
        debug
        {
          (cast(WeakPtr!(T, ExportType))this).m_pLastLookupResult = null;
        }
        return null;
      }
    }
  }

  ref WeakPtr!(T, ExportType) opAssign(T ptr)
  {
    if(ptr !is null)
    {
      m_weakRefIndex = ptr.m_weakRefIndex;
    }
    else
    {
      m_weakRefIndex = WeakRefIndex.invalidValue;
    }
    debug {
      m_pLastLookupResult = ptr;
    }
    return this;
  }

  /// creates a new weak reference
  void setWithNewIndex(T ptr) 
  { 
    auto lock = ScopedLock!Mutex(WeakReferenced!(T, ExportType).s_mutex);

    m_weakRefIndex = WeakReferenced!(T, ExportType).findWeakRefIndex();
    WeakReferenced!(T, ExportType).s_weakTable[m_weakRefIndex.index] = ptr;
    debug {
      m_pLastLookupResult = ptr;
    }
  }

  /// \brief invalidates a weak reference which was previously created with setWithNewIndex
  ///   and replaces it with the given object
  void invalidateAndReplace(T ptr)
  {
    auto lock = ScopedLock!Mutex(WeakReferenced!(T, ExportType).s_mutex);

    assert(ptr !is null);
    auto storedPtr = get();
    assert(storedPtr !is null, "reference is already invalid");
    WeakReferenced!(T, ExportType).s_weakTable[ptr.m_weakRefIndex.index] = null;
    ptr.m_weakRefIndex = m_weakRefIndex;
    WeakReferenced!(T, ExportType).s_weakTable[m_weakRefIndex.index] = ptr;
    debug
    {
      m_pLastLookupResult = ptr;
    }
  }

  /// \brief gets the weak ref index for debugging purposes
  uint getWeakRefIndex()
  {
    return m_weakRefIndex.index;
  }
}

unittest
{
  static class WeakRefTest : WeakReferenced!WeakRefTest
  {
  }

  WeakPtr!WeakRefTest ptr1 = New!WeakRefTest();
  WeakPtr!WeakRefTest ptr3;
  ptr3 = New!WeakRefTest();

  assert(ptr1.get() !is null);
  assert(ptr3.get() !is null);

  //test copy constructor
  void testCopy(WeakPtr!WeakRefTest ptr4)
  {
    assert(ptr4.get() is ptr1.get());
    assert(ptr4.get() !is null);
  }
  testCopy(ptr1);
  assert(ptr1.get() !is null);

  //test copy assignment
  WeakPtr!WeakRefTest ptr4;
  ptr4 = ptr1;
  assert(ptr1.get() is ptr4.get());

  // test assignment of null
  ptr1 = null;

  //test pointer invalidation
  Delete(ptr4.get());
  assert(ptr1.get() is null);
  assert(ptr1.get() is null);
  assert(ptr4.get() is null);
  assert(ptr3.get() !is null);

  //test destructor
  WeakPtr!WeakRefTest ptr2 = New!WeakRefTest();
  {
    auto ptr5 = ptr2;
    assert(ptr5.get() !is null);
  }
  assert(ptr2.get() !is null);

  //test pointer invalidation
  Delete(ptr2.get());
  assert(ptr1.get() is null);
  assert(ptr1.get() is null);
  assert(ptr4.get() is null);
  assert(ptr2.get() is null);
  assert(ptr3.get() !is null);

  Delete(ptr3.get());
  assert(ptr1.get() is null);
  assert(ptr1.get() is null);
  assert(ptr4.get() is null);
  assert(ptr2.get() is null);
  assert(ptr3.get() is null);
}

