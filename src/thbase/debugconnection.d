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

__gshared Socket g_debugConnection;
__gshared Mutex g_debugConnectionMutex;
__gshared Socket g_remoteDebugConnection;
__gshared Hashmap!(string, DataBucket) g_debugData;
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
      g_debugCommunicationThread = New!Thread(&debugSendAndRecieve);
    }
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

void registerDebugChannel(scope string name)
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
    if(g_debugRecieveBufferSize < g_debugRecieveBuffer.length)
    {
      sizediff_t bytesRecieved = g_remoteDebugConnection.receive(g_debugRecieveBuffer[g_debugRecieveBufferSize..$]);
      if(bytesRecieved > 0)
      {
        g_debugRecieveBufferSize += bytesRecieved;

        //Sort recieved messages into buckets
        size_t cur = 0;
        auto inStream = New!MemoryInStream(g_debugRecieveBuffer[0..g_debugRecieveBufferSize], MemoryInStream.TakeOwnership.No);
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
    Thread.sleep(dur!"msecs"(10));
  }
  g_debugCommunicationWorking = false;
}