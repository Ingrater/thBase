module thBase.container.octree;

import thBase.math3d.all;
import thBase.container.linkedlist;
import thBase.container.stack;
import thBase.container.vector;
import core.allocator;
import core.hashmap;
import thBase.policies.hashing;
import thBase.allocator;
import thBase.logging;
public import thBase.types;

/**
* Loose Octree 
* $(BR) child layout is:
* $(BR) 0 = (0,0,0)
* $(BR) 1 = (1,0,0)
* $(BR) 2 = (0,1,0)
* $(BR) 3 = (1,1,0)
* $(BR) 4 = (0,0,1)
* $(BR) 5 = (1,0,1)
* $(BR) 6 = (0,1,1)
* $(BR) 7 = (1,1,1)
*/
class LooseOctree(T, OctreePolicy, HashPolicy, TakeOwnership takeOwnership = TakeOwnership.yes, pos_t = vec3) {
public:	
  enum ExtendDirection : ubyte {
    NEGATIVE,
    POSITIVE
  }

	class Node {
  private:
    bool m_HasChilds = false;
    Node[8] m_Childs;
    Node[6] m_Neighbours;
    pos_t m_Center;
    float m_RealSize;
    AlignedBox_t!pos_t m_BoundingBox;
    DoubleLinkedList!(T) m_Objects;
    enum float SIZE_FACTOR = 2.0f;

  public:
    /**
    * default constructor
    * Params:
    *  center = the center of the node
    *  size = the size of the node
    */
    this(pos_t center, float size){
      m_Center = center;
      m_RealSize = size;
      //loose octree, this actually makes the bounding box twice as big to generate 
      //some overlapping areas
      float offset = size / 2.0f * SIZE_FACTOR;
      m_BoundingBox = AlignedBox_t!pos_t(m_Center - vec3(offset,offset,offset),
                                 m_Center + vec3(offset,offset,offset));
      m_Objects = New!(typeof(m_Objects))(StdAllocator.globalInstance);
    }

    /**
    * special constructor used to extend the overall size of the octree
    * Param:
    *  child = the current root node of the octree (now a child)
    *  extendDirection = false for positive extension, true for negative
    */
    this(Node child, ExtendDirection extendDirection){
      m_Objects = New!(typeof(m_Objects))(StdAllocator.globalInstance);
      m_HasChilds = true;
      m_RealSize = child.m_RealSize*2.0f;					   
      float shift = child.m_RealSize;
      pos_t center = child.m_Center;
      if(extendDirection == ExtendDirection.NEGATIVE)
        shift *= -1.0f;
      m_Center = child.m_Center + vec3(shift/2.0f,shift/2.0f,shift/2.0f);

      float newSize = m_RealSize / 2.0f * SIZE_FACTOR;
      m_BoundingBox = AlignedBox_t!pos_t(m_Center - vec3(newSize,newSize,newSize),
                                         m_Center + vec3(newSize,newSize,newSize));

      if(extendDirection == ExtendDirection.NEGATIVE){
        m_Childs[0] = new Node(center + vec3(shift,shift,shift),child.m_RealSize);
        m_Childs[1] = new Node(center + vec3( 0.0f,shift,shift),child.m_RealSize);
        m_Childs[2] = new Node(center + vec3(shift, 0.0f,shift),child.m_RealSize);
        m_Childs[3] = new Node(center + vec3( 0.0f, 0.0f,shift),child.m_RealSize);
        m_Childs[4] = new Node(center + vec3(shift,shift, 0.0f),child.m_RealSize);
        m_Childs[5] = new Node(center + vec3( 0.0f,shift, 0.0f),child.m_RealSize);
        m_Childs[6] = new Node(center + vec3(shift, 0.0f, 0.0f),child.m_RealSize);
        m_Childs[7] = child;
      }
      else {
        m_Childs[0] = child;
        m_Childs[1] = new Node(center + vec3(shift, 0.0f, 0.0f),child.m_RealSize);
        m_Childs[2] = new Node(center + vec3( 0.0f,shift, 0.0f),child.m_RealSize);
        m_Childs[3] = new Node(center + vec3(shift,shift, 0.0f),child.m_RealSize);
        m_Childs[4] = new Node(center + vec3( 0.0f, 0.0f,shift),child.m_RealSize);
        m_Childs[5] = new Node(center + vec3(shift, 0.0f,shift),child.m_RealSize);
        m_Childs[6] = new Node(center + vec3( 0.0f,shift,shift),child.m_RealSize);
        m_Childs[7] = new Node(center + vec3(shift,shift,shift),child.m_RealSize);
      }
    }

