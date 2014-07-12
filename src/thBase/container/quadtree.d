module thBase.container.quadtree;

import thBase.container.vector;
import thBase.container.hashmap;
import thBase.container.stack;
import thBase.policies.hashing;
import thBase.math3d.all;

struct StdQuadTreePolicy
{
  static Rectangle getBounds(T)(T obj)
  {
    return obj.bounds;
  }
}


/// <summary>
/// manages all game objects, keeps them inside a quad tree
/// </summary>
class QuadTree(T, QuadTreePolicy = StdQuadTreePolicy, HP = StdHashPolicy)
{
private:
  alias QuadTree!(T, QuadTreePolicy, HP) tree_t;

  /// <summary>
  /// stores information about in which quad tree nodes a game object is contained
  /// </summary>
  static class ObjectInfo
  {
    public T obj;
    public Vector!QuadTreeNode isIn;

    /// Constructs a new ObjectInfo
    /// @param isIn Takes ownership of the given vector container
    this(T obj)
    {
      this.obj = obj;
      this.isIn = New!(typeof(isIn))();
    }

    ~this()
    {
      Delete(isIn);
    }

    public void moveFromTo(QuadTreeNode from, QuadTreeNode to){
      isIn.remove(from);
      isIn ~= to;
    }

    public void RemoveFrom(QuadTreeNode node)
    {
      isIn.remove(node);
    }
  }

  static class QuadTreeNode
  {
    Rectangle bounds;
    QuadTreeNode[] childs;
    composite!(Vector!T) objects;
    tree_t head;

    private this()
    {
      objects = typeof(objects)(defaultCtor);
    }

    ~this()
    {
      if(childs !is null)
      {
        foreach(child; childs)
          Delete(child);
        Delete(childs);
        childs = null;
      }
    }

    /// <summary>
    /// constructor
    /// </summary>
    /// <param name="pBounds">bounds of the node</param>
    /// <param name="pHead">reference to the game object manager</param>
    this(Rectangle bounds, typeof(head) head)
    {
      objects = typeof(objects)(defaultCtor);
      this.bounds = bounds;
      this.head = head;
    }

    /// <summary>
    /// subdivides this quad tree node
    /// </summary>
    void subdivide()
    {
      assert(childs is null, "already subdivided");
      childs = NewArray!QuadTreeNode(4);
      auto halfSize = bounds.size * 0.5f;

      auto pos = bounds.min;
      childs[0] = New!QuadTreeNode(Rectangle(pos, pos + halfSize), head);// Rectangle(bounds.min.x, bounds.max.y, bounds.width / 2, bounds.height / 2),head);
      
      pos = bounds.min + vec2(halfSize.x, 0.0f);
      childs[1] = New!QuadTreeNode(Rectangle(pos, pos + halfSize), head); //, Rectangle(bounds.min.x + bounds.width / 2, bounds.max.y,  bounds.width / 2, bounds.height / 2),head);
      
      pos = bounds.min + halfSize;
      childs[2] = New!QuadTreeNode(Rectangle(pos, pos + halfSize), head); //Rectangle(bounds.min.x + bounds.width / 2, bounds.max.y + bounds.height / 2, bounds.width / 2, bounds.height / 2), head);
      
      pos = bounds.min + vec2(0.0f, halfSize.y);
      childs[3] = New!QuadTreeNode(Rectangle(pos, pos + halfSize), head); //Rectangle(bounds.min.x, bounds.max.y + bounds.height / 2, bounds.width / 2, bounds.height / 2),head);

      //Remove links
      foreach (ref obj; objects)
      {
        if (head.m_objects.exists(obj))
        {
          head.m_objects[obj].isIn.remove(this);
        }
      }

      //Update links
      foreach(child; childs)
      {
        foreach(ref obj; objects)
        {
          if (child.bounds.intersects(QuadTreePolicy.getBounds(obj)))
          {
            child.objects ~= obj;
            if (head.m_objects.exists(obj))
            {
              head.m_objects[obj].isIn ~= child;
            }
          }
        }
      }

      //Clear childs
      objects.resize(0);

      version(assert)
      {
        foreach (info; head.m_objects.values)
        {
          foreach (node; info.isIn)
          {
            assert(node != this,"removing from object info list failed");
          }
        }
      }
    }

    public void optimize()
    {
      if (childs != null)
      {
        if (count() < 4)
        {
          foreach (child; childs)
          {
            child.optimize();
            foreach (ref obj; child.objects)
            {
              objects ~= obj;
              head.m_objects[obj].moveFromTo(child, this);
            }
            Delete(child);
          }
          Delete(childs);
          childs = null;
        }
        else
        {
          foreach (child; childs)
          {
            child.optimize();
          }
        }
      }
    }

