module thBase.bitstream;

public import thBase.types : thResult;
import thBase.math;
import std.traits;

version=LITTLE_ENDIAN;

class BitStreamBase
{
  protected:
    T swizzle(T)(T val)
    {
      static if(T.sizeof == 1)
        return val;
      else
      {
        version(LITTLE_ENDIAN)
        {
          ubyte[T.sizeof] mem;
          static assert(isIntegral!T, "error can only convert integral types to correct endianes");
          ubyte[] orgVal = (cast(ubyte*)&val)[0..T.sizeof];
          for(size_t i=0; i<T.sizeof; i++)
          {
            mem[i] = orgVal[T.sizeof-i-1];
          }
          return *(cast(T*)mem.ptr);
        }
        else
        {
          return val;
        }
      }
    }
}

class BitOutStream(AT = StdAllocator) : BitStreamBase
{
  private:
    ubyte[] m_data;
    ubyte* m_currentByte;
    ubyte m_currentBit;
    AT m_allocator;

    void ensureBytesLeft(size_t size)
    {
      size_t currentLength =(m_currentByte - m_data.ptr) + 1;
      if( m_data.length - currentLength - 1 < size)
      {
        size_t newLength = m_data.length * 2;
        while(newLength - currentLength - 1 < size)
        {
          newLength *= 2;
        }
        ubyte[] newData = AllocatorNewArray!ubyte(m_allocator, newLength);
        newData[0..currentLength] = m_data[0..currentLength];
        AllocatorDelete(m_allocator, m_data);
        m_data = newData;
        m_currentByte = m_data.ptr + (currentLength - 1);
      }
    }

  public:

    static if(is(typeof(AT.globalInstance)))
    {
      this(size_t initialSize)
      {
        this(initialSize, AT.globalInstance);
      }
    }
    
    this(size_t initialSize, AT allocator)
    {
      assert(initialSize > 0);
      m_allocator = allocator;
      m_data = AllocatorNewArray!ubyte(m_allocator, initialSize);
      m_currentByte = m_data.ptr;
      m_currentBit = 0;
    }

    ~this()
    {
      AllocatorDelete(m_allocator, m_data);
      m_data = [];
    }

    void write(T)(T value,in size_t bits = (T.sizeof * 8))
    {
      assert((bits + 7) / 8 <= T.sizeof, "trying to write more bits then type has");
      //if the bytes fit exactly, we can leave them in the original endianess and don't swizzle
      if(bits % 8 == 0 && m_currentBit == 0)
      {
        ubyte[] mem = (cast(ubyte*)&value)[0..bits / 8];
        ensureBytesLeft(mem.length);
        m_currentByte[0..mem.length] = mem[];
        m_currentByte += mem.length;
      }
      else
      {
        T swizzeldValue = swizzle(value);
        ubyte[] buf = (cast(ubyte*)&swizzeldValue)[0..T.sizeof];
        ensureBytesLeft((bits + 7) / 8);
        size_t curByte=1;
        size_t curBit=0;
        for(size_t bitsDone = 0; bitsDone < bits;)
        {
          size_t bitsTodo = min(8 - m_currentBit, bits - bitsDone);
          ubyte mask = cast(ubyte)(((1 << bitsTodo) - 1));
          mask = cast(ubyte)(mask << m_currentBit);
          ubyte data = buf[T.sizeof - curByte] >> curBit;
          if(bitsTodo > 8 - curBit)
            data = data | cast(ubyte)( buf[T.sizeof - curByte - 1] << (8 - curBit) );
          data = cast(ubyte)(data << m_currentBit);
          *m_currentByte = ((*m_currentByte) & (~mask)) | (data & mask);
          if(m_currentBit + bitsTodo >= 8)
            m_currentByte++;
          if(curBit + bitsTodo >= 8)
            curByte++;
          m_currentBit = (m_currentBit + bitsTodo) % 8;
          bitsDone += bitsTodo;
          curBit = (curBit + bitsTodo) % 8;
        }
      }
    }

    @property ubyte[] data()
    {
      auto len = (m_currentByte - m_data.ptr);
      if(m_currentBit > 0)
        len++;
      return m_data[0..len];
    }
}

class BitInStream : BitStreamBase
{
  private:
    ubyte[] m_data;
    ubyte* m_currentByte;
    ubyte m_currentBit;