    ~this()
    {
      Delete(m_Objects);
      foreach(child; m_Childs)
      {
        Delete(child);
      }
    }

    ///subdivides this node
    void subdivide()
    in {
      assert(m_HasChilds == false);
      assert(m_Objects.size() >= 8);
    }
    out {
      assert(m_HasChilds == true);
      /*int sum = 0;
      foreach(ref child;m_Childs){
      assert(child !is null);
      sum += child.m_Objects.size();
      }
      assert(sum > 0);
      sum += m_Objects.size();
      assert(sum == 8);*/
    }
    body {
      //logInfo("subdividing");
      m_HasChilds = true;
      float shift = m_RealSize / 4.0f;
      float newsize = m_RealSize / 2.0f;
      m_Childs[0] = new Node(m_Center + vec3(-shift,-shift,-shift),newsize);
      m_Childs[1] = new Node(m_Center + vec3( shift,-shift,-shift),newsize);
      m_Childs[2] = new Node(m_Center + vec3(-shift, shift,-shift),newsize);
      m_Childs[3] = new Node(m_Center + vec3( shift, shift,-shift),newsize);
      m_Childs[4] = new Node(m_Center + vec3(-shift,-shift, shift),newsize);
      m_Childs[5] = new Node(m_Center + vec3( shift,-shift, shift),newsize);
      m_Childs[6] = new Node(m_Center + vec3(-shift, shift, shift),newsize);
      m_Childs[7] = new Node(m_Center + vec3( shift, shift, shift),newsize);

      auto r = m_Objects[];
      while(!r.empty){
        auto obj = r.front();
        bool moved = false;
        //Try to move the objects into the childs, if they fit
        auto box = OctreePolicy.getBoundingBox(obj);
        foreach(node;m_Childs){
          if(box in node.m_BoundingBox){
            node.m_Objects.moveHereBack(r);
            assert(node.m_Objects.back().front() is obj);
            changeObjectLocation(node,node.m_Objects.back());
            moved = true;
            break;
          }
        }
        //object did not fit into any of the childs
        if(!moved){
          //assert(0,"object was to big");
          r.popFront();
        }
      }

      foreach(child;m_Childs){
        if(!child.m_HasChilds && child.m_Objects.size() >= 8 && child.m_RealSize > m_MinSize){
          child.subdivide();
        }
      }
      //TODO notifiy neighbours about change
    }

    ///optimizes this node
    void optimize(){
      if(m_HasChilds){
        size_t numObjects = m_Objects.size();
        bool doOptimization = true;
        foreach(child;m_Childs){
          child.optimize();
          if(child.m_HasChilds)
            doOptimization = false;
          numObjects += child.m_Objects.size();
        }
        if(numObjects < 8 && doOptimization){
          foreach(child;m_Childs){
            //TODO notify neighbours
            for(auto r = child.m_Objects[];!r.empty();){
              m_Objects.moveHereBack(r);
              changeObjectLocation(this,m_Objects.back());
            }
            assert(child.m_Objects.empty());
            debug {
              //Check if there is still a refrence to this node in any of the ObjectInfo objects
              foreach(ref ObjectInfo info; m_ObjectInNode.values)
              {
                assert(info.node !is child);
              }
            }
            Delete(child);
          }
          m_Childs[0..8] = null;
          m_HasChilds = false;
        }
      }
    }

    /**
    * inserts a element into this node
    * Params:
    *  obj = the game object to insert
    * Returns: true if the insert was sucessfull, false otherwise
    */
    bool insert(T obj){
      auto box = OctreePolicy.getBoundingBox(obj);
      if(m_HasChilds){
        foreach(ref child;m_Childs){
          if(child.insert(obj))
            return true;
        }
      }
      if(box in m_BoundingBox){
        m_Objects.insertBack(obj);
        changeObjectLocation(this,m_Objects.back());
        if(!m_HasChilds && m_Objects.size() >= 8 && m_RealSize > m_MinSize){
          subdivide();
        }
        return true;
      }
      return false;
    }

    @property Node[] childs() 
    {
      if(m_HasChilds)
        return m_Childs[];
      return null;
    }

    @property auto objects()
    {
      return m_Objects[];
    }
	}

  static struct ObjectInfo {
    Node node;
    DoubleLinkedList!(T).Range at;

    this(Node node, DoubleLinkedList!(T).Range at){
      this.node = node;
      this.at = at;
    }
  }

	Node m_Root;	
  Hashmap!(T, ObjectInfo, HashPolicy) m_ObjectInNode;
	ExtendDirection m_ExtendDirection = ExtendDirection.NEGATIVE;
	float m_MinSize;

