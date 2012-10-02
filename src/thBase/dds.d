module thBase.dds;

import core.sys.windows.windows;
import thBase.format;
import thBase.file;
import thBase.allocator;
import thBase.math;

version(unittest)
{
  import thBase.devhelper;
}

template MAKEFOURCC(char ch0, char ch1, char ch2, char ch3)
{
  enum int MAKEFOURCC = (cast(int)ch0) | ((cast(int)ch1) << 8) | ((cast(int)ch2) << 16) | ((cast(int)ch3) << 24);
}

class DDSLoadingException : RCException
{
  this(rcstring msg)
  {
    super(msg);
  }
}

class DDSLoader
{
  public:
  enum D3DFORMAT
  {
      R8G8B8 = 20,
      A8R8G8B8 = 21,
      DXT1 = MAKEFOURCC!('D','X','T','1'),
      DXT2 = MAKEFOURCC!('D','X','T','2'),
      DXT3 = MAKEFOURCC!('D','X','T','3'),
      DXT4 = MAKEFOURCC!('D','X','T','4'),
      DXT5 = MAKEFOURCC!('D','X','T','5'),
      DX10 = MAKEFOURCC!('D','X','1','0')
  }

  private:
    struct DDS_PIXELFORMAT
    {
      DWORD dwSize;
      DWORD dwFlags;
      DWORD dwFourCC;
      DWORD dwRGBBitCount;
      DWORD dwRBitMask;
      DWORD dwGBitMask;
      DWORD dwBBitMask;
      DWORD dwABitMask;
    }

    enum PixelFormatFlags
    {
      ALPHAPIXELS = 0x1,
      ALPHA       = 0x2,
      FOURCC      = 0x4,
      RGB         = 0x40,
      YUV         = 0x200,
      LUMINANCE   = 0x20000
    }

    struct DDS_HEADER
    {  
      DWORD           dwSize;
      DWORD           dwFlags;
      DWORD           dwHeight;
      DWORD           dwWidth;
      DWORD           dwPitchOrLinearSize;
      DWORD           dwDepth;
      DWORD           dwMipMapCount;
      DWORD           dwReserved1[11];
      DDS_PIXELFORMAT ddspf;
      DWORD           dwCaps;
      DWORD           dwCaps2;
      DWORD           dwCaps3;
      DWORD           dwCaps4;
      DWORD           dwReserved2;
    }

    enum HeaderFlags
    {
      CAPS = 0x1, //required in every dds file
      HEIGHT = 0x2, //required in every dds file
      WIDTH = 0x4, // required in every dds file
      PITCH = 0x8, // required when pitch is provided for uncompressed texture
      PIXELFORMAT = 0x1000, // required in every dds file
      MIPMAPCOUNT = 0x20000, // required in a mipmaped texture
      LINEARSIZE  = 0x80000, // required when a pitch is provided for a compressed texture
      DEPTH       = 0x800000 // required in a depth texture
    }

    enum DDSCAPS
    {
      COMPLEX = 0x8,
      MIPMAP = 0x400000,
      TEXTURE = 0x1000
    }

    enum DDSCAPS2
    {
      CUBEMAP = 0x200,
      CUBEMAP_POSITIVEX = 0x400,
      CUBEMAP_NEGATIVEX = 0x800,
      CUBEMAP_POSITIVEY = 0x1000,
      CUBEMAP_NEGATIVEY = 0x2000,
      CUBEMAP_POSITIVEZ = 0x4000,
      CUBEMAP_NEGATIVEZ = 0x8000,
      VOLUME = 0x200000
    }

    DDS_HEADER m_header;
    rcstring m_filename;
    ubyte[] m_memory;
    ubyte[][] m_imageData;
    ubyte[][][] m_data;
  public:

    @property final const(ubyte[][][]) data()
    {
      return m_data;
    }

    @property final D3DFORMAT dataFormat()
    {
      return cast(D3DFORMAT)m_header.ddspf.dwFourCC;
    }

    @property final bool isCubemap()
    {
      return (m_header.dwCaps2 & DDSCAPS2.CUBEMAP) != 0;
    }

    @property final uint width()
    {
      return cast(uint)m_header.dwWidth;
    }

    @property final uint height()
    {
      return cast(uint)m_header.dwHeight;
    }

    ~this()
    {
      Delete(m_memory);
      Delete(m_imageData);
      Delete(m_data);
    }