    size_t count()
    {
      if (childs != null)
      {
        size_t sum = 0;
        foreach (child; childs)
        {
          sum += child.count;
        }
        return sum;
      }
      return objects.length;
    }

    bool contains(T pObj)
    {
      if (childs != null)
      {
        foreach (child; childs)
        {
          if (child.contains(pObj))
            return true;
        }
      }
      foreach(obj; objects)
      {
        if(obj is pObj)
          return true;
      }
      return false;
    }

    /*void Draw(List<VertexPositionColor> pPoints, List<short> pIndices)
    {
      short index = (short)pPoints.Count;
      pPoints.Add(new VertexPositionColor(new Vector3(bounds.Left,bounds.Top, 0.5f), Color.Red));
      pPoints.Add(new VertexPositionColor(new Vector3(bounds.Right, bounds.Top, 0.5f), Color.Red));
      pPoints.Add(new VertexPositionColor(new Vector3(bounds.Right, bounds.Bottom, 0.5f), Color.Red));
      pPoints.Add(new VertexPositionColor(new Vector3(bounds.Left, bounds.Bottom, 0.5f), Color.Red));

      pIndices.Add(index);
      pIndices.Add((short)(index + 1));

      pIndices.Add((short)(index + 1));
      pIndices.Add((short)(index + 2));

      pIndices.Add((short)(index + 2));
      pIndices.Add((short)(index + 3));

      pIndices.Add((short)(index + 3));
      pIndices.Add(index);

      if (childs != null)
      {
        for (int i = 0; i < 4; i++)
          childs[i].Draw(pPoints, pIndices);
      }
      else
      {
        foreach (T obj in objects)
        {
          index = (short)pPoints.Count;
          pPoints.Add(new VertexPositionColor(new Vector3(obj.collision.bounds.Left, obj.collision.bounds.Top, 0.5f), Color.Green));
          pPoints.Add(new VertexPositionColor(new Vector3(obj.collision.bounds.Right, obj.collision.bounds.Top, 0.5f), Color.Green));
          pPoints.Add(new VertexPositionColor(new Vector3(obj.collision.bounds.Right, obj.collision.bounds.Bottom, 0.5f), Color.Green));
          pPoints.Add(new VertexPositionColor(new Vector3(obj.collision.bounds.Left, obj.collision.bounds.Bottom, 0.5f), Color.Green));

          pIndices.Add(index);
          pIndices.Add((short)(index + 1));

          pIndices.Add((short)(index + 1));
          pIndices.Add((short)(index + 2));

          pIndices.Add((short)(index + 2));
          pIndices.Add((short)(index + 3));

          pIndices.Add((short)(index + 3));
          pIndices.Add(index);
        }
      }
    }*/
  }

  composite!(Hashmap!(T, ObjectInfo, HP)) m_objects;
  QuadTreeNode m_root;
  bool m_extensionSwitch = false;

public:
  this()
  {
    m_root = New!QuadTreeNode(Rectangle(vec2(-128, -128), vec2(128, 128)), this);
    m_objects = typeof(m_objects)(defaultCtor);
  }

  ~this()
  {
    Delete(m_root);
    foreach(k, v; m_objects)
    {
      Delete(v);
    }
  }

  /// <summary>
  /// helper to insert new game objects into the quad tree (recursion)
  /// </summary>
  /// <param name="obj">game object to insert</param>
  /// <param name="isIn">list quad tree nodes the object has be inserted in</param>
  /// <param name="node">the current node beeing porcessed</param>
  private void QuadTreeInsertHelper(T obj, Vector!QuadTreeNode isIn, QuadTreeNode node)
  {
    auto bounds = QuadTreePolicy.getBounds(obj);
    //Inside or on the bounds of the current Node
    if (node.bounds.intersects(bounds))
    {
      if (node.childs == null)
      {
        if (node.objects.length >= 4 && node.bounds.width > 8)
        {
          node.subdivide();
          QuadTreeInsertHelper(obj, isIn, node);
        }
        else if(!node.objects.contains!"is"(obj))
        {
          isIn~= node;
          node.objects ~= obj;
        }
      }
      else
      {
        assert(node.objects.length == 0, "Node with childs and objects");
        foreach (child; node.childs)
        {
          if (child.bounds.intersects(bounds))
          {
            QuadTreeInsertHelper(obj, isIn, child);
          }
        }
      }
    }
  }