	void changeObjectLocation(Node node, DoubleLinkedList!(T).Range r){
		m_ObjectInNode[r.front()] = ObjectInfo(node,r);
	}

public:

	struct QueryRange {
  private:

    static struct NodeInfo {
      Node node;
      bool completelyIn;

      this(Node node, bool completelyIn){
        this.node = node;
        this.completelyIn = completelyIn;
      }
    }

    Stack!(NodeInfo) m_NodeList;
    AlignedBox_t!pos_t m_Box;
    T m_CurrentObject;
    Node m_CurrentNode;
    DoubleLinkedList!(T).Range m_CurPos;

    void add(NodeInfo info){
      bool completelyIn = info.completelyIn || (info.node.m_BoundingBox in m_Box);
      if(info.node.m_HasChilds){
        foreach(child;info.node.m_Childs){
          if(completelyIn || child.m_BoundingBox.intersects(m_Box))
            m_NodeList.push(NodeInfo(child,completelyIn));
        }
      }
      if(info.node.m_Objects.empty){
        if(m_NodeList.empty){
          m_CurrentNode = null;
          return;
        }
        add(m_NodeList.pop());
        return;
      }
      m_CurrentNode = info.node;
      m_CurPos = info.node.m_Objects[];
    }
  public:
    @disable this();

    this(LooseOctree tree, AlignedBox_t!pos_t box)
    {
      m_Box = box;
      m_NodeList = New!(Stack!(NodeInfo))(1024);
      if(tree.m_Root.m_BoundingBox.intersects(m_Box))
        m_NodeList.push( NodeInfo( tree.m_Root, (tree.m_Root.m_BoundingBox in m_Box) ) );
      popFront();
    }

    this(this)
    {
      m_NodeList = New!(Stack!(NodeInfo))(m_NodeList);
    }

    ~this()
    {
      Delete(m_NodeList);
    }

    @property bool empty(){
      return (m_CurrentObject is null);
    }

    @property T front(){
      return m_CurrentObject;
    }

    void popFront(){
      while(true){
        if(m_CurrentNode is null){
          while( !m_NodeList.empty && (m_CurrentNode is null) ){
            add(m_NodeList.pop());
          }
          if(m_NodeList.empty && m_CurrentNode is null){
            m_CurrentObject = null;
            return;
          }
          assert(!m_CurPos.empty());
        }

        while(!m_CurPos.empty()){
          auto cur = m_CurPos.front;
          auto objBox = OctreePolicy.getBoundingBox(cur);
          static if(is(typeof(objBox.isValid)))
          {
            assert(objBox.isValid());
          }
          if(objBox.intersects(m_Box)){
            m_CurrentObject = cur;
            m_CurPos.popFront();
            return;
          }
          m_CurPos.popFront();
        }
        if(m_CurPos.empty()){
          m_CurrentNode = null;
          m_CurrentObject = null;
        }
      }
    }
	}

	/**
  * constructor
  * Params:
  *  startSize = the start size of the octree
  *  minSize = the minimum size of a octree node
  */
	this(float startSize, float minSize){
		m_Root = new Node(pos_t(0,0,0), startSize);
		m_MinSize = minSize;
    m_ObjectInNode = New!(typeof(m_ObjectInNode))();
	}

  ~this()
  {
    deleteAllRemainingObjects();
    Delete(m_ObjectInNode);
    Delete(m_Root);
  }

  /**
  * deletes all objects remaining in the octree
  */
  void deleteAllRemainingObjects()
  {
    m_ObjectInNode.removeWhere((ref obj, ref info){
      info.node.m_Objects.removeSingle(info.at);
      static if(takeOwnership == TakeOwnership.yes)
        Delete(obj);
      return true;
    });
  }

	/**
  * inserts a object into the octree
  */
	void insert(T obj){
		//object is outside of our octree
		while( !(OctreePolicy.getBoundingBox(obj) in m_Root.m_BoundingBox) ){
			m_Root = new Node(m_Root,m_ExtendDirection);
      m_ExtendDirection = (m_ExtendDirection == ExtendDirection.NEGATIVE) ? ExtendDirection.POSITIVE : ExtendDirection.NEGATIVE;
		}
		m_Root.insert(obj);
	}

	/**
  * removes a object from the octree
  */
	bool remove(T obj){
		//if((obj in m_ObjectInNode) !is null){
    if(m_ObjectInNode.exists(obj)){
			auto info = m_ObjectInNode[obj];
			info.node.m_Objects.removeSingle(info.at);
      m_ObjectInNode.remove(obj);
      return true;
		}
    return false;
	}