    final void LoadFile(rcstring filename)
    {
      m_filename = filename;

      if(!thBase.file.exists(filename[]))
      {
        throw New!DDSLoadingException(format("The file '%s' does not exist", filename[]));
      }

      auto file = RawFile(filename[], "rb");

      if(file.size < 128)
      {
        throw New!DDSLoadingException(format("The file '%s' is to small to be a valid dds file", filename[]));
      }

      DWORD ddsMarker;
      file.read(ddsMarker);
      if(ddsMarker != 0x20534444)
      {
        throw New!DDSLoadingException(format("The file '%s' is not an dds file", filename[]));
      }

      file.read(m_header.dwSize);
      if(m_header.dwSize != DDS_HEADER.sizeof)
      {
        throw New!DDSLoadingException(format("dds-header size does not match inside file '%s'", filename[]));
      }

      file.read(m_header.dwFlags);
      file.read(m_header.dwHeight);
      file.read(m_header.dwWidth);
      file.read(m_header.dwPitchOrLinearSize);
      file.read(m_header.dwDepth);
      file.read(m_header.dwMipMapCount);
      foreach(ref el; m_header.dwReserved1)
      {
        file.read(el);
      }
      file.read(m_header.ddspf);
      file.read(m_header.dwCaps);
      file.read(m_header.dwCaps2);
      file.read(m_header.dwCaps3);
      file.read(m_header.dwCaps4);
      file.read(m_header.dwReserved2);

      if((m_header.ddspf.dwFlags & PixelFormatFlags.FOURCC) && (m_header.ddspf.dwFourCC == D3DFORMAT.DX10))
      {
        throw New!DDSLoadingException(format("Loading DX10 dds file '%s' is not supported yet", filename[]));
      }

      DWORD neededFlags = HeaderFlags.WIDTH | HeaderFlags.HEIGHT | HeaderFlags.PIXELFORMAT;
      if((m_header.dwFlags & neededFlags) != neededFlags)
      {
        throw New!DDSLoadingException(format("The dds-header of the file '%s' is missing the following flags: %s %s %s", 
                                             filename[],
                                             ((m_header.dwFlags & HeaderFlags.WIDTH) == 0) ? HeaderFlags.WIDTH.stringof : "",
                                             ((m_header.dwFlags & HeaderFlags.HEIGHT) == 0) ? HeaderFlags.HEIGHT.stringof : "",
                                             ((m_header.dwFlags & HeaderFlags.PIXELFORMAT) == 0) ? HeaderFlags.PIXELFORMAT.stringof : ""));
      }

      size_t numMipmaps = 1;
      size_t numTextures = 1;
      // is it a mipmapped texture
      if((m_header.dwFlags & HeaderFlags.MIPMAPCOUNT) != 0)
      {
        numMipmaps = m_header.dwMipMapCount;
      }
      size_t[] mipmapMemorySize = AllocatorNewArray!size_t(ThreadLocalStackAllocator.globalInstance, numMipmaps);
      scope(exit) AllocatorDelete(ThreadLocalStackAllocator.globalInstance, mipmapMemorySize);

      size_t memoryNeeded;
      if((m_header.ddspf.dwFlags & PixelFormatFlags.FOURCC) != 0)
      {
        // compressed texture
        if(m_header.ddspf.dwFourCC != D3DFORMAT.DXT1 &&
           m_header.ddspf.dwFourCC != D3DFORMAT.DXT2 &&
           m_header.ddspf.dwFourCC != D3DFORMAT.DXT3 &&
           m_header.ddspf.dwFourCC != D3DFORMAT.DXT4 &&
           m_header.ddspf.dwFourCC != D3DFORMAT.DXT5)
        {
          throw New!DDSLoadingException(format("Unkown fourcc format in file '%s'", filename[]));
        }

        size_t blockSize = (m_header.ddspf.dwFourCC == D3DFORMAT.DXT1) ? 8 : 16;
        size_t pitch = max(1, ((m_header.dwWidth+3)/4)) * blockSize; //how many bytes one scan line has
        size_t numScanLines = max(1, ((m_header.dwHeight+3)/4));

        bool isPowerOfTwo(size_t value)
        {
          if(value == 1)
            return true;
          return (value % 2 == 0) && isPowerOfTwo(value / 2);
        }

        if(!isPowerOfTwo(m_header.dwWidth) || !isPowerOfTwo(m_header.dwHeight))
        {
          throw New!DDSLoadingException(format("The file '%s' is a compressed texture but has a non pot size", filename[]));
        }

        size_t mipmapWidth = m_header.dwWidth;
        size_t mipmapHeight = m_header.dwHeight;
        for(size_t i=0; i<numMipmaps; i++)
        {
          size_t mipmapPitch = max(1, (mipmapWidth+3)/4) * blockSize;
          size_t mipmapNumScanlines = max(1, (mipmapHeight+3)/4);
          mipmapMemorySize[i] = mipmapPitch * mipmapNumScanlines;
          memoryNeeded += mipmapMemorySize[i];
          mipmapWidth /= 2;
          mipmapHeight /= 2;
        }

        // Is it a cubemap?
        if(m_header.dwCaps2 & DDSCAPS2.CUBEMAP)
        {
          DWORD allSides = DDSCAPS2.CUBEMAP_POSITIVEX | DDSCAPS2.CUBEMAP_NEGATIVEX |
                           DDSCAPS2.CUBEMAP_POSITIVEY | DDSCAPS2.CUBEMAP_NEGATIVEY |
                           DDSCAPS2.CUBEMAP_POSITIVEZ | DDSCAPS2.CUBEMAP_NEGATIVEZ;
          if((m_header.dwCaps2 & allSides) != allSides)
          {
            throw New!DDSLoadingException(format("File '%s' is a cubemap but does not have all 6 cube map faces", filename[]));
          }

          numTextures = 6;
          m_data = NewArray!(ubyte[][])(numTextures);
          m_imageData = NewArray!(ubyte[])(numTextures * numMipmaps);
        }
        else
        {
          m_data = NewArray!(ubyte[][])(numTextures);
          m_imageData = NewArray!(ubyte[])(numTextures * numMipmaps);
        }
      }
      else
      {
        assert(0, "not implemented yet");
      }

      m_memory = NewArray!ubyte(memoryNeeded);
      size_t memStart = 0;
      size_t arrStart = 0;
      for(size_t texture=0; texture<numTextures; texture++)
      {
        m_data[texture] = m_imageData[arrStart..arrStart+numMipmaps];
        arrStart += numMipmaps;
        for(size_t mipmap=0; mipmap<numMipmaps; mipmap++)
        {
          m_data[texture][mipmap] = m_memory[memStart..memStart+mipmapMemorySize[mipmap]];
          memStart += mipmapMemorySize[mipmap];
          if( file.readArray(m_data[texture][mipmap]) != mipmapMemorySize[mipmap] )
          {
            throw New!DDSLoadingException(format("Error reading texture %d mipmap level %d of file '%s'", texture, mipmap, filename[]));
          }
        }
      }
    }
}