  /// <summary>
  /// inserts a game object into the quad tree
  /// </summary>
  /// <param name="obj">the game object</param>
  /// <returns>list of all quad tree nodes the object was added to</returns>
  private void QuadTreeInsert(T obj, Vector!QuadTreeNode result)
  {
    auto objBounds = QuadTreePolicy.getBounds(obj);

    //Tree is not big enough
    while ((m_root.bounds.intersects(objBounds) && !m_root.bounds.contains(objBounds))
           || !m_root.bounds.contains(objBounds)) 
    {
      QuadTreeNode newRoot;
      //Extend to top left
      if (m_extensionSwitch)
      {
        newRoot = New!QuadTreeNode(Rectangle(m_root.bounds.min - m_root.bounds.size, m_root.bounds.max), this);
        /*newRoot = New!QuadTreeNode(Rectangle(m_root.bounds.x - m_root.bounds.width,
                                             m_root.bounds.y - m_root.bounds.height,
                                             m_root.bounds.width * 2,
                                             m_root.bounds.height * 2), this);*/
        newRoot.childs = NewArray!QuadTreeNode(4);

        newRoot.childs[0] = New!QuadTreeNode(Rectangle(newRoot.bounds.min, m_root.bounds.min), this);
        newRoot.childs[1] = New!QuadTreeNode(Rectangle(newRoot.bounds.min + vec2(m_root.bounds.width, 0.0f), m_root.bounds.min + vec2(m_root.bounds.width, 0.0f)), this);
        newRoot.childs[2] = m_root;
        newRoot.childs[3] = New!QuadTreeNode(Rectangle(newRoot.bounds.min + vec2(0.0f, m_root.bounds.height), m_root.bounds.min + vec2(0.0f, m_root.bounds.height)), this);

        /*newRoot.childs[0] = New!QuadTreeNode(Rectangle(newRoot.bounds.X,
                                                       newRoot.bounds.Y,
                                                       m_root.bounds.width,
                                                       m_root.bounds.height),this);
        newRoot.childs[1] = New!QuadTreeNode(Rectangle(newRoot.bounds.X + m_root.bounds.width,
                                                       newRoot.bounds.Y,
                                                       m_root.bounds.width,
                                                       m_root.bounds.height),this);
        newRoot.childs[2] = m_root;
        newRoot.childs[3] = New!QuadTreeNode(Rectangle(newRoot.bounds.X,
                                                       newRoot.bounds.Y + m_root.bounds.height,
                                                       m_root.bounds.width,
                                                       m_root.bounds.height),this);*/
      }
      else //Extend to bottom right
      {
        newRoot = New!QuadTreeNode(Rectangle(m_root.bounds.min, m_root.bounds.max + m_root.bounds.size), this);
        /*newRoot = New!QuadTreeNode(Rectangle(m_root.bounds.X,
                                             m_root.bounds.Y,
                                             m_root.bounds.width * 2,
                                             m_root.bounds.height * 2), this);*/
        newRoot.childs = NewArray!QuadTreeNode(4);

        newRoot.childs[0] = m_root;
        newRoot.childs[1] = New!QuadTreeNode(Rectangle(m_root.bounds.min + vec2(m_root.bounds.width, 0.0f), m_root.bounds.max + vec2(m_root.bounds.width, 0.0f)), this);
        newRoot.childs[2] = New!QuadTreeNode(Rectangle(m_root.bounds.min + m_root.bounds.size, m_root.bounds.max + m_root.bounds.size), this);
        newRoot.childs[3] = New!QuadTreeNode(Rectangle(m_root.bounds.min + vec2(0.0f, m_root.bounds.height), m_root.bounds.max + vec2(0.0f, m_root.bounds.height)), this);
        
        /*newRoot.childs[1] = New!QuadTreeNode(Rectangle(newRoot.bounds.X + m_root.bounds.width,
                                                       newRoot.bounds.Y,
                                                       m_root.bounds.width,
                                                       m_root.bounds.height), this);
        newRoot.childs[2] = New!QuadTreeNode(Rectangle(newRoot.bounds.X + m_root.bounds.width,
                                                       newRoot.bounds.Y + m_root.bounds.height,
                                                       m_root.bounds.width,
                                                       m_root.bounds.height), this);
        newRoot.childs[3] = New!QuadTreeNode(Rectangle(newRoot.bounds.X,
                                                       newRoot.bounds.Y + m_root.bounds.height,
                                                       m_root.bounds.width,
                                                       m_root.bounds.height), this);*/
      }
      m_extensionSwitch = !m_extensionSwitch;
      m_root = newRoot;
    }

    QuadTreeInsertHelper(obj, result, m_root);
  }

