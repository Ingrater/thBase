module thBase.chunkfile;

import thBase.file;
import thBase.container.stack;
import thBase.traits;
import thBase.types;

class Chunkfile
{
  public enum Operation
  {
    Read,
    Write,
    Modify
  }

  private:
    Operation m_operation;
    byte[] m_oldData;
    byte* m_readLocation;
    RawFile m_file;
    rcstring m_filename;
    uint m_version = 0;

    enum uint MAX_CHUNK_NAME_LENGTH = 27;
    static assert(MAX_CHUNK_NAME_LENGTH < ubyte.max, "needs to fit into a ubyte");

    struct ChunkReadInfo
    {
      char[MAX_CHUNK_NAME_LENGTH] name;
      ubyte nameLength;
      uint bytesLeft;
    }

    struct ChunkWriteInfo
    {
      size_t lengthPosition;
      size_t length;
    }

    composite!(Stack!ChunkReadInfo) m_readInfo;
    composite!(Stack!ChunkWriteInfo) m_writeInfo;

  public:
    this(rcstring filename, Operation operation)
    {
      m_filename = filename;
      m_operation = operation;
      m_readInfo = typeof(m_readInfo)(DefaultCtor());
      m_readInfo.construct();
      m_writeInfo = typeof(m_writeInfo)(DefaultCtor());
      m_writeInfo.construct();
      final switch(m_operation)
      {
        case Operation.Read:
          m_file = RawFile(m_filename[], "rb");
          break;
        case Operation.Write:
          m_file = RawFile(m_filename[], "wb");
          break;
        case Operation.Modify:
          m_file = RawFile(m_filename[], "rb");
          m_oldData = NewArray!byte(m_file.size());
          m_readLocation = m_oldData.ptr;
          m_file.readArray(m_oldData);
          m_file.close();
          m_file.open(m_filename[], "wb");
          break;
      }
    }

    ~this()
    {
      assert(m_readInfo.size == 0, "there are still chunks open for reading");
      assert(m_writeInfo.size == 0, "there are still chunks open for writing");
      Delete(m_oldData);
    }

    @property Operation operation()
    {
      return m_operation;
    }

    size_t read(T)(ref T val) if(!thBase.traits.isArray!T)
    {
      assert(m_operation != Operation.Write, "can not read in write operation");
      assert(m_readInfo.size == 0 || m_readInfo.top.bytesLeft >= T.sizeof, "reading over chunk boundary");
      size_t size;
      if(m_operation == Operation.Read)
      {
        size = m_file.read(val);
      }
      else
      {
        assert(m_readLocation + T.sizeof <= m_oldData.ptr + m_oldData.length, "out of bounds");
        val = *cast(T*)(m_readLocation);
        size = T.sizeof;
        m_readLocation += size;
      }
      if(m_readInfo.size > 0)
        m_readInfo.top.bytesLeft -= size;
      return size;
    }

    final size_t read(T)(T val) if(thBase.traits.isArray!T)
    {
      assert(m_operation != Operation.Write, "can not read in write operation");
      alias arrayType!T ET;
      assert(m_readInfo.size == 0 || m_readInfo.top.bytesLeft >= ET.sizeof * val.length, "reading over chunk boundary");

      size_t size;
      if(m_operation == Operation.Read)
      {
        size = m_file.readArray(val);
      }
      else
      {   
        if(m_readLocation + ET.sizeof * val.length <= m_oldData.ptr + m_oldData.length)
        {
          assert(0, "out of bounds");
          return 0;
        }
        val[] = (cast(ET*)m_readLocation)[0..val.length];
        size = ET.sizeof * val.length;
        m_readLocation += size;
      }
      if(m_readInfo.size > 0)
        m_readInfo.top.bytesLeft -= size;
      return size;
    }

    /**
     * Allocates and reads a array of a given type from the chunk file
     *
     * Params:
     *  allocator = the allocator to use
     *
     * Returns:
     *  the correctly initialized array or an empty array on error
     */
    T[] readAndAllocateArray(T, ST = uint, Allocator = StdAllocator)(Allocator allocator = null)
    {
      static if(is(typeof(Allocator.globalInstance)))
      {
        if(allocator is null)
          allocator = Allocator.globalInstance;
      }
      else
      {
        assert(allocator !is null, "no allocator given");
      }
      ST len = 0;
      if( read(len) < ST.sizeof)
        return [];
      if(len <= 0)
        return [];
      T[] data = AllocatorNewArray!T(allocator, len, InitializeMemoryWith.NOTHING);
      if( read(data) < T.sizeof * len )
      {
        Delete(data);
        return [];
      }
      return data;
    }

