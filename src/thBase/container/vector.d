module thBase.container.vector;

import thBase.metatools;
public import core.stdc.stdlib;
public import core.stdc.string;
import core.allocator;
import std.traits;
import thBase.traits;

/**
 * array with dynamic size
 */
final class Vector(T,AT = StdAllocator) {
private:
	T[] m_Data;
	size_t m_Size;
  AT m_allocator;

public:
	alias T data_t;
	
	struct Range {
		private T* frontPtr;
		private T* backPtr;
		
		ref T front(){
			return *frontPtr;
		}
		
		ref T back(){
			return *backPtr;
		}
		
		void popFront(){
			frontPtr++;
		}
		
		void popBack(){
			backPtr--;
		}
		
		bool empty(){
			return (frontPtr >= backPtr);
		}
	};
	
	struct ConstRange {
		private const(T)* frontPtr;
		private const(T)* backPtr;
		
		const(T) front(){
			return *frontPtr;
		}
		
		const(T) back(){
			return *backPtr;
		}
		
		void popFront(){
			frontPtr++;
		}
		
		void popBack(){
			backPtr--;
		}
		
		bool empty(){
			return (frontPtr >= backPtr);
		}
	};
	
	/**
	 * creates a empty vector
	 */
	this(AT allocator){
    m_allocator = allocator;
		m_Size = 0;
		size_t startSize = 2;
		size_t elementSize = T.sizeof;
		m_Data = AllocatorNewArray!(T,AT)(m_allocator, startSize, InitializeMemoryWith.NOTHING);
	}
	
	/**
	 * creates a vector with the given data
	 */
	this(T[] pData, AT allocator){
    m_allocator = allocator;
		m_Data = AllocatorNewArray!(T,AT)(m_allocator, pData.length, InitializeMemoryWith.NOTHING);
    uninitializedCopy(m_Data, pData);
		m_Size = m_Data.length;
	}

  static if(is(typeof(AT.globalInstance)))
  {
    this()
    {
      this(AT.globalInstance);
    }

    this(T[] pData)
    {
      this(pData, AT.globalInstance);
    }
  }
	
	~this(){
		if(m_Data.ptr !is null){
      callDtor(m_Data[0..m_Size]);
			m_allocator.FreeMemory(m_Data.ptr);
			m_Size = 0;
		}
	}
	
	/**
	 * reserves amount of data for later usage
	 * this does not change the vector size
	 */
	void reserve(size_t amount){
		if(amount < m_Size)
			resize(amount);
		else if(amount > m_Data.length){
      T[] newData = AllocatorNewArray!(T,AT)(m_allocator, amount, InitializeMemoryWith.NOTHING);
      uninitializedMove(newData[0..m_Data.length], m_Data);
      AllocatorFree(m_allocator, m_Data);
      m_Data = newData;
		}
	}
	
	/**
	 *  resizes the vector to the given size
	 */
	void resize(size_t size){
		if(size > m_Data.length){
			size_t newSize = m_Data.length * 2;
			while( size > newSize){
				newSize *= 2;
			}
			reserve(newSize);			
		}
		if(size > m_Size){
      static if(is(T == struct) || is(T == union))
        T initHelper;
		  for(T* cur = m_Data.ptr + m_Size; cur < m_Data.ptr + size; ++cur){
			  static if(is(T == struct) || is(T == union))
          memcpy(cur, &initHelper, T.sizeof);
        else
          *cur = T.init;
		  }		
		}
		m_Size = size;
	}
	
	/**
	 * returns the size of the vector
	 */
	@property size_t size() const {
		return m_Size;
	}
	alias size length;

  void push_back(U : T)(auto ref U element)
  {
    if(m_Data.length == m_Size)
    {
      reserve(m_Data.length * 2);
    }
    static if(is(T == struct))
    {
      memcpy(m_Data.ptr + m_Size, &element, T.sizeof);
      callPostBlit(&element);
    }
    else
      m_Data[m_Size] = element;
    m_Size++;
  }