  void insert(T obj)
  {
    assert(!m_objects.exists(obj), "object already exists inside quad tree");
    auto info = New!ObjectInfo(obj);
    QuadTreeInsert(obj, info.isIn);
    m_objects[obj] = info;
  }

  /*public void Draw(List<VertexPositionColor> pPoints, List<short> pIndices)
  {
    m_root.Draw(pPoints, pIndices);
  }*/

  void objectHasMoved(T obj)
  {
    if (m_objects.exists(obj))
    {
      //Simple solution for now, removes the object from the tree and adds it back in
      ObjectInfo info = m_objects[obj];
      foreach (node; info.isIn)
      {
        node.objects.remove(obj);
      }
      assert(m_root.contains(obj) == false, "not removed completely");
      info.isIn.clear();
      QuadTreeInsert(obj, info.isIn);
    }
  }

  /// <summary>
  /// removes a game object from the quad tree, and the world
  /// </summary>
  /// <param name="obj">the game object</param>
  public void remove(T obj)
  {
    if (m_objects.exists(obj))
    {
      ObjectInfo info = m_objects[obj];
      foreach(node; info.isIn)
      {
        node.objects.remove(obj);
      }
      Delete(info);
      m_objects.remove(obj);
    }
  }

  static struct QuadTreeQueryRange
  {
  private:
    tree_t m_tree;
    Rectangle m_queryRect;
    Stack!QuadTreeNode m_remainingNodes;
    Hashmap!(T, void, ReferenceHashPolicy) m_alreadyFound; 
    T m_currentObject;
    QuadTreeNode m_currentNode;
    Vector!T.Range m_curPos;

    void add(QuadTreeNode node){
      bool completelyIn = (node.bounds in m_queryRect);
      foreach(child; node.childs){
        if(completelyIn || child.bounds.intersects(m_queryRect))
          m_remainingNodes.push(child);
      }
      if(node.objects.length == 0){
        if(m_remainingNodes.empty){
          m_currentNode = null;
          return;
        }
        add(m_remainingNodes.pop());
        return;
      }
      m_currentNode = node;
      m_curPos = node.objects.GetRange();
    }

  public:
    @disable this();
      
    this(tree_t tree, Rectangle queryRect)
    {
      m_tree = tree;
      m_queryRect = queryRect;
      m_remainingNodes = New!(Stack!QuadTreeNode)(1024);
      m_alreadyFound = New!(typeof(m_alreadyFound))();
      add(m_tree.m_root);
      popFront();
    }

    this(this)
    {
      m_remainingNodes = New!(Stack!QuadTreeNode)(m_remainingNodes);
    }

    ~this()
    {
      Delete(m_remainingNodes);
      Delete(m_alreadyFound);
    }

    @property bool empty()
    {
      return (m_currentObject is null);
    }

    @property T front()
    {
      return m_currentObject;
    }

    void popFront()
    {
      while(true){
        if(m_currentNode is null){
          while( !m_remainingNodes.empty && (m_currentNode is null) ){
            add(m_remainingNodes.pop());
          }
          if(m_remainingNodes.empty && m_currentNode is null){
            m_currentObject = null;
            return;
          }
          assert(!m_curPos.empty());
        }

        while(!m_curPos.empty()){
          auto cur = m_curPos.front;
          auto bounds = QuadTreePolicy.getBounds(cur);
          static if(is(typeof(bounds.isValid)))
          {
            assert(bounds.isValid());
          }
          if(bounds.intersects(m_queryRect) && !m_alreadyFound.exists(cur)){
            m_currentObject = cur;
            m_curPos.popFront();
            return;
          }
          m_curPos.popFront();
        }
        if(m_curPos.empty()){
          m_currentNode = null;
          m_currentObject = null;
        }
      }
    }
  }

  auto query(Rectangle queryRect)
  {
    return QuadTreeQueryRange(this, queryRect);
  }

