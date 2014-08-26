module thBase.dds;

import core.sys.windows.windows;
import thBase.format;
import thBase.file;
import thBase.allocator;
import thBase.math;
import thBase.casts;

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
      R8G8B8A8 = 1,
      R16G16B16A16 = 2,
      R32G32B32A32_FLOAT = 3,
      R16G16 = 4,
      R10G10B10A2 = 5,
      DXT1 = MAKEFOURCC!('D','X','T','1'),
      DXT2 = MAKEFOURCC!('D','X','T','2'),
      DXT3 = MAKEFOURCC!('D','X','T','3'),
      DXT4 = MAKEFOURCC!('D','X','T','4'),
      DXT5 = MAKEFOURCC!('D','X','T','5'),
      DX10 = MAKEFOURCC!('D','X','1','0')
  }

  enum DXGI_FORMAT
  {
    R16G16B16A16_UNORM = 11,
    R8G8B8A8_UNORM = 28,
    R32G32B32A32_FLOAT = 2,
    R16G16_UNORM = 35,
    R10G10B10A2_UNORM = 24,
  }

  static uint bytesPerPixel(DXGI_FORMAT format)
  {
    final switch(format)
    {
      case DXGI_FORMAT.R16G16B16A16_UNORM:
        return 8;
      case DXGI_FORMAT.R8G8B8A8_UNORM:
      case DXGI_FORMAT.R16G16_UNORM:
      case DXGI_FORMAT.R10G10B10A2_UNORM:
        return 4;
      case DXGI_FORMAT.R32G32B32A32_FLOAT:
        return 16;
    }
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

    enum D3D10_RESOURCE_DIMENSION { 
      UNKNOWN    = 0,
      BUFFER     = 1,
      TEXTURE1D  = 2,
      TEXTURE2D  = 3,
      TEXTURE3D  = 4
    }

    struct DDS_HEADER_DXT10
    {
      DXGI_FORMAT              dxgiFormat;
      D3D10_RESOURCE_DIMENSION resourceDimension;
      UINT                     miscFlag;
      UINT                     arraySize;
      UINT                     miscFlags2;
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
    D3DFORMAT m_format;
    rcstring m_filename;
    alias RCArray!(ubyte, IAllocator) mipmap_data_t;
    alias RCArray!(mipmap_data_t, IAllocator) image_data_t;
    mipmap_data_t m_memory;
    image_data_t m_imageData;
    image_data_t[] m_images;
    IAllocator m_allocator;
  public:

    @property final allocator()
    {
      return m_allocator;
    }

    @property final image_data_t[] images()
    {
      return m_images;
    }

    @property final D3DFORMAT dataFormat() const
    {
      return m_format;
    }

    @property final bool isCubemap() const
    {
      return (m_header.dwCaps2 & DDSCAPS2.CUBEMAP) != 0;
    }

    @property final uint width() const
    {
      return cast(uint)m_header.dwWidth;
    }

    @property final uint height() const
    {
      return cast(uint)m_header.dwHeight;
    }

    this(IAllocator allocator)
    {
      assert(allocator !is null);
      m_allocator = allocator;
    }

    ~this()
    {
      Delete(m_images);
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

      DDS_HEADER_DXT10 header10;
      bool bCompressed = false;

      if((m_header.ddspf.dwFlags & PixelFormatFlags.FOURCC) && (m_header.ddspf.dwFourCC == D3DFORMAT.DX10))
      {
        file.read(header10);
        if(header10.arraySize > 1)
        {
          throw New!DDSLoadingException(format("Loading texture arrays is not supported yet"));
        }
        switch(header10.dxgiFormat)
        {
          case DXGI_FORMAT.R16G16B16A16_UNORM:
            m_format = D3DFORMAT.R16G16B16A16;
            break;
          case DXGI_FORMAT.R8G8B8A8_UNORM:
            m_format = D3DFORMAT.R8G8B8A8;
            break;
          case DXGI_FORMAT.R32G32B32A32_FLOAT:
            m_format = D3DFORMAT.R32G32B32A32_FLOAT;
            break;
          case DXGI_FORMAT.R16G16_UNORM:
            m_format = D3DFORMAT.R16G16;
            break;
          case DXGI_FORMAT.R10G10B10A2_UNORM:
            m_format = D3DFORMAT.R10G10B10A2;
            break;
          default:
            throw New!DDSLoadingException(format("unsupported DXGI format in DX10 extension header"));
        }
      }
      else if(m_header.ddspf.dwFlags & PixelFormatFlags.FOURCC)
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
        bCompressed = true;
      }
      else if(m_header.ddspf.dwFlags & PixelFormatFlags.RGB)
      {
        if(m_header.ddspf.dwRGBBitCount != 32)
        {
          throw New!DDSLoadingException(format("Rgb formats are only supported with alpha. file: '%s'", m_filename[]));
        }
        // swizzeled because of endianes

        if(m_header.ddspf.dwABitMask != 0xFF_00_00_00 ||
           m_header.ddspf.dwRBitMask != 0x00_00_00_FF ||
           m_header.ddspf.dwGBitMask != 0x00_00_FF_00 ||
           m_header.ddspf.dwBBitMask != 0x00_FF_00_00 )
        {
          throw New!DDSLoadingException(format("Unsupported rgb format in file '%s'.", m_filename[]));
        }

        m_format = D3DFORMAT.R8G8B8A8;
      }
      else
      {
        throw New!DDSLoadingException(format("The format of the file '%s' is not supported.", m_filename[]));
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
      if(bCompressed)
      {
        m_format = cast(D3DFORMAT)m_header.ddspf.dwFourCC;

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
      }
      else
      {
        size_t bytesPerPixel;
        final switch(m_format)
        {
          case D3DFORMAT.R16G16B16A16:
            bytesPerPixel = 8;
            break;
          case D3DFORMAT.R8G8B8A8:
          case D3DFORMAT.R16G16:
          case D3DFORMAT.R10G10B10A2:
            bytesPerPixel = 4;
            break;
          case D3DFORMAT.R32G32B32A32_FLOAT:
            bytesPerPixel = 16;
            break;
          case D3DFORMAT.DXT1:
          case D3DFORMAT.DXT2:
          case D3DFORMAT.DXT3:
          case D3DFORMAT.DXT4:
          case D3DFORMAT.DXT5:
          case D3DFORMAT.DX10:
            assert(0, "should not happen");
        }

        size_t mipmapWidth = m_header.dwWidth;
        size_t mipmapHeight = m_header.dwHeight;

        for(size_t i=0; i<numMipmaps; i++)
        {
          size_t mipmapPitch = mipmapWidth * bytesPerPixel;
          size_t mipmapNumScanlines = mipmapHeight;
          mipmapMemorySize[i] = mipmapPitch * mipmapNumScanlines;
          memoryNeeded += mipmapMemorySize[i];
          mipmapWidth /= 2;
          mipmapHeight /= 2;
        }
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
        memoryNeeded *= numTextures;
        m_images = NewArray!(image_data_t)(numTextures);
        m_imageData = image_data_t(numTextures * numMipmaps, m_allocator);
      }
      else
      {
        m_images = NewArray!(image_data_t)(numTextures);
        m_imageData = image_data_t(numTextures * numMipmaps, m_allocator);
      }

      m_memory = mipmap_data_t(memoryNeeded, m_allocator); //new RCArray of size memoryNeeded
      size_t memStart = 0;
      size_t arrStart = 0;
      for(size_t texture=0; texture<numTextures; texture++)
      {
        m_images[texture] = m_imageData[arrStart..arrStart+numMipmaps];
        arrStart += numMipmaps;
        for(size_t mipmap=0; mipmap<numMipmaps; mipmap++)
        {
          m_images[texture][mipmap] = m_memory[memStart..memStart+mipmapMemorySize[mipmap]];
          memStart += mipmapMemorySize[mipmap];
          if( file.readArray(m_images[texture][mipmap]) != mipmapMemorySize[mipmap] )
          {
            throw New!DDSLoadingException(format("Error reading texture %d mipmap level %d of file '%s'", texture, mipmap, filename[]));
          }
        }
      }
    }
}

void WriteDDS(const(char)[] filename, uint width, uint height, DDSLoader.DXGI_FORMAT format,const(void)[] data)
{
  auto file = RawFile(filename, "wb");
  DWORD ddsMarker = 0x20534444;
  file.write(ddsMarker);

  DDSLoader.DDS_HEADER header;
  header.dwSize = int_cast!uint(DDSLoader.DDS_HEADER.sizeof);
  assert(header.dwSize == 124);

  header.dwFlags = DDSLoader.HeaderFlags.CAPS | DDSLoader.HeaderFlags.WIDTH | DDSLoader.HeaderFlags.HEIGHT | DDSLoader.HeaderFlags.PIXELFORMAT | DDSLoader.HeaderFlags.PITCH;
  header.dwWidth = width;
  header.dwHeight = height;
  header.dwPitchOrLinearSize = width * DDSLoader.bytesPerPixel(format);
  header.ddspf.dwSize = header.ddspf.sizeof;
  assert(header.ddspf.dwSize == 32);
  header.ddspf.dwFlags = DDSLoader.PixelFormatFlags.FOURCC;
  header.ddspf.dwFourCC = DDSLoader.D3DFORMAT.DX10;
  header.dwCaps = DDSLoader.DDSCAPS.TEXTURE;
  file.write(header);

  DDSLoader.DDS_HEADER_DXT10 header10;
  header10.dxgiFormat = format;
  header10.resourceDimension = DDSLoader.D3D10_RESOURCE_DIMENSION.TEXTURE2D;
  header10.miscFlag = 0;
  header10.arraySize = 1;
  header10.miscFlags2 = 0;
  file.write(header10);

  assert(data.length == width * DDSLoader.bytesPerPixel(format) * height);
  file.writeArray(data);
}

unittest
{
  auto leak = LeakChecker("thBase.dds unittest");
  {
    // DXT1 compressed file without mipmaps
    try
    {
      auto loader = New!DDSLoader(StdAllocator.globalInstance);
      scope(exit) Delete(loader);

      loader.LoadFile(_T("dxt1.dds"));
      assert(loader.images.length == 1, "number of textures incorrect");
      assert(loader.images[0].length == 1, "number of mipmaps incorrect");
      assert(loader.images[0][0].length > 0, "no image data loaded");
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
      auto loader = New!DDSLoader(StdAllocator.globalInstance);
      scope(exit) Delete(loader);

      loader.LoadFile(_T("dxt1_with_mipmaps.dds"));
      assert(loader.images.length == 1, "number of textures incorrect");
      assert(loader.images[0].length == 7, "number of mipmaps incorrect");
      for(int i=0; i<7; i++)
      {
        assert(loader.images[0][i].length > 0, "no image data loaded");
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
      auto loader = New!DDSLoader(StdAllocator.globalInstance);
      scope(exit) Delete(loader);

      loader.LoadFile(_T("dxt3.dds"));
      assert(loader.images.length == 1, "number of textures incorrect");
      assert(loader.images[0].length == 1, "number of mipmaps incorrect");
      assert(loader.images[0][0].length > 0, "no image data loaded");
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
      auto loader = New!DDSLoader(StdAllocator.globalInstance);
      scope(exit) Delete(loader);

      loader.LoadFile(_T("dxt3_with_mipmaps.dds"));
      assert(loader.images.length == 1, "number of textures incorrect");
      assert(loader.images[0].length == 7, "number of mipmaps incorrect");
      for(int i=0; i<7; i++)
      {
        assert(loader.images[0][i].length > 0, "no image data loaded");
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
      auto loader = New!DDSLoader(StdAllocator.globalInstance);
      scope(exit) Delete(loader);

      loader.LoadFile(_T("dxt5.dds"));
      assert(loader.images.length == 1, "number of textures incorrect");
      assert(loader.images[0].length == 1, "number of mipmaps incorrect");
      assert(loader.images[0][0].length > 0, "no image data loaded");
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
      auto loader = New!DDSLoader(StdAllocator.globalInstance);
      scope(exit) Delete(loader);

      loader.LoadFile(_T("dxt5_with_mipmaps.dds"));
      assert(loader.images.length == 1, "number of textures incorrect");
      assert(loader.images[0].length == 7, "number of mipmaps incorrect");
      for(int i=0; i<7; i++)
      {
        assert(loader.images[0][i].length > 0, "no image data loaded");
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