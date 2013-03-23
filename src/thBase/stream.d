module thBase.stream;
import core.refcounted;
import thBase.file;
import thBase.format;
import thBase.traits;
import thBase.math;

class StreamException : RCException
{
  this(rcstring msg, string file = __FILE__ , size_t line = __LINE__)
  {
    super(msg,file,line);
  }
}

interface IInputStream
{
  public:
    final size_t read(T)(ref T data) if(!thBase.traits.isArray!T)
    {
      static assert(!is(T == const) && !is(T == immutable), "can not read into const / immutable value");
      return readImpl((cast(void*)&data)[0..T.sizeof]);
    }

    final size_t read(T)(T data) if(thBase.traits.isArray!T)
    {
      static assert(!is(typeof(data[0]) == const) && !is(typeof(data[0]) == immutable), "can not read into const / immutable array");
      return readImpl((cast(void*)data.ptr)[0..(arrayType!T.sizeof * data.length)]);
    }

    size_t skip(size_t bytes);

  protected:
    size_t readImpl(void[] buffer);
}

interface IPeekableInputStream
{
public:
  final size_t peek(T)(ref T data) if(!thBase.traits.isArray!T)
  {
    static assert(!is(T == const) && !is(T == immutable), "can not read into const / immutable value");
    return peekImpl((cast(void*)&data)[0..T.sizeof]);
  }

  final size_t peek(T)(T data) if(thBase.traits.isArray!T)
  {
    static assert(!is(typeof(data[0]) == const) && !is(typeof(data[0]) == immutable), "can not read into const / immutable array");
    return peekImpl((cast(void*)data.ptr)[0..(arrayType!T.sizeof * data.length)]);
  }

protected:
  size_t peekImpl(void[] buffer);
}

unittest
{

  class DummyInputStream : IInputStream
  {
    size_t readImpl(void[] buffer){return 0;}
    size_t skip(size_t bytes) { return bytes; }
  }

  DummyInputStream dummy;
  const(char)[] constArray;
  immutable(char)[] immutableArray;
  const int constValue = 1;
  immutable int immutableValue = 2;
  static assert(!__traits(compiles, dummy.read(constArray)), "passing a const array to read should not compile");
  static assert(!__traits(compiles, dummy.read(immutableArray)), "passing a immutable array to read should not compile");
  static assert(!__traits(compiles, dummy.read(constValue)), "passing a const value to read should not compile");
  static assert(!__traits(compiles, dummy.read(immutableValue)), "passing a immutable value to read should not compile");

  int[] mutableArray;
  int mutableValue;
  static assert(__traits(compiles, dummy.read(mutableArray)), "passing a mutable array to read should compile");
  static assert(__traits(compiles, dummy.read(mutableValue)), "passing a mutable value to read should compile");
}

interface ISeekableInputStream : IInputStream
{
  /**
   * the length of the stream
   */
  @property size_t length();

  /**
   * the current position in the stream
   */
  @property size_t position();

  /**
   * seek to a certain point in the stream
   * Params:
   *   position = the position to seek to
   */
  void seek(size_t position);
}

private struct IOutputStreamPutPolicy(T)
{
  char[1024] buffer;
  uint cur = 0;
  IOutputStream stream;

  this(IOutputStream stream)
  {
    this.stream = stream;
  }

  void put(T character)
  {
    buffer[cur++] = character;
    if(cur >= buffer.length)
    {
      stream.write(buffer[]);
      cur = 0;
    }
  }

  ~this()
  {
    if(cur > 0)
      stream.write(buffer[0..cur]);
  }
}

interface IOutputStream
{
  public:
    final size_t write(T)(T value) if(!thBase.traits.isArray!T)
    {
      return writeImpl((cast(const(void*))&value)[0..T.sizeof]);
    }

    final size_t write(T)(T value) if(thBase.traits.isArray!T)
    {
      return writeImpl((cast(const(void*))value.ptr)[0..arrayType!T.sizeof * value.length]);
    }