    final size_t writeArray(T, ST = uint)(T data) 
    {
      static assert(isArray!T, T.stringof ~ " is not an array");
      size_t size = write!ST(data.length);
      size += write(data);
      return size;
    }

    final size_t write(T)(auto ref T val) if(!thBase.traits.isArray!T)
    {
      assert(m_operation != Operation.Read, "can not write in read operation");
      size_t size = m_file.write(val);
      assert(size == T.sizeof, "writing failed");
      if(m_writeInfo.size > 0)
        m_writeInfo.top.length += size;
      return size;
    }

    final size_t write(T, ST = uint)(auto ref T val) if(thBase.traits.isArray!T)
    {
      assert(m_operation != Operation.Read, "can not write in read operation");
      assert(val.length < ST.max);
      size_t size = m_file.write!ST(cast(ST)val.length);
      size += m_file.writeArray(val);
      assert(size == (arrayType!T).sizeof * val.length + ST.sizeof, "writing failed");
      if(m_writeInfo.size > 0)
        m_writeInfo.top.length += size;
      return size;
    }

    final void discardChanges()
    {
      assert(m_operation == Operation.Modify, "discarding only possible when modifying");
      m_file.close();
      m_file.open(m_filename[], "wb");
      m_file.writeArray(m_oldData);
      m_file.close();
    }

    final thResult startReadChunk()
    {
      thResult result = thResult.FAILURE;
      scope(exit)
      {
        if(result != thResult.SUCCESS && m_operation == Operation.Modify)
          discardChanges();
      }
      assert(m_operation != Operation.Write, "opening a existing chunk is not possible in write mode");
      ChunkReadInfo info;
      
      //read the chunk name
      if(read(info.nameLength) != 1 || info.nameLength > MAX_CHUNK_NAME_LENGTH)
      {
        return thResult.FAILURE;
      }
      if(read(info.name[0..info.nameLength]) != info.nameLength)
        return thResult.FAILURE;

      //read the chunk length
      if(read(info.bytesLeft) != typeof(info.bytesLeft).sizeof)
        return thResult.FAILURE;

      if(m_readInfo.size > 0)
      {
        if(m_readInfo.top.bytesLeft < info.bytesLeft)
        {
          assert(0, "inner chunk is to long");
          return thResult.FAILURE;
        }
        m_readInfo.top.bytesLeft -= info.bytesLeft;
      }

      m_readInfo.push(info);

      result = thResult.SUCCESS;
      return thResult.SUCCESS;
    }

    @property final currentChunkHasMoreData()
    {
      assert(m_readInfo.size > 0, "no chunk is open");
      return m_readInfo.top.bytesLeft > 0;
    }

    @property const(char)[] currentChunkName()
    {
      assert(m_readInfo.size > 0, "no chunk is open");
      return m_readInfo.top.name[0..m_readInfo.top.nameLength];
    }

    @property uint fileVersion()
    {
      return m_version;
    }

    final void endReadChunk()
    {
      assert(m_readInfo.size > 0, "no chunk to end");
      assert(m_readInfo.top.bytesLeft == 0, "there is still data left in the chunk");
      m_readInfo.pop();
    }

    final void startWriteChunk(const(char)[] name)
    {
      assert(name.length <= MAX_CHUNK_NAME_LENGTH, "chunk name is to long");
      write!(const(char)[], ubyte)(name);
      ChunkWriteInfo info;
      info.lengthPosition = m_file.position;
      write!uint(cast(uint)0);
      m_writeInfo.push(info);
    }

    final size_t endWriteChunk()
    {
      assert(m_writeInfo.size > 0, "there is no chunk to end");
      auto length = m_writeInfo.top.length;
      m_file.seek(m_writeInfo.top.lengthPosition);
      m_file.write!uint(length);
      m_file.seekEnd();
      m_writeInfo.pop();
      if(m_writeInfo.size > 0)
        m_writeInfo.top.length += length;
      return length;
    }

    /**
     * keeps the rest of the current chunk and ends the chunk
     */
    final void keepRestOfCurrentChunk()
    {
      assert(m_operation == Operation.Modify, "can only keep chunks in modifiy operation");
      ptrdiff_t bytesRemaining = (m_oldData.ptr + m_oldData.length) - m_readLocation;
      assert(bytesRemaining >= 0, "privous read did go out of bounds");
      if(bytesRemaining > 0)
      {
        m_file.writeArray(m_readLocation[0..bytesRemaining]);
      }
      endWriteChunk();
    }

