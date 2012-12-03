module thBase.message;

import std.typetuple;
import thBase.traits;
import core.stdc.string;

enum FreeMemory
{
  no,
  yes
}

class MessageStorage(Allocator, FreeMemory freePolicy, MessageTypes...)
{
  private:
    Allocator m_allocator;
    alias TypeTuple!(MessageTypes) MessageTypeList;

    static struct Header
    {
      uint id;
      Header* next;
    }
    Header* m_first;
    Header* m_last;

  public:
    this(Allocator allocator)
    {
      m_allocator = allocator;
    }

    static if(is(typeof(Allocator.globalInstance)))
    {
      this()
      {
        m_allocator = Allocator.globalInstance;
      }
    }

    @property Allocator allocator()
    {
      return m_allocator;
    }

    template idOf(M)
    {
      static assert(staticIndexOf!(M, MessageTypeList) >= 0, M.stringof ~ " has not been specified as message type for this message storage");
      enum uint idOf = staticIndexOf!(M, MessageTypeList);
    }

    M* append(M)()
    {
      static assert(is(M == struct), "only struct messages are supported. " ~ M.stringof ~ " is not a struct");
      Header* header = cast(Header*)m_allocator.AllocateMemory(Header.sizeof + M.sizeof).ptr;
      M* message = cast(M*)(header+1);
      header.next = m_last;
      header.id = idOf!M;
      m_last = header;
      if(m_first is null)
        m_first = header;
      M initHelper;
      memcpy(message, &initHelper, M.sizeof);
      return message;
    }

    @property bool empty() const
    {
      return (m_first is null);
    }

    @property uint idOfNextMessage() const
    {
      assert(m_first !is null);
      return m_first.id;
    }

    @property M* get(M)()
    {
      assert(m_first !is null);
      assert(idOf!M == m_first.id);
      M* result = cast(M*)(m_first+1);
      return result;
    }

    void next()
    {
      static if(freePolicy == FreeMemory.yes)
      {
        static if(anySatisfy!(needsDestruction, MessageTypeList))
        {
          //TODO mixin destroy switch case
        }
        m_allocator.FreeMemory(m_first);
      }
      m_first = m_first.next;
    }
}

version(unittest)
{
  import thBase.devhelper;
  import core.allocator;
}

unittest
{
  static struct Message1
  {
    int i = 1;
  }

  static struct Message2
  {
    char[] text;
  }

  static struct Message3
  {
    float f = 15.0f;
  }

  auto leak = LeakChecker("thBase.message unittest");

  {
    string testText = "Hello World!";
    auto storage = New!(MessageStorage!(StdAllocator, FreeMemory.yes, Message1, Message2, Message3))();
    scope(exit) Delete(storage);

    {
      auto m1 = storage.append!Message1();
      assert(m1.i == 1, "not correctly initialized");
      m1.i = 2;
    }

    {
      auto m2 = storage.append!Message2();
      assert(m2.text is null, "not correctly initialized");
      m2.text = AllocatorNewArray!char(storage.allocator, testText.length);
      m2.text[] = testText[];
    }

    {
      auto m3 = storage.append!Message3();
      assert(m3.f == 15.0f, "not correctly initialized");
      m3.f = 16.0f;
    }

    //Now read the stuff again
    {
      assert(!storage.empty);
      assert(storage.idOfNextMessage == storage.idOf!Message1);
      {
        auto m1 = storage.get!Message1();
        assert(m1.i == 2);
      }
      storage.next();
      assert(!storage.empty);
      assert(storage.idOfNextMessage == storage.idOf!Message2);
      {
        auto m2 = storage.get!Message2();
        assert(m2.text == testText, "allocated array not correct");
      }
      storage.next();
      assert(!storage.empty);
      assert(storage.idOfNextMessage == storage.idOf!Message3);
      {
        auto m3 = storage.get!Message3();
        assert(m3.f == 16.0f, "message 3 content not correct");
      }
      storage.next();
      assert(storage.empty);
    }
  }
}