    final size_t format(string fmt, ...)
    {
      auto putPolicy = IOutputStreamPutPolicy!char(this);
      return formatDo(putPolicy, fmt, _arguments, _argptr);
    }

  protected:
    size_t writeImpl(const(void[]) data);
}

unittest
{

  class DummyOutputStream : IOutputStream
  {
    size_t writeImpl(const(void[]) buffer){return 0;}
  }

  DummyOutputStream dummy;
  const(char)[] constArray;
  immutable(char)[] immutableArray;
  const int constValue = 1;
  immutable int immutableValue = 2;
  static assert(__traits(compiles, dummy.write(constArray)), "passing a const array to write should compile");
  static assert(__traits(compiles, dummy.write(immutableArray)), "passing a immutable array to write should compile");
  static assert(__traits(compiles, dummy.write(constValue)), "passing a const value to write should compile");
  static assert(__traits(compiles, dummy.write(immutableValue)), "passing a immutable value to write should compile");

  int[] mutableArray;
  int mutableValue;
  static assert(__traits(compiles, dummy.write(mutableArray)), "passing a mutable array to write should compile");
  static assert(__traits(compiles, dummy.write(mutableValue)), "passing a mutable value to write should compile");
}

interface ISeekableOutputStream : IOutputStream
{
  /**
  * the current position in the stream
  */
  @property size_t position();

  /**
  * seek to a certain point in the stream
  * Params:
  *   position = the position to seek to
  */
  void seek(size_t position);
}

/** unbuffered file stream **/
class FileOutStream : IOutputStream
{
  private:
    RawFile file;

  public:
    this(string filename)
    {
      file = RawFile(filename,"wb");
      if(!file.isOpen())
      {
        throw New!StreamException(thBase.format.format("Couldn't open file '%s' for writing", filename));
      }
    }

  protected:
    size_t writeImpl(const(void[]) data)
    {
      return file.writeArray(data);
    }
}

class FileInStream : IInputStream, IPeekableInputStream
{
  private:
    RawFile m_file;

  public:
    this(string filename)
    {
      m_file = RawFile(filename,"rb");
      if(!m_file.isOpen())
      {
        throw New!StreamException(format("Couldn't open file '%s' for reading", filename));
      }
    }

  protected:
    override size_t readImpl(void[] buffer)
    {
      return m_file.readArray(buffer);
    }

    override size_t skip(size_t bytes)
    {
      m_file.skip(bytes);
      return bytes;
    }
}

class MemoryInStream : ISeekableInputStream
{
  private:
    void[] m_data;
    TakeOwnership m_own;
    size_t m_curPosition;
    IAllocator m_allocator;

  public:

    invariant()
    {
      assert(m_curPosition <= m_data.length);
    }

    this(void[] data, TakeOwnership own, IAllocator allocator = null)
    {
      assert(own == TakeOwnership.No || allocator !is null, "allocator required when taking ownership");
      m_own = own;
      m_data = data;
      m_allocator = allocator;
    }

    ~this()
    {
      if(m_own == TakeOwnership.Yes)
      {
        AllocatorDelete(m_allocator, m_data);
      }
    }

    override size_t readImpl(void[] buffer)
    {
      size_t canRead = min(buffer.length, m_data.length - m_curPosition);
      buffer[0..canRead] = m_data[m_curPosition..m_curPosition+canRead];
      m_curPosition += canRead;
      return canRead;
    }

    override size_t skip(size_t bytes)
    {
      size_t canRead = min(bytes, m_data.length - m_curPosition);
      m_curPosition += canRead;
      return canRead;
    }

    override size_t position()
    {
      return m_curPosition;
    }

    override void seek(size_t position)
    {
      assert(position <= m_data.length);
      m_curPosition = position;
    }

    override size_t length()
    {
      return m_data.length;
    }
}

