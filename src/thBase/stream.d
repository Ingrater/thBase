module thBase.stream;
import core.refcounted;
import thBase.file;
import thBase.format;

class StreamException : RCException
{
  this(rcstring msg, string file = __FILE__ , size_t line = __LINE__)
  {
    super(msg,file,line);
  }
}

interface IInputStream
{
}

interface IDataInStream
{
  //TODO implement when static final template methods are allowed within interfaces
}

interface IOutputStream
{
  void write(ubyte data);
  void write(char data);

  void writeString(string data);
  void writeString(rcstring data);

  void writeLine(string line);
  void writeLine(rcstring line);

  size_t format(string fmt, ...);
}

/** unbuffered file stream **/
class FileOutStream : IOutputStream
{
  RawFile file;

  this(string filename)
  {
    file = RawFile(filename,"wb");
    if(!file.isOpen())
    {
      throw New!StreamException(_T("Couldn't open file '") ~ filename ~ _T("' for writing"));
    }
  }

  void write(ubyte data)
  {
    file.write(data);
  }

  void write(char data)
  {
    file.write(data);
  }

  void writeString(string data)
  {
    file.writeArray(data);
  }

  void writeString(rcstring data)
  {
    file.writeArray(data);
  }

  void writeLine(string line)
  {
    writeString(line);
    version(Windows)
    {
      writeString("\r\n");
    }
    version(linux)
    {
      writeString("\n");
    }
  }

  void writeLine(rcstring line)
  {
    writeLine(line[]);
  }

  size_t format(string fmt, ...)
  {
    auto put = RawFilePutPolicy!char(file);
    return formatDo(put,fmt,_arguments,_argptr);
  }
}

class FileInStream : IInputStream
{
  RawFile m_file;

  this(string filename)
  {
    m_file = RawFile(filename,"rb");
    if(!m_file.isOpen())
    {
      throw New!StreamException(_T("Couldn't open file '") ~ filename ~ _T("' for reading"));
    }
  }
}