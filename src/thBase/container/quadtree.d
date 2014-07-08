module thBase.container.quadtree;

import thBase.container.vector;
import thBase.container.hashmap;

/++
/// <summary>
/// manages all game objects, keeps them inside a quad tree
/// </summary>
class QuadTree(T, HP = StdHashPolicy)
{
private:
  /// <summary>
  /// stores information about in which quad tree nodes a game object is contained
  /// </summary>
  static class ObjectInfo
  {
    public T m_obj;
    public composite!(Vector!QuadTreeNode) m_isIn;

    this(T obj)
    {
      this.m_obj = obj;
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
    GameObjectManager head;

    /// <summary>
    /// constructor
    /// </summary>
    /// <param name="pBounds">bounds of the node</param>
    /// <param name="pHead">reference to the game object manager</param>
    this(Rectangle bounds, GameObjectManager head)
    {
      this.bounds = bounds;
      this.head = head;
    }

    /// <summary>
    /// subdivides this quad tree node
    /// </summary>
    void subdivide()
    {
      Debug.Assert(childs == null, "already subdivided");
      childs = New!QuadTreeNode[4];
      childs[0] = New!QuadTreeNode(Rectangle(bounds.min.x, bounds.max.y, bounds.width / 2, bounds.height / 2),head);
      childs[1] = New!QuadTreeNode(Rectangle(bounds.min.x + bounds.width / 2, bounds.max.y,  bounds.width / 2, bounds.height / 2),head);
      childs[2] = New!QuadTreeNode(Rectangle(bounds.min.x + bounds.width / 2, bounds.max.y + bounds.height / 2, bounds.width / 2, bounds.height / 2), head);
      childs[3] = New!QuadTreeNode(Rectangle(bounds.min.x, bounds.max.y + bounds.height / 2, bounds.width / 2, bounds.height / 2),head);

      //Remove links
      foreach (ref obj; objects)
      {
        if (head.m_objects.contains(obj))
        {
          head.m_objects[obj].isIn.remove(this);
        }
      }

      //Update links
      foreach(child; childs)
      {
        foreach(ref obj; objects)
        {
          auto pos = obj.position;
          if (child.bounds.Intersects(obj.bounds))
          {
            child.objects ~= obj;
            if (head.m_objects.contains(obj))
            {
              head.m_objects[obj].isIn ~= child;
            }
          }
        }
      }

      //Clear childs
      objects.clear();

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
          }
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
      return objects.count;
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
      return objects.contains(pObj);
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
        foreach (IGameObject obj in objects)
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
    }
  }*/

  composite!(Hashmap!(T, ObjectInfo, HP)) m_objects;
  QuadTreeNode m_root;
  bool m_extensionSwitch = false;

  this()
  {
    m_root = New!QuadTreeNode(Rectangle(vec2(-128, -128), vec2(128, 128)), this);
  }

  /// <summary>
  /// helper to insert new game objects into the quad tree (recursion)
  /// </summary>
  /// <param name="pGameObject">game object to insert</param>
  /// <param name="pList">list quad tree nodes the object has be inserted in</param>
  /// <param name="pNode">the current node beeing porcessed</param>
  private void QuadTreeInsertHelper(IGameObject pGameObject, List<QuadTreeNode> pList, QuadTreeNode pNode)
  {
    Vector2 pos = pGameObject.movement.position;
    //Inside or on the bounds of the current Node
    if (pNode.bounds.Intersects(pGameObject.collision.bounds))
    {
      if (pNode.childs == null)
      {
        if (pNode.objects.Count >= 4 && pNode.bounds.Width > 8)
        {
          pNode.Subdivide();
          QuadTreeInsertHelper(pGameObject, pList, pNode);
        }
        else if(!pNode.objects.Contains(pGameObject))
        {
          pList.Add(pNode);
          pNode.objects.Add(pGameObject);
        }
      }
      else
      {
        Debug.Assert(pNode.objects.Count == 0, "Node with childs and objects");
        foreach (QuadTreeNode child in pNode.childs)
        {
          if (child.bounds.Intersects(pGameObject.collision.bounds))
          {
            QuadTreeInsertHelper(pGameObject, pList, child);
          }
        }
      }
    }

  }