class MemoryOutStream : ISeekableOutputStream
{
  private:
    void[] m_data;
    TakeOwnership m_own;
    size_t m_curPosition;
    IAllocator m_allocator;

  public:

    invariant()
    {
      assert(m_curPosition <= m_data.length);
    }

    this(void[] data, TakeOwnership own, IAllocator allocator = null)
    {
      assert(own == TakeOwnership.No || allocator !is null, "allocator required when taking ownership");
      m_own = own;
      m_data = data;
      m_allocator = allocator;
    }

    ~this()
    {
      if(m_own == TakeOwnership.Yes)
      {
        AllocatorDelete(m_allocator, m_data);
      }
    }

    override size_t position()
    {
      return m_curPosition;
    }

    override void seek(size_t position)
    {
      assert(position <= m_data.length);
      m_curPosition = position;
    }

    override size_t writeImpl(const(void[]) data)
    {
      size_t bytesToWrite = min(data.length, m_data.length - m_curPosition);
      m_data[m_curPosition..m_curPosition+bytesToWrite] = data[0..bytesToWrite];
      m_curPosition += bytesToWrite;
      return bytesToWrite;
    }

    @property final void[] writtenData()
    {
      return m_data[0..m_curPosition];
    }
};

class PeekableInputStreamWrapper : ISeekableInputStream
{
  private:
    void[256] m_buffer = void;
    size_T m_readPos;
    size_t m_bytesBuffered;
    IInputStream m_stream;
    TakeOwnership m_owns;
    IAlloctor m_allocator;

  public:
    this(IInputStream stream, TakeOwnership own, IAllocator allocator = null)
    {
      assert(own == TakeOwnership.no || allocator !is null, "allocator must be given when taking ownership");
      assert(stream !is null);
      m_stream = stream;
      m_own = own;
      m_allocator = allocator;
      m_bytesBuffered = stream.readImpl(m_buffer);
      m_readPos = 0;
    }

    ~this()
    {
      if(m_own == TakeOwnership.yes)
      {
        m_allocator.AllocatorDelete(m_stream);
      }
    }

    final override size_t readImpl(void[] buffer)
    {
      auto remainingBytesBuffered = m_bytesBuffered - m_readPos;
      if(buffer.length > m_buffer.length)
      {
        buffer[0..remainingBytesBuffered] = m_buffer[m_readPos..m_bytesBuffered];
        m_bytesBuffered = 0;
        m_readPos = 0;
        return remainingBytesBuffered + m_stream.readImpl(buffer[remainingBytesBuffered..$]);
      } 
      if(buffer.length > reaminingBytesBuffered)
      {
        m_buffer[0..m_readPos] = m_buffer[m_readPos..m_bytesBuffered];
        m_bytesBuffered = remainingBytesBuffered + m_stream.readImpl(m_buffer[remainingBytesBuffered..$]);
        m_readPos = 0;
      }
      auto bytesRead = min(buffer.length, m_bytesBuffered - m_readPos); 
      buffer[0..bytesRead] = m_buffer[m_readPos..(m_readPos + bytesRead)];
      m_readPos += bytesRead;
      return bytesRead;
    }

    override size_t skip(size_t bytes)
    {
      auto remainingBytesBuffered = m_bytesBuffered - m_readPos;
      if(bytes > m_buffer.length)
      {
        m_bytesBuffered = 0;
        m_readPos = 0;
        return remainingBytesBuffered + m_stream.skip(bytes);
      } 
      if(bytes > remainingBytesBuffered)
      {
        bytes -= remainingBytesBuffered;
        m_bytesBuffered = m_stream.readImpl(m_buffer[]);
        m_readPos = 0;
      }
      auto bytesSkipped= min(bytes, m_bytesBuffered - m_readPos);
      m_readPos += bytesSkipped;
      return bytesSkipped + remainingBytesBuffered;
    }

    override size_t peekImpl(void[] buffer)
    {
      assert(buffer.length <= m_buffer.length, "requested peek amount is to large");
    }
};