  /// <summary>
  /// helper function to query all objects inside a rectangle
  /// </summary>
  /// <param name="node">current node beeing processed</param>
  /// <param name="pRect">the rectangle</param>
  /// <param name="isIn">list of all found objects</param>
  /*private void QueryObjectInsideRectHelper(QuadTreeNode node, Rectangle pRect, Vector!QuadTreeNode isIn){
    if (node.bounds.intersects(pRect))
    {
      if (node.childs != null)
      {
        foreach (QuadTreeNode node in node.childs)
        {
          QueryObjectInsideRectHelper(node, pRect, isIn);
        }
      }
      else
      {
        foreach (T obj in node.objects)
        {
          if (pRect.intersects(obj.collision.bounds) && !isIn.Contains(obj))
          {
            isIn.Add(obj);
          }
        }
      }
    }
  }

  /// <summary>
  /// queries all objects inside a certain rectangle
  /// </summary>
  /// <param name="pRect">the rectangle</param>
  /// <returns>a list of all game objects inside or on the bounds of this rectangle</returns>
  public List<T> queryObjectsInsideRect(Rectangle pRect){
    List<T> list = new List<T>();
    QueryObjectInsideRectHelper(m_root, pRect, list);
    return list;
  }*/

  public void optimize()
  {
    m_root.optimize();
  }

  public size_t count()
  {
    return m_root.count();
  }

  public void clear()
  {
    foreach (obj; m_objects.keys)
    {
      remove(obj);
    }
    m_objects.clear();
  }
}

unittest
{
  import std.random;
  import thBase.logging;
  import thBase.policies.hashing;
  import thBase.algorithm : swap;

  uint seed = 1;

  Random gen;
  gen.seed(seed);

  scope(failure) logMessage("Seed was %d", seed);

  uint numRects = uniform(0, 128, gen);
  uint numTestsPerRect = uniform(0, 64, gen);
  if(numTestsPerRect % 2 == 1)
    numTestsPerRect++;

  static class TestObject
  {
    Rectangle bounds;
    this(Rectangle bounds)
    {
      this.bounds = bounds;
    }
  }

  float testMin = uniform(-1000.0f, 1000.0f, gen);
  float testMax = uniform(-1000.0f, 1000.0f, gen);
  if(testMin > testMax)
    swap(testMin, testMax);

  Rectangle[] testAreas = NewArray!Rectangle(numRects);
  TestObject[] testObjects = NewArray!TestObject(numRects * numTestsPerRect);
  auto tree = New!(QuadTree!(TestObject, StdQuadTreePolicy, ReferenceHashPolicy))();
  bool[] found = NewArray!bool(numTestsPerRect);

  scope(exit)
  {
    Delete(testAreas);
    foreach(testObject; testObjects)
      Delete(testObject);
    Delete(testObjects);
    Delete(tree);
    Delete(found);
  }

  size_t nextTestObject = 0;
  foreach(ref area; testAreas)
  {
    auto areaMin = vec2(uniform(testMin, testMax), uniform(testMin, testMax));
    auto areaMax = vec2(uniform(testMin, testMax), uniform(testMin, testMax));
    area = Rectangle(minimum(areaMin, areaMax), maximum(areaMin, areaMax));

    // generate objects which are inside the test area
    for(uint i=0; i<numTestsPerRect/2; i++)
    {
      auto p1 = vec2(uniform(area.min.x, area.max.x, gen), uniform(area.min.y, area.max.y, gen));
      auto p2 = vec2(uniform(area.min.x, area.max.x, gen), uniform(area.min.y, area.max.y, gen));
      auto rect = Rectangle(minimum(p1, p2), maximum(p1, p2));
      assert(rect in area, "generated rectangle is not in test area");
      testObjects[nextTestObject] = New!TestObject(rect);
      tree.insert(testObjects[nextTestObject]);
      nextTestObject++;
    }

    // generate objects which intersect the test area
    for(uint i=0; i<numTestsPerRect/2; i++)
    {
      auto p1 = vec2(uniform(area.min.x, area.max.x, gen), uniform(area.min.y, area.max.y, gen));
      auto p2 = vec2(uniform(area.min.x - area.width, area.max.x + area.width), uniform(area.min.y - area.height, area.max.y + area.height));
      auto rect = Rectangle(minimum(p1, p2), maximum(p1, p2));
      assert(rect in area || rect.intersects(area), "generated rectangle is not intersecting");
      testObjects[nextTestObject] = New!TestObject(rect);
      tree.insert(testObjects[nextTestObject]);
      nextTestObject++;
    }
  }

  if(uniform(0, 2, gen) == 0)
  {
    tree.optimize();
  }

  foreach(size_t i, ref area; testAreas)
  {
    size_t offset = i * numTestsPerRect;
    found[] = false;
    foreach(obj; tree.query(area))
    {
      for(uint j=0; j<numTestsPerRect; j++)
      {
        if(testObjects[offset + j] is obj)
        {
          found[j] = true;
          break;
        }
      }
    }

    foreach(size_t k, b; found)
    {
      assert(b, "object not found");
    }
  }
}