	/**
  * adds multiple elements to the end of the vector
  */
	void push_back(U : T[])(U elements)
  {
		if(m_Size + elements.length > m_Data.length){
			size_t newSize = m_Data.length * 2;
			while(m_Size + elements.length > newSize){
				newSize *= 2;
			}
			reserve(newSize);
		}
    uninitializedCopy(m_Data[m_Size..(m_Size + elements.length)], elements);
		m_Size += elements.length;
	}
	
	void opOpAssign(string op, U : T)(U element) if(op == "~")
	{
		push_back(element);
	}
	
	// ~= 
	void opOpAssign(string op, U : T[])(U elements) if(op == "~")
	{
		push_back(elements);
	}

  // copyFrom
  void CopyFrom(Vector!T rh)
  {
    resize(0); //destroy all currently stored data
    size_t len = rh.length;
    reserve(len); // reserve enough space
    uninitializedCopy(m_Data[0..len], rh.m_Data[0..len]);
    m_Size = len;
  }

  static if(IsPOD!T)
  {
    void CopyFrom(const(Vector!T) rh)
    {
      resize(0); //destroy all currently stored data
      size_t len = rh.length;
      reserve(len); // reserve enough space
      uninitializedCopy(m_Data[0..len], rh.m_Data[0..len]);
      m_Size = len;
    }
  }
	
	/**
	 * indexes the vector
	 */
	ref T opIndex(size_t index)
	in {
		assert(index < m_Size);
	}
	body {
		return m_Data[index];
	}

	/**
	 * indexes the vector
	 */
	ref const(T) opIndex(size_t index) const 
	in {
		assert(index < m_Size);
	}
	body {
		return m_Data[index];
	}
	
	Range opSlice() {
		return GetRange();
	}
	
	ConstRange opSlice() const {
		return GetRange();
	}
	
	T[] opSlice(size_t start, size_t stop) {
		return m_Data[start..stop];
	}
	
	const(T[]) opSlice(size_t start, size_t stop) const {
		return m_Data[start..stop];
	}

  void opIndexAssign(U)(auto ref U value, size_t index) 
  {
    static assert(is(T == StripModifier!U));
    m_Data[index] = value;
  }
	
	void opSliceAssign(T[] array, size_t start, size_t stop)
	in {
		assert(array.length == stop - start);
    assert(start < m_Size && stop <= m_Size, "out of bounds access");
	}
	body
	{
    copy(m_Data[start..stop], array[0..$]);
	}
	
	int opApply(scope int delegate(ref T) dg){
		int result = 0;
		foreach(ref T element; m_Data[0..m_Size]){
			result = dg(element);
			if(result)
				break;
		}
		return result;
	}
	
	int opApply(scope int delegate(ref const(T)) dg) const {
	    int result = 0;
	    foreach(element; m_Data[0..m_Size]){
	    	result = dg(element);
	    	if(result)
	    		break;
	    }
	    return result;
	}
	
	int opApplyReverse(scope int delegate(ref T) dg){
		int result = 0;
		foreach_reverse(ref T element; m_Data[0..m_Size]){
			result = dg(element);
			if(result)
				break;
		}
		return result;		
	}
	
	int opApplyReverse(scope int delegate(ref const(T)) dg) const {
		int result = 0;
		foreach_reverse(element; m_Data[0..m_Size]){
			result = dg(element);
			if(result)
				break;
		}
		return result;		
	}
	
	/**
	 * gets a range to iterate with foreach
	 * foreach(e;vector.GetRange())...
	 */
	Range GetRange(){
		return Range(m_Data.ptr,m_Data.ptr+m_Size);
	}
	
	/// ditto
	ConstRange GetRange() const {
		return ConstRange(m_Data.ptr,m_Data.ptr+m_Size);
	}
	
	/**
	 * returns the data pointer of the vector
	 */
	T* ptr(){
		return m_Data.ptr;
	}
	
  T[] toArray() 
  {
    return m_Data[0..m_Size];
  }

	const(T)[] toArray() const {
		return m_Data[0..m_Size];
	}
	
