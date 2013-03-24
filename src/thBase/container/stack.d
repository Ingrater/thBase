module thBase.container.stack;

import core.stdc.stdlib;
import core.stdc.string;
import core.allocator;

/**
 * a basic stack implementation using amortized doubling
 */
final class Stack(T,AT = StdAllocator) {
private:
	T* memStart = null;
	T* memEnd = null;
	T* memCur = null;
  AT m_allocator;
		
	void Init(size_t size){
		memStart = AllocatorNewArray!(T,AT)(m_allocator, size, InitializeMemoryWith.NOTHING).ptr;
    assert(memStart !is null);
		memCur = memStart;
		memEnd = memStart + size;
	}  
	
public:
	
	this(AT allocator){
    m_allocator = allocator;
	}

  /**
   * copy constructor
   */
  this(typeof(this) rh)
  {
    m_allocator = rh.m_allocator;
    Init(rh.memEnd - rh.memStart);
    ptrdiff_t rhSize = rh.memCur - rh.memStart;
    assert(rhSize >= 0);
    if(rhSize > 0)
    {
      uninitializedCopy(memStart[0..rhSize], rh.memStart[0..rhSize]);
    }
    memCur = memStart + rhSize;
  }

  static if(is(typeof(AT.globalInstance)))
  {
    this()
    {
      this(AT.globalInstance);
    }
  }
	
  static if(is(typeof(AT.globalInstance)))
  {
	  /**
	   * constructor
	   * Params:
	   *  startSize = the starting size for the stack 
	   */
	  this(size_t startSize){
		  this(startSize, AT.globalInstance);
	  }
  }

  /**
  * constructor
  * Params:
  *  startSize = the starting size for the stack 
  *  allocator = the allocator to use
  */
  this(size_t startSize, AT allocator)
  {
    m_allocator = allocator;
    Init(startSize);
  }

	~this(){
		if(memStart !is null){
      callDtor(memStart[0..(memCur-memStart)]); //destroy all currently active instances on the stack
			AllocatorFree(m_allocator, memStart[0..(memEnd-memStart)]); //free the memory
		}
	}

	/**
	 * pushes a element onto the stack
	 * Params:
	 *  value = the value to push
	 */
	void push(T value){
		if(memStart is null)
			Init(16);
		if(memCur == memEnd){
			size_t oldSize = (memEnd - memStart);
      size_t newSize = oldSize * 2;
      T* newMem = AllocatorNewArray!(T,AT)(m_allocator, newSize, InitializeMemoryWith.NOTHING).ptr;
      uninitializedMove(newMem[0..oldSize], memStart[0..oldSize]);
      AllocatorFree(m_allocator, memStart[0..oldSize]);
			memStart = newMem;
			memEnd = memStart + newSize;
			memCur = memStart + oldSize;
		}
		memcpy(memCur, &value, T.sizeof);
    callPostBlit(memCur);
		memCur++;
	}
	
	/**
	 * pops a element from the stack
	 * Returns: the element
	 */
	T pop(){
		memCur--;
    auto retVal = *memCur;
    static if(is(T == struct))
    {
      callDtor(memCur);
    }
    else
    {
      callDtor(*memCur);
    }
		return retVal;
	}
	
	/**
	 * gives acces to the currently element on the top of the stack
	 */
	ref T top(){
		assert(memCur > memStart,"stack is empty");
		return *(memCur-1);
	}
	
	/**
	 * Returns: true if the stack is empty, false otherwise
	 */
	bool empty(){
		return (memStart == memCur);
	}
	
	size_t size(){
		return (memCur - memStart);
	}
}

unittest {
	Stack!(int) s = New!(Stack!(int))();
  scope(exit) Delete(s);
	
	assert(s.empty() == true);
	s.push(5);
	assert(s.empty() == false);
	assert(s.pop() == 5);
	assert(s.empty() == true);
	s.push(3);
	s.push(4);
	s.push(7);
	assert(s.empty() == false);
	assert(s.pop() == 7);
	assert(s.pop() == 4);
	assert(s.pop() == 3);
	assert(s.empty() == true);
}
