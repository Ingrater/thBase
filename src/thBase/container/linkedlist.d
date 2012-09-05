module thBase.container.linkedlist;

import core.allocator;

//Debugging version
//version = LINKED_LIST_CHECK;

class DoubleLinkedList(T, AT = StdAllocator) {
private:
	struct Element {
		T data;
		Element *next;
		Element *prev;
		
		this(T data, Element* next, Element *prev){
			this.data = data;
			this.next = next;
			this.prev = prev;
		}
	}
	
	Element *m_Head = null;
	Element *m_Tail = null;
	size_t m_Size = 0;
  AT m_allocator;

  version(LINKED_LIST_CHECK)
  {
    private static bool check(typeof(this) list, Element *el, bool checkNext = true)
    {
      if(el is null)
        return true;
      if(el.prev is null && list.m_Head != el)
        return false;
      else if(checkNext)
        check(list, el.prev, false);
      if(el.next is null && list.m_Tail != el)
        return false;
      else if(checkNext)
        check(list, el.next, false);
      return true;
    }
  }
	
public:
	
	static struct Range {
		DoubleLinkedList!(T,AT) _super;
		Element *current;
		
		this(DoubleLinkedList!(T,AT) _super, Element *current){
			this._super = _super;
			this.current = current;
		}
		
		@property bool empty(){
			return (this.current is null);
		}
		
		@property ref T front(){
			return current.data;
		}

    version(LINKED_LIST_CHECK)
    {
      @property bool valid()
      {
        return check(this._super, this.current);
      }
    }
		
		void popFront(){
      version(LINKED_LIST_CHECK) assert(check(this._super, this.current));
			current = current.next;
		}
	}



  this(AT allocator)
  {
    m_allocator = allocator;
  }

  static if(is(typeof(AT.globalInstance)))
  {
    this()
    {
      this(AT.globalInstance);
    }
  }
	
	~this(){
		clear();
	}
	
	void clear(){
		m_Size = 0;
		Element* cur = m_Head;
		while(cur !is null){
			Element* temp = cur;
			cur = cur.next;
			AllocatorDelete(m_allocator, temp);
		}
		m_Head = null;
		m_Tail = null;
	}
	
	void stableInsertBack(T value){
		Element *elem = AllocatorNew!(Element, AT)(m_allocator, value,null,m_Tail);
		if(empty()){
			m_Head = elem;
			m_Tail = elem;
		}
		else {
			m_Tail.next = elem;
			m_Tail = elem;
		}
    version(LINKED_LIST_CHECK) assert(check(this, elem));
		m_Size++;
	}
	alias stableInsertBack insertBack;
	
	void stableInsertFront(T value){
		Element *elem = AllocatorNew!(Element, AT)(m_allocator, value,m_Head,null);
		if(empty()){
			m_Head = elem;
			m_Tail = elem;
		}
		else {
			m_Head.prev = elem;
			m_Head = elem;
		}
    version(LINKED_LIST_CHECK) assert(check(this, elem));
		m_Size++;
	}
	alias stableInsertFront insertFront;
	
	@property bool empty(){
		return (m_Head is null);
	}
	
	size_t size(){
		return m_Size;
	}
	
	/**
	 * moves the element of a other double linked list to the end of this linked list
	 * $(BR) this calls r.popFront on the range!
	 */
	void moveHereBack(ref Range r)
	in {
		assert(r._super != this,"destination and target of the movement operation is the same");
    assert(r._super.m_allocator == this.m_allocator, "allocator does not match");
	}
	body {
		r._super.m_Size--;
		m_Size++;
		Element *current = r.current;
    debug {
      Element *prev = current.prev;
      Element *next = current.next;
    }
    r.popFront();
		if(current.prev is null){
			r._super.m_Head = current.next;
		}
		else {
			current.prev.next = current.next;
		}
		if(current.next is null){
			r._super.m_Tail = current.prev;
		}
		else {
			current.next.prev = current.prev;
		}
		if(empty()){
			this.m_Head = current;
			this.m_Tail = current;
			current.next = null;
			current.prev = null;
		}
		else {
			m_Tail.next = current;
			current.prev = m_Tail;
			current.next = null;
			m_Tail = current;
		}
    version(LINKED_LIST_CHECK) {
      assert(check(this, current));
      assert(check(r._super, prev));
      assert(check(r._super, next));
    }
	}
	
	Range opSlice(){
    version(LINKED_LIST_CHECK) assert(check(this, m_Head));
		return Range(this,m_Head);
	}

	/**
	 * removes the element that the range is pointing to
	 * $(BR) calls popFront on the range
	 */
	void removeSingle(ref Range r)
	in {
		assert(r._super == this);
	}
	body {
    if(r.empty)
      return;
		m_Size--;
		Element* current = r.current;
		r.popFront();
		if(m_Head == current)
			m_Head = current.next;
		else
			current.prev.next = current.next;
		if(m_Tail == current)
			m_Tail = current.prev;
		else
			current.next.prev = current.prev;
    version(LINKED_LIST_CHECK) assert(check(this, current.next));
    version(LINKED_LIST_CHECK) assert(check(this, current.prev));
		AllocatorDelete(m_allocator, current);
	}
	
	/**
	 * Returns: a range pointing at the currently last element
	 */
	Range back(){
    version(LINKED_LIST_CHECK) assert(check(this, m_Tail));
		return Range(this, m_Tail);
	}
}

unittest {
	auto list = New!(DoubleLinkedList!(int))(StdAllocator.globalInstance);
  scope(exit) Delete(list);
	for(int i=0;i<100;i++){
		list.insertBack(i);
		assert(list.size() == i+1);
	}
	assert(list.size() == 100);
	
	int j=0;
	foreach(e;list[]){
		assert(j == e);
		j++;
	}

	while(!list[].empty()){
    auto r = list[];
		list.removeSingle(r);
	}
	assert(list.size() == 0);
	
	list.insertBack(1);
	list.insertBack(2);
	
	auto list2 = New!(DoubleLinkedList!(int))(StdAllocator.globalInstance);
  scope(exit) Delete(list2);
	auto r = list[];
	list2.moveHereBack(r);
	assert(list.size() == 1);
	assert(list2.size() == 1);
	list2.moveHereBack(r);
	assert(r.empty());
	assert(list.size() == 0);
	assert(list2.size() == 2);
	assert(list.m_Head is null);
	assert(list.m_Tail is null);
	assert(list.empty());
	r = list2[];
	assert(r.front() == 1);
	r.popFront();
	assert(r.front() == 2);
}