	/**
	 * removes the given element from the vector if it exists in it
	 * this will only remove 1 instance of the object
	 * Params:
	 *  element = the element to remove (for classes the 'is' opreator is used for comparison)
	 * Returns: True if a element was removed, false otherwise
	 */
	bool remove(T element){
		size_t pos = m_Size;
		foreach(size_t i,el;m_Data[0..m_Size]){
			static if(isClass!(T) || isInterface!(T)){
				if(el is element){
					pos = i;
					break;
				}
			}
			else {
				if(el == element){
					pos = i;
					break;
				}
			}
		}
		if(pos < m_Size){
			removeAtIndex(pos);
      return true;
		}
		return false;
	}

  /**
   * removes the element at the given index without respecting the order of the elements O(1)
   * Params:
   *  index = the index where the element should be removed
   */
  void removeAtIndexUnordered(size_t index)
  {
    assert(index < m_Size, "out of bounds");
    callDtor(&m_Data[index]);
    m_Size--;
    if(index != m_Size)
    {
      //move the last element to the position of the destroyed element
      memcpy(m_Data.ptr + index, m_Data.ptr + m_Size, T.sizeof);
    }
  }

  /**
   * removes the element at the given index respecting the order of the elements O(N)
   * Params:
   *   index = the index of the element to remove
   */
  void removeAtIndex(size_t index)
  {
    for(size_t i=index;i<m_Size-1;i++){
      m_Data[i] = m_Data[i+1]; //TODO use memmove
    }
    m_Size--;
    callDtor(&m_Data[m_Size]);
  }

  void insertAtIndex(U)(size_t index, auto ref U value)
  {
    assert(index <= m_Size, "out of bounds access");
    resize(m_Size + 1);
    if(m_Size > 1)
    {
      for(size_t i = m_Size-1; i >= index; i--)
      {
        m_Data[i] = m_Data[i-1]; //TODO use memmove
      }
    }
    m_Data[index] = value;
  }
	
	void insertionSort(scope bool delegate(ref const(T) lh, ref const(T) rh) cmp){
		for(uint sortedSize = 1;sortedSize < m_Size;sortedSize++){
			T* cur = &m_Data[sortedSize];
			int insertPos = sortedSize-1;
			while(insertPos >= 0 && cmp(*cur,m_Data[insertPos])){
				insertPos--;
			}
			insertPos += 1;
			if(insertPos > sortedSize) //already in correct place
				break;
			
			T temp = *cur;
			for(size_t i=sortedSize;i>insertPos;i--){
				m_Data[i] = m_Data[i-1];
			}
			m_Data[insertPos] = temp;
		}
	}
}

version(unittest){
	import thBase.timer;
  import thBase.devhelper;
  import core.stdc.stdio;
}