    bool areBytesLeft(size_t size)
    {      
      size_t currentLength =(m_currentByte - m_data.ptr) + 1;
      return m_data.length - currentLength >= size;
    }

  public:
    this(ubyte[] data)
    {
      m_data = data;
      m_currentByte = data.ptr;
      m_currentBit = 0;
    }

    thResult read(T)(ref T val, in size_t bits = (T.sizeof * 8))
    {
      assert((bits + 7) / 8 <= T.sizeof, "trying to read more bits then the type has");
      //if the bytes exactly fit the data is in its original endianess
      if(bits % 8 == 0 && m_currentBit % 8 == 0)
      {
        val = 0;
        size_t bytes = (bits / 8);
        if(!areBytesLeft(bytes))
          return thResult.FAILURE;
        ubyte[] mem = (cast(ubyte*)&val)[0..bytes];
        mem[] = m_currentByte[0..bytes];
        m_currentByte += bytes;
      }
      else
      {
        val = 0;
        size_t bytes = (bits + 7) / 8;
        if(!areBytesLeft(bytes))
          return thResult.FAILURE;
        ubyte[T.sizeof] mem;
        size_t cur=1;
        for(size_t bitsDone = 0; bitsDone < bits; cur++)
        {
          size_t bitsTodo = min(8, bits - bitsDone);
          assert(m_currentByte < m_data.ptr + m_data.length);
          ubyte data = (*m_currentByte) >> m_currentBit;
          if(bitsTodo > 8 - m_currentBit)
          {
            m_currentByte++;
            data = data | cast(ubyte)( (*m_currentByte) << (8 - m_currentBit) );
          }
          data = data & cast(ubyte)((1 << bitsTodo) - 1);
          mem[T.sizeof - cur] = data;
          bitsDone += bitsTodo;
          m_currentBit = (m_currentBit + bitsTodo) % 8;
        }
        val = swizzle(*cast(T*)mem.ptr);
      }
      return thResult.SUCCESS;
    }
}

unittest
{
  auto outStream = New!(BitOutStream!())(1024);
  scope(exit) Delete(outStream);

  outStream.write!ubyte(123, 8);
  outStream.write!ushort(12345, 16);
  outStream.write!uint(12345678, 32);
  outStream.write!ubyte(1, 1);
  outStream.write!ushort(12345, 16);
  outStream.write!uint(13, 4);
  outStream.write!uint(14, 4);
  outStream.write!uint(3, 2);
  outStream.write!ubyte(123, 8);
  outStream.write!ushort(12345, 16);
  outStream.write!uint(12345678, 32);

  auto inStream = New!BitInStream(outStream.data);
  scope(exit) Delete(inStream);

  thResult result;
  ubyte ubdata;
  ushort usdata;
  uint uidata;

  result = inStream.read!ubyte(ubdata, 8);
  assert(result == thResult.SUCCESS);
  assert(ubdata == 123);

  result = inStream.read!ushort(usdata, 16);
  assert(result == thResult.SUCCESS);
  assert(usdata == 12345);

  result = inStream.read!uint(uidata, 32);
  assert(result == thResult.SUCCESS);
  assert(uidata == 12345678);

  result = inStream.read!ubyte(ubdata, 1);
  assert(result == thResult.SUCCESS);
  assert(ubdata == 1);

  result = inStream.read!ushort(usdata, 16);
  assert(result == thResult.SUCCESS);
  assert(usdata == 12345);
  
  result = inStream.read!uint(uidata, 4);
  assert(result == thResult.SUCCESS);
  assert(uidata == 13);

  result = inStream.read!uint(uidata, 4);
  assert(result == thResult.SUCCESS);
  assert(uidata == 14);

  result = inStream.read!uint(uidata, 2);
  assert(result == thResult.SUCCESS);
  assert(uidata == 3);

  result = inStream.read!ubyte(ubdata, 8);
  assert(result == thResult.SUCCESS);
  assert(ubdata == 123);

  result = inStream.read!ushort(usdata, 16);
  assert(result == thResult.SUCCESS);
  assert(usdata == 12345);

  result = inStream.read!uint(uidata, 32);
  assert(result == thResult.SUCCESS);
  assert(uidata == 12345678);

  //isData 0 1
  //rleLength 7 3
  //isData 1 1
  //rleLength 3 3
  //index 0 0
  //X 413 9
  //Y 57 9
}