	/**
  * updates the octree
  */
	void update(){
    T[] objs = AllocatorNewArray!T(ThreadLocalStackAllocator.globalInstance, m_ObjectInNode.count);
    scope(exit) AllocatorDelete(ThreadLocalStackAllocator.globalInstance, objs);

    size_t i=0;
    foreach(obj, ref info; m_ObjectInNode)
    {
      objs[i++] = obj;
    }

		foreach(obj; objs){
			if(OctreePolicy.hasMoved(obj)){
				auto info = m_ObjectInNode[obj];
				if(info.node.m_HasChilds || !(OctreePolicy.getBoundingBox(obj) in info.node.m_BoundingBox)){
					remove(obj);
					insert(obj);
				}
			}
		}
	}

	/**
  * optimizes the octree
  */
	void optimize(){
		m_Root.optimize();
	}

	/**
  * returns a range to iterate over all elements inside a aligend box
  */
	QueryRange getObjectsInBox(AlignedBox_t!pos_t box)
	in {
    static if(is(typeof(box.isValid)))
		  assert(box.isValid);
	}
	body {
		return QueryRange(this,box);
	}

	/**
  * Returns: an iterator to iterate over all objects in the tree
  */
	auto allObjects(){
		return m_ObjectInNode.keys;
	}

  /// number of objects in the tree
  @property auto count()
  {
    return m_ObjectInNode.count;
  }

  /// root node
  @property Node rootNode()
  {
    return m_Root;
  }
}

unittest {
	static class TestObject {
	private:
		vec3 m_position;
	public:
		this(vec3 position){
			m_position = position;
		}

		@property vec3 position() const {
			return m_position;
		}

		@property void position(vec3 position){
			m_position = position;
		}

		@property AlignedBoxLocal boundingBox() const {
			return AlignedBoxLocal(vec3(-5,-5,-5),vec3(5,5,5)) + m_position;
		}
	}

  static struct TestObjectOctreePolicy
  {
    static vec3 getPosition(TestObject obj)
    {
      return obj.position;
    }

    static AlignedBoxLocal getBoundingBox(TestObject obj)
    {
      return obj.boundingBox;
    }

    static bool hasMoved(TestObject obj)
    {
      return false;
    }
  }

	TestObject[8] objects;
	objects[0] = new TestObject(vec3(-500,-500,-500));
	objects[1] = new TestObject(vec3( 500,-500,-500));
	objects[2] = new TestObject(vec3( 500, 500,-500));
	objects[3] = new TestObject(vec3(-500, 500,-500));
	objects[4] = new TestObject(vec3(-500,-500, 500));
	objects[5] = new TestObject(vec3( 500,-500, 500));
	objects[6] = new TestObject(vec3( 500, 500, 500));
	objects[7] = new TestObject(vec3(-500, 500, 500));
  scope(exit)
  {
    foreach(obj; objects)
    {
      Delete(obj);
    }
  }

	auto oct = new LooseOctree!(TestObject, TestObjectOctreePolicy, ReferenceHashPolicy, TakeOwnership.no)(750.0f,100.0f);
  scope(exit) Delete(oct);
	auto oct2 = new LooseOctree!(TestObject, TestObjectOctreePolicy, ReferenceHashPolicy, TakeOwnership.no)(100.0f,50.0f);
  scope(exit) Delete(oct2);
	foreach(o;objects){
		oct.insert(o);
		oct2.insert(o);
	}

	assert(oct.m_Root.m_HasChilds == true);

	auto queryBox1 = AlignedBoxLocal(vec3(-500,-500,0),vec3(500,500,500));

	auto res1 = New!(Vector!TestObject)();
  scope(exit) Delete(res1);
	for(auto query = oct.getObjectsInBox(queryBox1);!query.empty();query.popFront()){
		res1 ~= query.front();
	}

	auto res2 = New!(Vector!TestObject)();
  scope(exit) Delete(res2);
	for(auto query = oct.getObjectsInBox(queryBox1);!query.empty();query.popFront()){
		res2 ~= query.front();
	}

	bool isIn(TestObject[] ar, TestObject obj){
		foreach(o;ar){
			if(o is obj)
				return true;
		}
		return false;
	}

	assert(res1.length == 4);
	assert(isIn(res1.toArray(), objects[4]));
	assert(isIn(res1.toArray(), objects[5]));
	assert(isIn(res1.toArray(), objects[6]));
	assert(isIn(res1.toArray(), objects[7]));

	assert(res2.length == 4);
	assert(isIn(res2.toArray(), objects[4]));
	assert(isIn(res2.toArray(), objects[5]));
	assert(isIn(res2.toArray(), objects[6]));
	assert(isIn(res2.toArray(), objects[7]));
}