    /**
     * skips the rest of the current chunk and ends it
     */
    final void skipCurrentChunk()
    {
      assert(m_operation != Operation.Write, "can not skip chunks in write operation");
      if(m_operation == Operation.Read)
      {
        m_file.skip(m_readInfo.top.bytesLeft);
        m_readInfo.top.bytesLeft = 0;
        endReadChunk();
      }
      else
      {
        m_readLocation += m_readInfo.top.bytesLeft;
        m_readInfo.top.bytesLeft = 0;
        endReadChunk();
      }
    }

    final void startWriting(const(char)[] filetype, uint ver)
    {
      assert(m_operation != Operation.Read, "can't write in reading operation");
      assert(ver > 0, "version has to be greater then 0");
      startWriteChunk(filetype);
      write(ver);
    }

    final void endWriting()
    {
      assert(m_operation != Operation.Read, "can't write in reading operation");
      endWriteChunk();
    }

    final thResult startReading(const(char)[] filetype)
    {
      assert(m_operation != Operation.Write, "can't read in write operation");
      if( startReadChunk() != thResult.SUCCESS )
      {
        return thResult.FAILURE;
      }
      if( currentChunkName != filetype)
      {
        skipCurrentChunk();
        return thResult.FAILURE;
      }
      if( read(m_version) < typeof(m_version).sizeof )
      {
        skipCurrentChunk();
        return thResult.FAILURE;
      }
      if( m_version == 0 )
      {
        assert(0, "invalid version in chunk file");
        skipCurrentChunk();
        return thResult.FAILURE;
      }
      return thResult.SUCCESS;
    }

    final void endReading()
    {
      endReadChunk();
    }
}

version(unittest)
{
  import thBase.devhelper;
}

unittest 
{
  auto leak = LeakChecker("thBase.chunkfile unittest");
  //Writing
  {
    auto file = New!Chunkfile(_T("unittest.bin"), Chunkfile.Operation.Write);
    scope(exit) Delete(file);
    file.startWriting("unittest", 1);
    for(int i=0; i<10; i++)
    {
      uint[4] vals;
      vals[0] = i;
      vals[1] = i+1;
      vals[2] = i+2;
      vals[3] = i+3;
      file.startWriteChunk("testcase");
      file.write(i);
      file.write(i * 0.25f);
      file.startWriteChunk("array");
      file.write(vals);
      file.endWriteChunk();
      file.endWriteChunk();
    }
    file.endWriting();
  }

  //Reading
  {
    auto readFile = New!Chunkfile(_T("unittest.bin"), Chunkfile.Operation.Read);
    scope(exit) Delete(readFile);
    auto result = readFile.startReading("unittest");
    assert(result == thResult.SUCCESS);
    assert(readFile.fileVersion == 1);
    assert(readFile.currentChunkName == "unittest");
    for(int i=0; i<10; i++)
    {
      uint[4] vals;
      vals[0] = i;
      vals[1] = i+1;
      vals[2] = i+2;
      vals[3] = i+3;

      result = readFile.startReadChunk();
      assert(result == thResult.SUCCESS);
      assert(readFile.currentChunkName == "testcase");
      if(i == 4)
      {
        readFile.skipCurrentChunk();
      }
      else
      {
        int iTemp;
        assert(readFile.read(iTemp) == typeof(iTemp).sizeof);
        assert(iTemp == i);
        float fTemp;
        assert(readFile.read(fTemp) == typeof(fTemp).sizeof);
        assert(fTemp == i * 0.25f);
        result = readFile.startReadChunk();
        assert(result == thResult.SUCCESS);
        assert(readFile.currentChunkName() == "array");
        assert(readFile.currentChunkHasMoreData() == true);
        if(i == 6)
        {
          readFile.skipCurrentChunk();
        }
        else
        {
          if(i == 7)
          {
            uint[] data = readFile.readAndAllocateArray!uint();
            scope(exit) Delete(data);
            assert(data.length == 4);
            for(int j=0; j<4; j++)
              assert(data[j] == i+j);
          }
          else
          {
            uint[4] data;
            uint len;
            assert( readFile.read(len) == typeof(len).sizeof );
            assert(len == 4);
            assert( readFile.read(data[]) == (arrayType!(typeof(data))).sizeof * data.length );
            for(int j=0; j<4; j++)
              assert(data[j] == i+j);
          }
          readFile.endReadChunk();
        }
        readFile.endReadChunk();
      }
    }
    readFile.endReading();
  }
}