unittest
{
  auto leak = LeakChecker("thBase.dds unittest");
  {
    // DXT1 compressed file without mipmaps
    try
    {
      auto loader = New!DDSLoader();
      scope(exit) Delete(loader);

      loader.LoadFile(_T("dxt1.dds"));
      assert(loader.data.length == 1, "number of textures incorrect");
      assert(loader.data[0].length == 1, "number of mipmaps incorrect");
      assert(loader.data[0][0].length > 0, "no image data loaded");
    }
    catch(DDSLoadingException ex)
    {
      auto error = ex.toString();
      Delete(ex);
      assert(0, error[]);
    }

    // DXT1 compressed file with mipmaps
    try
    {
      auto loader = New!DDSLoader();
      scope(exit) Delete(loader);

      loader.LoadFile(_T("dxt1_with_mipmaps.dds"));
      assert(loader.data.length == 1, "number of textures incorrect");
      assert(loader.data[0].length == 7, "number of mipmaps incorrect");
      for(int i=0; i<7; i++)
      {
        assert(loader.data[0][i].length > 0, "no image data loaded");
      }
    }
    catch(DDSLoadingException ex)
    {
      auto error = ex.toString();
      Delete(ex);
      assert(0, error[]);
    }

    //DXT3 compressed file
    try
    {
      auto loader = New!DDSLoader();
      scope(exit) Delete(loader);

      loader.LoadFile(_T("dxt3.dds"));
      assert(loader.data.length == 1, "number of textures incorrect");
      assert(loader.data[0].length == 1, "number of mipmaps incorrect");
      assert(loader.data[0][0].length > 0, "no image data loaded");
    }
    catch(DDSLoadingException ex)
    {
      auto error = ex.toString();
      Delete(ex);
      assert(0, error[]);
    }

    //DXT3 compressed file with mipmaps
    try
    {
      auto loader = New!DDSLoader();
      scope(exit) Delete(loader);

      loader.LoadFile(_T("dxt3_with_mipmaps.dds"));
      assert(loader.data.length == 1, "number of textures incorrect");
      assert(loader.data[0].length == 7, "number of mipmaps incorrect");
      for(int i=0; i<7; i++)
      {
        assert(loader.data[0][i].length > 0, "no image data loaded");
      }
    }
    catch(DDSLoadingException ex)
    {
      auto error = ex.toString();
      Delete(ex);
      assert(0, error[]);
    }

    // DXT5 copressed image
    try
    {
      auto loader = New!DDSLoader();
      scope(exit) Delete(loader);

      loader.LoadFile(_T("dxt5.dds"));
      assert(loader.data.length == 1, "number of textures incorrect");
      assert(loader.data[0].length == 1, "number of mipmaps incorrect");
      assert(loader.data[0][0].length > 0, "no image data loaded");
    }
    catch(DDSLoadingException ex)
    {
      auto error = ex.toString();
      Delete(ex);
      assert(0, error[]);
    }

    // DXT5 compressed image with mipmaps
    try
    {
      auto loader = New!DDSLoader();
      scope(exit) Delete(loader);

      loader.LoadFile(_T("dxt5_with_mipmaps.dds"));
      assert(loader.data.length == 1, "number of textures incorrect");
      assert(loader.data[0].length == 7, "number of mipmaps incorrect");
      for(int i=0; i<7; i++)
      {
        assert(loader.data[0][i].length > 0, "no image data loaded");
      }
    }
    catch(DDSLoadingException ex)
    {
      auto error = ex.toString();
      Delete(ex);
      assert(0, error[]);
    }
  }
}