module thBase.debugconnection;

import core.runtime;
import core.sync.mutex;
import core.thread;

import thBase.socket;
import thBase.io;
import thBase.container.vector;
import thBase.container.hashmap;
import thBase.types;
import thBase.conv;
import thBase.stream;
import thBase.allocator;
import thBase.casts;

__gshared Socket g_debugConnection;
__gshared Mutex g_debugConnectionMutex;
__gshared Socket g_remoteDebugConnection;
__gshared Hashmap!(const(char)[], DataBucket) g_debugData;
__gshared SmartPtr!Thread g_debugCommunicationThread;
__gshared bool g_debugCommunicationWorking = true;
__gshared void[] g_debugRecieveBuffer;
__gshared size_t g_debugRecieveBufferSize = 0;

private struct DataBucket
{
  Vector!byte recieved;
  Vector!byte toSend;
  Mutex mutex;

  this(DefaultCtor c)
  {
    recieved = New!(typeof(recieved))();
    toSend = New!(typeof(toSend))();
    mutex = New!(typeof(mutex))();
  }

  void destory()
  {
    Delete(recieved);
    Delete(toSend);
  }
}

shared static this()
{
  string ipAddress = "0.0.0.0";
  ushort port = 11337;
  bool waitForConnect = false;
  string[] args = Runtime.args;
  for(int i=0; i<args.length; i++)
  {
    if(args[i] == "--waitForDebugTool")
    {
      waitForConnect = true;
    }
    else if(args[i] == "--debugPort")
    {
      if(i+1 < args.length)
      {
        thResult result = to!ushort(args[i+1], port);
        if(result != thResult.SUCCESS)
        {
          writefln("debugPort parameter is not a number");
        }
      }
      else
      {
        writefln("missing value for debugPort parameter");
      }
    }
    else if(args[i] == "--debugIp")
    {
      if(i+1 < args.length)
      {
        ipAddress = args[i+1];
      }
      else
      {
        writefln("missing value for debugIp parameter");
      }
    }
  }

  if(waitForConnect)
  {
    g_debugConnectionMutex = New!Mutex();
    g_debugConnection = New!TcpSocket();
    SmartPtr!Address address = New!InternetAddress(ipAddress, port).ptr;
    g_debugConnection.bind( address );
    g_debugConnection.listen( 1 );
    g_debugConnection.blocking = false;
    g_debugRecieveBuffer = NewArray!void(1024 * 1024 * 2); //2 MB
    while(g_remoteDebugConnection is null)
    {
      g_remoteDebugConnection = g_debugConnection.accept();
      Thread.sleep(dur!"msecs"(100));
    }
    g_remoteDebugConnection.setOption(SocketOptionLevel.TCP, SocketOption.TCP_NODELAY, 1);
    g_debugCommunicationThread = New!Thread(&debugSendAndRecieve);
  }
}

shared static ~this()
{
  g_debugCommunicationWorking = false;
  if(g_debugCommunicationThread !is null)
  {
    g_debugCommunicationThread.join();
  }
  if(g_remoteDebugConnection !is null)
  {
    g_remoteDebugConnection.shutdown(SocketShutdown.BOTH);
    g_remoteDebugConnection.close();
  }
  if(g_debugConnection !is null)
  {
    g_remoteDebugConnection.shutdown(SocketShutdown.BOTH);
    g_remoteDebugConnection.close();
  }
  Delete(g_debugConnection);
  Delete(g_remoteDebugConnection);
  g_debugCommunicationThread = null;
  Delete(g_debugConnectionMutex);
  Delete(g_debugData);
}

thResult debugConnect(scope string ip, ushort port)
{
  try {
    SmartPtr!Address address = New!InternetAddress(ip, port).ptr;
    g_remoteDebugConnection = New!TcpSocket(address);
    g_remoteDebugConnection.setOption(SocketOptionLevel.TCP, SocketOption.TCP_NODELAY, 1);
    g_remoteDebugConnection.blocking = false;
    return thResult.SUCCESS;
  }
  catch(SocketException ex)
  {
    Delete(ex);
  }
  return thResult.FAILURE;
}

void registerDebugChannel(string name)
{
  if(g_debugConnection is null)
    return;

  g_debugConnectionMutex.lock();
  scope(exit) g_debugConnectionMutex.unlock();

  assert(!g_debugData.exists(name));

  g_debugData[name] = DataBucket(DefaultCtor());
}