unittest {
  auto leak = LeakChecker("container.vector unittest");
	{
	  auto vec1 = New!(Vector!(int))();
    scope(exit) Delete(vec1);

	  assert(vec1.size() == 0);
	  foreach(e;vec1.GetRange()){
		  assert(0,"this should never be executed");
	  }
  	
	  vec1.resize(2);
	  assert(vec1.size() == 2);
  	
	  vec1[0] = 1;
	  vec1[1] = 2;
	  assert(vec1[0] == 1);
	  assert(vec1[1] == 2);
  	
	  foreach(ref vec1.data_t element;vec1){
		  element = 3;
	  }
	  assert(vec1[0] == 3);
	  assert(vec1[1] == 3);
  	
	  foreach_reverse(ref vec1.data_t element; vec1){
		  element = 4;
	  }
	  assert(vec1[0] == 4);
	  assert(vec1[1] == 4);
  	
	  vec1.push_back(5);
	  assert(vec1.size() == 3);
	  assert(vec1[2] == 5);
  	
	  int i=0;
	  foreach(e;vec1.GetRange()){
		  assert(e == vec1[i]);
		  i++;
	  }
  	
	  int[] slice = vec1[0..2];
	  assert(slice.length == 2);
	  assert(slice[0] == 4);
	  assert(slice[1] == 4);
  	
	  /*int[] slice2 = vec1[];
	  assert(slice2.length == 3);
	  assert(slice2[0] == 4);
	  assert(slice2[1] == 4);
	  assert(slice2[2] == 5);*/
  	
    //implementation removed
	  /*vec1[0..3] = 6;
	  assert(vec1[0] == 6);
	  assert(vec1[1] == 6);
	  assert(vec1[2] == 6);	*/
  	
	  int[2] a; a[0] = 3; a[1] = 3;
	  vec1[0..2] = a;
	  assert(vec1[0] == 3);
	  assert(vec1[1] == 3);
	  assert(vec1[2] == 5);		
  	
	  int[] b = a;
	  vec1[1..3] = b;
	  assert(vec1[0] == 3);
	  assert(vec1[1] == 3);
	  assert(vec1[2] == 3);	
  	
	  a[0] = 2;
	  vec1.push_back(a[]);
	  assert(vec1.size() == 5);
	  assert(vec1[3] == 2);
	  assert(vec1[4] == 3);
  	
	  vec1.push_back(b);
	  assert(vec1.size() == 7);
	  assert(vec1[5] == 2);
	  assert(vec1[6] == 3);
  	
	  auto vec2 = New!(Vector!(int))(a);
    scope(exit) Delete(vec2);

	  assert(vec2.size() == 2);
	  assert(vec2[0] == 2);
	  assert(vec2[1] == 3);
  	
	  //Do speed test
	  auto vec3 = New!(Vector!(int))();
    scope(exit) Delete(vec3);

	  vec3.resize(10000);
  	
	  auto timer = new shared(Timer)();
    scope(exit) Delete(timer);
  	
	  double time1,time2;
  	
	  {
		  scope start = Zeitpunkt(timer);
		  i=0;
		  foreach(ref vec3.data_t e;vec3){
			  e = i++;
		  }
		  scope stop = Zeitpunkt(timer);
		  time1 = stop-start;
		  printf("Vector ref foreach %f\n",time1);
	  }
  	
	  {
		  scope start = Zeitpunkt(timer);
		  i=0;
		  foreach(vec3.data_t e;vec3){
			  i += e;
		  }
		  scope stop = Zeitpunkt(timer);
		  time2 = stop-start;
		  printf("Vector foreach %f => %d\n",time2,i);
	  }
  	
	  //Test if references are correctly been thrown away
  	
	  static class TestClass {
		  int a, b;
	  }
  	
	  static struct TestStruct {
		  TestClass m_Ref;
		  TestStruct* m_Ptr;
	  }
  	
	  auto vec4 = New!(Vector!TestClass)();
    scope(exit) Delete(vec4);

	  vec4.resize(2);
    auto instance = New!TestClass();
    scope(exit) Delete(instance);
	  vec4[1] = instance;
	  vec4.resize(1);
	  vec4.resize(2);
	  assert(vec4[1] is null, "Reference has not been reset for class type");
	  
    {
      vec4.resize(3);
	    vec4[0] = New!TestClass();
	    vec4[1] = New!TestClass();
	    vec4[2] = New!TestClass();
      scope(exit)
      {
        Delete(vec4[0]);
        Delete(vec4[1]);
        Delete(vec4[2]);
      }
    	
	    size_t index = 0;
	    foreach(c;vec4.GetRange()){
		    assert(c == vec4[index],"range is broken");
		    index++;
	    }
	    assert(index == vec4.length,"Range is broken");
    }
  	
	  TestStruct data;
	  auto vec5 = New!(Vector!(TestStruct))();
    scope(exit) Delete(vec5);

    {
	    vec5.resize(2);
	    vec5[1].m_Ref = instance;
	    vec5[1].m_Ptr = &data;
	    assert(vec5[1].m_Ptr == &data,"Index operator is not working with reference");
	    vec5.resize(1);
	    vec5.resize(2);
	    assert(vec5[1].m_Ref is null,"Reference has not been reset for struct type clearing reference");
	    assert(vec5[1].m_Ptr is null,"Reference has not been reset for struct type clearing pointer");
    }
  	
	  auto vec6 = New!(Vector!(TestStruct*))();
    scope(exit) Delete(vec6);
	  vec6.resize(2);
	  vec6[1] = &data;
	  assert(vec6[1] == &data,"Index operator is not working");
	  vec6.resize(1);
	  vec6.resize(2);
	  assert(vec6[1] is null,"Reference has not been reset for pointer type");
  	
	  struct TestStruct2 {
		  int wert1,wert2;
	  }
  	
	  auto vec7 = New!(Vector!(TestStruct2))();
    scope(exit) Delete(vec7);
	  vec7 ~= TestStruct2(1,2);
	  vec7 ~= TestStruct2(2,2);
	  vec7 ~= TestStruct2(3,2);
	  assert(vec7[0].wert1 == 1 && vec7[0].wert2 == 2,"index operator with structs not working");
	  assert(vec7[1].wert1 == 2 && vec7[1].wert2 == 2,"index operator with structs not working");
	  assert(vec7[2].wert1 == 3 && vec7[2].wert2 == 2,"index operator with structs not working");
  	
	  vec7[1].wert2 = 5;
	  assert(vec7[1].wert2 == 5,"access over index operator for structs not working");
  	
	  /*foreach(j,ref v;vec7[]){
		  assert(v.wert1 == j+1,"foreach with slice operator not working " ~ to!string(v.wert1));
		  v.wert2 = j;
	  }
  	
	  assert(vec7[0].wert2 == 0,"foreach access not working");
	  assert(vec7[1].wert2 == 1,"foreach access not working");
	  assert(vec7[2].wert2 == 2,"foreach access not working");*/
  	
  	{
      __gshared int[] unsortedData = [4,2,7,8,1,5];
      __gshared int[] lessThenSortedData = [1,2,4,5,7,8];
      __gshared int[] greaterThenSortedData = [8,7,5,4,2,1];
	    auto vec8 = new Vector!(int)(unsortedData);
      scope(exit) Delete(vec8);
	    vec8.insertionSort((ref const(int) x,ref const(int) y){return x < y;});
	    assert(vec8.toArray()[] == lessThenSortedData,"insertion sort < does not work");
	    vec8.insertionSort((ref const(int) x,ref const(int) y){return x > y;});
	    assert(vec8.toArray()[] == greaterThenSortedData,"insertion sort > does not work");
    }
  	
	  auto vec10 = New!(Vector!(int))();
    scope(exit) Delete(vec10);
	  vec10 ~= 1;
	  vec10 ~= 2;
	  vec10 ~= 3;
	  vec10 ~= 4;
	  vec10.remove(1);
	  assert(vec10[0] == 2);
	  assert(vec10[1] == 3);
	  assert(vec10[2] == 4);
  	
    {
	    auto tc1 = New!TestClass();
	    auto tc2 = New!TestClass();
	    auto tc3 = New!TestClass();
	    auto tc4 = New!TestClass();
	    auto vec9 = New!(Vector!(TestClass))();
      scope(exit)
      {
        Delete(tc1);
        Delete(tc2);
        Delete(tc3);
        Delete(tc4);
        Delete(vec9);
      }

	    vec9 ~= tc1;
	    vec9 ~= tc2;
	    vec9 ~= tc3;
	    vec9 ~= tc4;
	    vec9.remove(tc1);
	    assert(vec9[0] is tc2,"remove does not work with classes");
	    assert(vec9[1] is tc3,"remove does not work with classes");
	    assert(vec9[2] is tc4,"remove does not work with classes");
    }

    auto vec11 = New!(Vector!rcstring)();
    scope(exit) Delete(vec11);

    vec11.push_back(rcstring("one"));
    vec11.push_back(rcstring("two"));
    vec11.push_back(rcstring("three"));
    vec11.push_back(rcstring("four"));
  }
}
