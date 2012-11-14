module thBase.stream;
import core.refcounted;
import thBase.file;
import thBase.format;
import thBase.traits;

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
    final size_t read(T)(T data) if(!thBase.traits.isArray!T)
    {
      static assert(!is(T == const) && !is(T == immutable), "can not read into const / immutable value");
      return readImpl((cast(void*)&data)[0..T.sizeof]);
    }

    final size_t read(T)(T data) if(thBase.traits.isArray!T)
    {
      static assert(!is(typeof(T[0]) == const) && !is(typeof(T[0]) == immutable), "can not read into const / immutable array");
      return readImpl((cast(void*)data.ptr)[0..(arrayType!T.sizeof * data.length)]);
    }

    size_t skip(size_t bytes);

  protected:
    size_t readImpl(void[] buffer);
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

  /**
   * seek to the end of the input stream
   */
  void seekEnd();
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

class FileInStream : IInputStream
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