private void debugSendAndRecieve()
{
  loop:while(g_debugCommunicationWorking)
  {
    //recieve data
    if(g_debugRecieveBufferSize < g_debugRecieveBuffer.length)
    {
      sizediff_t bytesRecieved = g_remoteDebugConnection.receive(g_debugRecieveBuffer[g_debugRecieveBufferSize..$]);
      if(bytesRecieved > 0)
      {
        g_debugRecieveBufferSize += bytesRecieved;

        //Sort recieved messages into buckets
        size_t cur = 0;
        auto inStream = AllocatorNew!MemoryInStream(ThreadLocalStackAllocator.globalInstance, 
                                                    g_debugRecieveBuffer[0..g_debugRecieveBufferSize], 
                                                    TakeOwnership.no);
        scope(exit) AllocatorDelete(ThreadLocalStackAllocator.globalInstance, inStream);
        uint nameLength = 0;
        char[64] name;
        size_t numBytesReadSuccessfully = 0;
        if( inStream.read(nameLength) == typeof(nameLength).sizeof )
        {
          if(nameLength > name.length) //given name is to long?
          {
            //TODO print error message for invalid debug package
            //try to skip the name
            if(inStream.skip(nameLength) == nameLength)
            {
              uint dataLength = 0;
              // try reading the data length
              if(inStream.read(dataLength) == typeof(dataLength).sizeof )
              {
                //skip the data
                if(inStream.skip(dataLength) == dataLength)
                {
                  numBytesReadSuccessfully = inStream.position;
                }
              }
            }
          }
          else //We recieved a valid packet
          {
            //Try reading the name
            if( inStream.read(name[0..nameLength]) == nameLength )
            {
              uint dataLength = 0;
              auto streamPos = inStream.position;
              //try reading the data length
              if(inStream.read(dataLength) == typeof(dataLength).sizeof)
              {
                //try reading the data
                if(inStream.skip(dataLength) == dataLength)
                {
                  //We did successfully read the data
                  numBytesReadSuccessfully = inStream.position;

                  //now check if the data bucket does exist
                  DataBucket bucket;
                  {
                    g_debugConnectionMutex.lock();
                    scope(exit) g_debugConnectionMutex.unlock();

                    g_debugData.ifExists(name[0..nameLength],
                                         (ref entry){
                                           bucket = entry;
                                         },
                                         (){
                                           //TODO print error message
                                         });
                  }
                  if(bucket.mutex !is null)
                  {
                    bucket.mutex.lock();
                    scope(exit) bucket.mutex.unlock();
                    size_t start = bucket.recieved.length;
                    bucket.recieved.resize(start + dataLength);
                    inStream.seek(streamPos);
                    inStream.read(bucket.recieved[start..start+dataLength]);
                  }
                }
              }
            }
          }
        }
      }
      else if(bytesRecieved == 0)
      {
        break;
      }
      else
      {
        switch(g_remoteDebugConnection.errno){
          // An error occured, usually EWOULDBLOCK or EINTR, ignore those
          case EWOULDBLOCK, EINTR:
            break;
            // Client died and was kind enough to reset its connection before its
            // death
          case ECONNRESET:
            break loop;
            // Other errors are not ok and usually indicate the the client died
          default:
            break loop;
        }
      }
    }

    //Send data
    foreach(const(char)[] channelName, ref bucket; g_debugData)
    {
      bucket.mutex.lock();
      scope(exit) bucket.mutex.unlock();
      if(bucket.toSend.length > 0)
      {
        size_t totalBytesSend = 0;
        auto data = bucket.toSend.toArray();
        while(totalBytesSend < data.length)
        {
          ptrdiff_t bytesSend = g_remoteDebugConnection.send(data[totalBytesSend..$]);
          if (bytesSend == -1){
            if( !(g_remoteDebugConnection.errno == EWOULDBLOCK || g_remoteDebugConnection.errno == ECONNRESET) )
            {
              //logWarning("net: socket send failed with error %s", g_remoteDebugConnection.errno);
              break loop;
            }
            break;
          }
          else
            totalBytesSend += bytesSend;
        }
        if(totalBytesSend < data.length && totalBytesSend > 0)
        {
          data[0..$-totalBytesSend] = data[totalBytesSend..$];
          bucket.toSend.resize(data.length - totalBytesSend);
        }
      }
    }

    Thread.sleep(dur!"msecs"(10));
  }
  g_debugCommunicationWorking = false;
}

void recieveDebugMessages(scope const(char)[] channelName, scope void delegate(void[] msg) callback)
{
  DataBucket bucket;
  {
    g_debugConnectionMutex.lock();
    scope(exit) g_debugConnectionMutex.unlock();

    g_debugData.ifExists(channelName,
                         (ref entry)
                         {
                           bucket = entry;
                         },
                         (){
                           assert(0, "the channel does not exist. Use registerDebugChannel firsts");
                         });
  }
  if(bucket.mutex !is null)
  {
    bucket.mutex.lock();
    scope(exit) bucket.mutex.unlock();

    auto data = bucket.recieved.toArray();

    auto inStream = AllocatorNew!MemoryInStream(ThreadLocalStackAllocator.globalInstance, 
                                                data, 
                                                TakeOwnership.no);
    scope(exit) AllocatorDelete(ThreadLocalStackAllocator.globalInstance, inStream);

    while(inStream.position < data.length)
    {
      uint dataLength;
      size_t read = inStream.read(dataLength);
      assert(read == typeof(dataLength).sizeof && dataLength > 0);
      size_t start = inStream.position;
      read = inStream.skip(dataLength);
      assert(read == dataLength);
      size_t end = inStream.position;
      callback(data[start..end]);
    }
    bucket.recieved.resize(0);
  }
}

bool isActive()
{
  return g_remoteDebugConnection !is null;
}

void sendDebugMessage(scope const(char)[] channelName, const(void[]) data)
{
  if(g_remoteDebugConnection !is null)
    return;
  DataBucket bucket;
  {
    g_debugConnectionMutex.lock();
    scope(exit) g_debugConnectionMutex.unlock();

    g_debugData.ifExists(channelName,
                         (ref entry)
                         {
                           bucket = entry;
                         },
                         (){
                           assert(0, "the channel does not exist. Use registerDebugChannel firsts");
                         });
  }
  if(bucket.mutex !is null)
  {
    bucket.mutex.lock();
    scope(exit) bucket.mutex.unlock();

    uint dataLength = int_cast!uint(data.length);
    bucket.toSend ~= (cast(byte*)&dataLength)[0..typeof(dataLength).sizeof];
    bucket.toSend ~= cast(const(byte[]))data;
  }
}