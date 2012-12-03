module thBase.json;

alias RCArray!(immutable(char), IAllocator) JsonString;

abstract class JsonBase
{
  private:
    IAllocator m_allocator;
  
  public:
    this(IAllocator allocator)
    {
      m_allocator = allocator;
    }
}

class JsonArray : JsonBase
{
  private:
    compose!(Vector!(JsonValue, IAllocator)) m_data;

  public:
    this(IAllocator allocator)
    {
      super(allocator);
      m_data = typeof(m_data)(DefaultCtor());
      m_data.construct(allocator);
    }

    @property Vector!(JsonValue, IAllocator) data()
    {
      return m_data;
    }
}

class JsonObject : JsonBase
{
  private:
    compose!(Hashmap(JsonString, JsonValue, StdHashPolicy, IAllocator)) m_keyValuePairs;

  public:
    this(IAllocator allocator)
    {
      super(allocator);
    }
}

class JsonValue : JsonBase
{
  enum Type
  {
    Array,
    Object,
    String,
    Bool,
    Number,
    Null
  }

  private:
    Type m_type;
    union
    {
      JsonString m_string;
      JsonObject m_object;
      JsonArray m_array;
      bool m_bool;
    }
}