  /// <summary>
  /// inserts a game object into the quad tree
  /// </summary>
  /// <param name="pGameObject">the game object</param>
  /// <returns>list of all quad tree nodes the object was added to</returns>
  private List<QuadTreeNode> QuadTreeInsert(IGameObject pGameObject)
  {
    List<QuadTreeNode> result = new List<QuadTreeNode>();

    //Tree is not big enough
    while ((m_root.bounds.Intersects(pGameObject.collision.bounds) && !m_root.bounds.Contains(pGameObject.collision.bounds))
           || !m_root.bounds.Contains(pGameObject.collision.bounds)) 
    {
      QuadTreeNode newRoot;
      //Extend to top left
      if (m_extensionSwitch)
      {
        newRoot = new QuadTreeNode(new Rectangle(m_root.bounds.X - m_root.bounds.Width,
                                                 m_root.bounds.Y - m_root.bounds.Height,
                                                 m_root.bounds.Width * 2,
                                                 m_root.bounds.Height * 2), this);
        newRoot.childs = new QuadTreeNode[4];

        newRoot.childs[0] = new QuadTreeNode(new Rectangle(newRoot.bounds.X,
                                                           newRoot.bounds.Y,
                                                           m_root.bounds.Width,
                                                           m_root.bounds.Height),this);
        newRoot.childs[1] = new QuadTreeNode(new Rectangle(newRoot.bounds.X + m_root.bounds.Width,
                                                           newRoot.bounds.Y,
                                                           m_root.bounds.Width,
                                                           m_root.bounds.Height),this);
        newRoot.childs[2] = m_root;
        newRoot.childs[3] = new QuadTreeNode(new Rectangle(newRoot.bounds.X,
                                                           newRoot.bounds.Y + m_root.bounds.Height,
                                                           m_root.bounds.Width,
                                                           m_root.bounds.Height),this);
      }
      else //Extend to bottom right
      {
        newRoot = new QuadTreeNode(new Rectangle(m_root.bounds.X,
                                                 m_root.bounds.Y,
                                                 m_root.bounds.Width * 2,
                                                 m_root.bounds.Height * 2), this);
        newRoot.childs = new QuadTreeNode[4];

        newRoot.childs[0] = m_root;
        newRoot.childs[1] = new QuadTreeNode(new Rectangle(newRoot.bounds.X + m_root.bounds.Width,
                                                           newRoot.bounds.Y,
                                                           m_root.bounds.Width,
                                                           m_root.bounds.Height), this);
        newRoot.childs[2] = new QuadTreeNode(new Rectangle(newRoot.bounds.X + m_root.bounds.Width,
                                                           newRoot.bounds.Y + m_root.bounds.Height,
                                                           m_root.bounds.Width,
                                                           m_root.bounds.Height), this);
        newRoot.childs[3] = new QuadTreeNode(new Rectangle(newRoot.bounds.X,
                                                           newRoot.bounds.Y + m_root.bounds.Height,
                                                           m_root.bounds.Width,
                                                           m_root.bounds.Height), this);
      }
      m_extensionSwitch = !m_extensionSwitch;
      m_root = newRoot;
    }

    QuadTreeInsertHelper(pGameObject, result, m_root);

    return result;
  }

  /*public void Draw(List<VertexPositionColor> pPoints, List<short> pIndices)
  {
    m_root.Draw(pPoints, pIndices);
  }*/

  void objectHasMoved(T pGameObject)
  {
    if (m_objects.ContainsKey(pGameObject))
    {
      //Simple solution for now, removes the object from the tree and adds it back in
      ObjectInfo info = m_objects[pGameObject];
      foreach (QuadTreeNode node in info.isIn)
      {
        node.objects.Remove(pGameObject);
      }
      Debug.Assert(m_root.Contains(pGameObject) == false, "not removed completely");
      info.isIn = QuadTreeInsert(pGameObject);
    }
  }

  /// <summary>
  /// removes a game object from the quad tree, and the world
  /// </summary>
  /// <param name="pGameObject">the game object</param>
  public void remove(T pGameObject){
    if (m_objects.ContainsKey(pGameObject))
    {
      ObjectInfo info = m_objects[pGameObject];
      foreach (QuadTreeNode node in info.isIn)
      {
        node.objects.Remove(pGameObject);
      }
      m_objects.Remove(pGameObject);

      Debug.Assert(m_root.Contains(pGameObject) == false, "not removed completely");
    }
  }

  /// <summary>
  /// helper function to query all objects inside a rectangle
  /// </summary>
  /// <param name="pNode">current node beeing processed</param>
  /// <param name="pRect">the rectangle</param>
  /// <param name="pList">list of all found objects</param>
  private void QueryObjectInsideRectHelper(QuadTreeNode pNode, Rectangle pRect, List<IGameObject> pList){
    if (pNode.bounds.Intersects(pRect))
    {
      if (pNode.childs != null)
      {
        foreach (QuadTreeNode node in pNode.childs)
        {
          QueryObjectInsideRectHelper(node, pRect, pList);
        }
      }
      else
      {
        foreach (IGameObject obj in pNode.objects)
        {
          if (pRect.Intersects(obj.collision.bounds) && !pList.Contains(obj))
          {
            pList.Add(obj);
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
  public List<IGameObject> queryObjectsInsideRect(Rectangle pRect){
    List<IGameObject> list = new List<IGameObject>();
    QueryObjectInsideRectHelper(m_root, pRect, list);
    return list;
  }

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
    foreach (IGameObject obj in m_objects.Keys.ToArray())
    {
      remove(obj);
    }
    m_objects.Clear();
  }
}

++/