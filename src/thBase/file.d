module thBase.file;

import thBase.traits;

import core.stdc.stdio;
import core.stdc.stdlib;
import thBase.string;
import thBase.casts;
import thBase.allocator;

version(Windows)
{
  import core.sys.windows.windows;
}

/**
 * wrapper around C FILE for raw file handling
 */
struct RawFile {
	FILE* m_Handle = null;

  @disable this(this);
	
	/**
	 * opens a file
	 * Params:
	 *  pFilename = the filename
	 *  pMode = the mode for the filestream
	 */
	void open(const(char)[] pFilename, const(char)[] pMode){
    assert(!isOpen());
    char[] szFilename = (cast(char*)alloca(pFilename.length+1))[0..(pFilename.length+1)];
    szFilename[0..($-1)] = pFilename[];
    szFilename[$-1] = '\0';

    char[] szMode = (cast(char*)alloca(pMode.length+1))[0..(pMode.length+1)];
    szMode[0..($-1)] = pMode[];
    szMode[$-1] = '\0';
		m_Handle = fopen(szFilename.ptr,szMode.ptr);
	}

	/**
  * constructor
  * Params:
  *  pFilename = the filename
  *  pMode = the mode for the filestream
  */
  this(const(char)[] pFilename, const(char)[] pMode)
  {
    open(pFilename, pMode);
  }
	
	~this(){
		close();
	}

	/**
	 * Returns: if the file is open or not
	 */
	bool isOpen(){
		return (m_Handle !is null);
	}
	
	/**
	 * writes a value to the file as raw data
	 * Params:
	 *	value = the value to write
	 * Returns: number of bytes written
	 */
	size_t write(T)(T value)
	in {
		assert(m_Handle !is null);
	}
	body {
		return fwrite(&value,T.sizeof,1,m_Handle) * T.sizeof;
	}
	
	/**
	 * writes a array of values as raw data
	 * Params:
	 *  values = the values
	 * Returns: number of bytes written
	 */
	size_t writeArray(T)(T values) if(thBase.traits.isArray!T)
	in {
		assert(m_Handle !is null);
	}
	body {
		return fwrite(values.ptr,arrayType!T.sizeof,values.length,m_Handle)  * arrayType!T.sizeof;
	}
	
	/**
	 * reads a value as raw data
	 * Params:
	 *  value = the value
	 * Returns: number of bytes read
	 */
	size_t read(T)(ref T value)
	in {
		assert(m_Handle !is null);
	}
	body {
		return fread(&value,T.sizeof,1,m_Handle) * T.sizeof;
	}
	
	/**
	 * reads a value array as raw data
	 * Params:
	 *  values = the values
	 * Returns: number of bytes read
	 */
	size_t readArray(T)(T values) if(thBase.traits.isArray!T)
	in {
		assert(m_Handle !is null);
	}
	body {
		return fread(values.ptr,arrayType!T.sizeof,values.length,m_Handle) * arrayType!T.sizeof;
	}
	
	/**
	 * closes the file
	 * $(BR) this is done automatically upon destruction of the wrapper object
	 */
	void close(){
		if(m_Handle !is null){
			fclose(m_Handle);
			m_Handle = null;
		}
	}

  /**
   * writes all buffered contents of the file to the disk
   */
  void flush()
  in
  {
    assert(m_Handle !is null);
  }
  body
  {
    fflush(m_Handle);
  }

  /**
   * gets the size of the file
   */
  @property size_t size()
  {
    if( m_Handle !is null)
    {
      auto cur = ftell(m_Handle);
      fseek(m_Handle,0,SEEK_END);
      auto len = ftell(m_Handle);
      fseek(m_Handle,cur,SEEK_SET);
      return len;
    }
    return 0;
  }

  /**
   * gets the current position in the file
   */
  @property size_t position()
  {
    if(m_Handle !is null)
    {
      return ftell(m_Handle);
    }
    return 0;
  }

  /**
   * sets the current position in the file
   */
  void seek(size_t position)
  {
    if( m_Handle !is null)
    {
      fseek(m_Handle, int_cast!int(position), SEEK_SET);
    }
  }

  /**
   * sets the position to the end of the file
   */
  void seekEnd()
  {
    if(m_Handle !is null)
    {
      fseek(m_Handle, 0, SEEK_END);
    }
  }

  /**
   * skips a given number of bytes
   */
  void skip(size_t bytes)
  {
    if(m_Handle !is null)
    {
      fseek(m_Handle, int_cast!int(bytes), SEEK_CUR);
    }
  }

  @property bool eof()
  {
    if( m_Handle !is null)
      return !!feof(m_Handle);
    return true;
  }
};

version(Windows)
{
  bool exists(const(char)[] filename)
  {
    mixin(stackCString("filename", "cstr"));
    DWORD attributes = GetFileAttributesA(cstr.ptr);
    return (attributes != 0xFFFFFFFF && 
            !(attributes & FILE_ATTRIBUTE_DIRECTORY));
  }

  enum OverwriteIfExists
  {
    No = 0,
    Yes = 1
  }

  bool copy(const(char)[] from, const(char)[] to, OverwriteIfExists overwrite)
  {
    mixin(stackCString("from", "cstrFrom"));
    mixin(stackCString("to","cstrTo"));
    return CopyFileA(cstrFrom.ptr, cstrTo.ptr, (overwrite == OverwriteIfExists.No)) != 0;
  }
}
else
{
  static assert(0, "not implemented");
}