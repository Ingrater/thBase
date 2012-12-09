module thBase.plugin;

import thBase.container.vector;
import thBase.container.hashmap;
import thBase.policies.hashing;
import core.allocator;
import core.sync.mutex;
import thBase.format;
import core.sys.windows.windows;
import rtti;
import thBase.stream;

//from core.allocator
extern(C) void _initStdAllocator(bool allowMemoryTracking);

struct ScanPair
{
  void* addr;
  TypeInfo type;
}

interface IPlugin
{
  @property string name();
  bool isInPluginMemory(void* ptr);
  size_t GetScanRoots(ScanPair[] results);
}

interface IPluginRegistry
{
  void* GetValue(string key);
}

extern(C)
{
  alias bool function(IPluginRegistry) PluginInitFunc;
  alias IPlugin function() PluginGetFunc;
  alias void function() PluginDeinitFunc;
}

version(Plugin)
{
  __gshared IPluginRegistry g_pluginRegistry;
  __gshared IAdvancedAllocator g_executableStdAllocator;
  __gshared PluginTrackingAllocator g_pluginAllocator;

  class PluginTrackingAllocator
  {
    private:
      Mutex m_mutex;
      IAdvancedAllocator m_allocator;
      Hashmap!(void*, size_t, PointerHashPolicy, IAdvancedAllocator) m_allocations;

    public:
      this(IAdvancedAllocator allocator)
      {
        assert(allocator !is null);
        m_allocator = allocator;
        m_mutex = AllocatorNew!Mutex(m_allocator);
        m_allocations = AllocatorNew!(typeof(m_allocations))(m_allocator, m_allocator);
      }

      ~this()
      {
        AllocatorDelete(m_allocator, m_allocations); m_allocations = null;
        AllocatorDelete(m_allocator, m_mutex); m_mutex = null;
      }

      void* OnAllocateMemory(size_t size, size_t alignment)
      {
        m_mutex.lock();
        scope(exit) m_mutex.unlock();

        void* result = m_allocator.AllocateMemory(size).ptr;
        m_allocations[result] = size;
        return result;
      }

      bool OnFreeMemory(void* ptr)
      {
        m_mutex.lock();
        scope(exit) m_mutex.unlock();
        assert(m_allocations.exists(ptr));
        m_allocations.remove(ptr);
        m_allocator.FreeMemory(ptr);
        return true;
      }

      void* OnReallocateMemory(void* ptr, size_t newSize)
      {
        m_mutex.lock();
        scope(exit) m_mutex.unlock();
        assert(m_allocations.exists(ptr));
        m_allocations.remove(ptr);
        void* result = m_allocator.ReallocateMemory(ptr, newSize).ptr;
        m_allocations[result] = newSize;
        return result;
      }

      final bool isInMemory(void* ptr)
      {
        m_mutex.lock();
        scope(exit) m_mutex.unlock();
        if(m_allocations.exists(ptr))
          return true;
        
        //If we don't find the raw pointer do a search through all memory blocks
        foreach(start, size; m_allocations)
        {
          if(ptr >= start && ptr < (start + size))
          {
            return true;
          }
        }
        return false;
      }
  }

  void InitPluginSystem()
  {
    _initStdAllocator(false);
    g_executableStdAllocator = cast(IAdvancedAllocator)g_pluginRegistry.GetValue("StdAllocator");
    g_pluginAllocator = AllocatorNew!PluginTrackingAllocator(g_executableStdAllocator, g_executableStdAllocator);

    // redirect all the allocations
    StdAllocator.globalInstance.OnAllocateMemoryCallback = &g_pluginAllocator.OnAllocateMemory;
    StdAllocator.globalInstance.OnFreeMemoryCallback = &g_pluginAllocator.OnFreeMemory;
    StdAllocator.globalInstance.OnReallocateMemoryCallback = &g_pluginAllocator.OnReallocateMemory;
  }

  void DeinitPluginSystem()
  {
    if(g_executableStdAllocator !is null)
      AllocatorDelete(g_executableStdAllocator, g_pluginAllocator);
  }
}
else
{
  class PluginRegistry : IPluginRegistry
  {
    private:
      composite!(Hashmap!(string, void*, StringHashPolicy)) m_storage;

      static struct PluginInfo
      {
        IPlugin plugin;
        PluginDeinitFunc PluginDeinit;
      }
      composite!(Vector!(PluginInfo)) m_loadedPlugins;


    public:
      this()
      {
        m_storage = typeof(m_storage)();
        m_storage.construct();
        m_loadedPlugins = typeof(m_loadedPlugins)();
        m_loadedPlugins.construct();
      }

      ~this()
      {
        foreach(info; m_loadedPlugins)
        {
          info.PluginDeinit();
        }
      }

      final void AddValue(string key, void* value)
      {
        m_storage[key] = value;
      }

      override void* GetValue(string key)
      {
        void* result = null;
        m_storage.ifExists(key, (ref v){ result = v; });
        debug
        {
          if(result is null)
            asm { int 3; }
        }
        return result;
      }

      final IPlugin LoadPlugin(string pluginName)
      {
        char[256] fileName;
        size_t fileNameLength = formatStatic(fileName, "%s%s%c", pluginName, ".dll", '\0');
        HMODULE hModule = LoadLibraryA(fileName.ptr);
        if(hModule is null)
        {
          //logFatalError("Could not load plugin '%s'", fileName[0..fileNameLength-1]);
          return null;
        }

        PluginInitFunc initFunc = cast(PluginInitFunc)GetProcAddress(hModule, "InitPlugin");
        PluginDeinitFunc deinitFunc = cast(PluginDeinitFunc)GetProcAddress(hModule, "DeinitPlugin");
        PluginGetFunc getFunc = cast(PluginGetFunc)GetProcAddress(hModule, "GetPlugin");
        if(initFunc is null || getFunc is null || deinitFunc is null)
        {
          /*logFatalError("Loading plugin '%s' failed because %s%s", fileName[0..fileNameLength-1], 
                        (initFunc is null) ? "InitPlugin entry point not found" : "",
                        (getFunc is null) ? "GetPlugin entry point not found" : "");*/
          return null;
        }

        if(!initFunc(g_pluginRegistry))
        {
          //logFatalError("Initializing plugin '%s' failed", fileName[0..fileNameLength-1]);
          return null;
        }

        IPlugin plugin = getFunc();
        if(plugin is null)
        {
          //logFatalError("Initializing plugin '%s' failed, no plugin interface returned", fileName[0..fileNameLength-1]);
        }
        else
        {
          m_loadedPlugins ~= PluginInfo(plugin, deinitFunc);
        }

        return plugin;
      }

      final void SerializePlugins()
      {
        auto stream = New!FileOutStream("serialize.json");
        scope(exit) Delete(stream);
        foreach(ref plugin; m_loadedPlugins)
        {
          ScanPair[10] roots;
          auto context = SerializeContext(stream, plugin.plugin);
          size_t numRoots = plugin.plugin.GetScanRoots(roots);
          foreach(root; roots[0..numRoots])
          {
            context.serialize(root.addr, "root", root.type);
          }
        }
      }

      static const(TypeInfo) unqualHelper(const TypeInfo type)
      {
        if(type is null) return null;
        auto tt = type.type;
        if(tt == TypeInfo.Type.Const || tt == TypeInfo.Type.Immutable || tt == TypeInfo.Type.Shared)
          return unqualHelper(type.next());
        return type;
      }

      static struct SerializeContext
      {

        IOutputStream stream;
        IPlugin plugin;
        uint depth = 0;
        uint nextId = 1;
        Hashmap!(void[], uint) m_serializedArrays;
        Hashmap!(void*, uint, PointerHashPolicy) m_serializedObjects;

        this(IOutputStream stream, IPlugin plugin)
        {
          this.stream = stream;
          this.plugin = plugin;
          m_serializedArrays = New!(typeof(m_serializedArrays))();
          m_serializedObjects = New!(typeof(m_serializedObjects))();
        }

        ~this()
        {
          Delete(m_serializedArrays);
          Delete(m_serializedObjects);
        }

        void serialize(void* addr, const(char)[] name, const TypeInfo type)
        {
          auto plainType = unqualHelper(type);
          string fill = (name.length > 0) ? " = " : "";
          switch(plainType.type)
          {
            case TypeInfo.Type.Class:
              if(addr is null)
              {
                stream.format("%s%s%snull", spaces[0..depth*2], name, fill);
              }
              else
              {
                serializeClass(*cast(void**)addr, name, plainType);
              }
              break;
            case TypeInfo.Type.Interface:
              {
                if(addr is null)
                {
                  stream.format("%s%s%snull", spaces[0..depth*2], name, fill);
                }
                else
                {
                  auto p = (*cast(void**)addr);
                  if(p is null)
                    stream.format("%s%s%snull", spaces[0..depth*2], name, fill);
                  else
                  {
                    auto pi = **cast(Interface***)p;
                    auto o = cast(Object)(p - pi.offset);
                    if(o.classinfo !is null)
                      serializeClass(cast(void*)o, name, o.classinfo);
                    else
                      stream.format("%s%s%snull", spaces[0..depth*2], name, fill);
                  }
                }
              }
              break;
            case TypeInfo.Type.Struct:
              serializeStruct(addr,name,plainType);
              break;
            case TypeInfo.Type.Byte:
              serializeIntegral!byte(addr, name, fill);
              break;
            case TypeInfo.Type.UByte:
              serializeIntegral!ubyte(addr, name, fill);
              break;
            case TypeInfo.Type.Short:
              serializeIntegral!short(addr, name, fill);
              break;
            case TypeInfo.Type.UShort:
              serializeIntegral!ushort(addr, name, fill);
              break;
            case TypeInfo.Type.Int:
              serializeIntegral!int(addr, name, fill);
              break;
            case TypeInfo.Type.UInt:
              serializeIntegral!uint(addr, name, fill);
              break;
            case TypeInfo.Type.Long:
              serializeIntegral!long(addr, name, fill);
              break;
            case TypeInfo.Type.ULong:
              serializeIntegral!ulong(addr, name, fill);
              break;
            case TypeInfo.Type.Float:
              stream.format("%s%s%s%f", spaces[0..depth*2], name, fill, *cast(const(float)*)addr);
              break;
            case TypeInfo.Type.Double:
              stream.format("%s%s%s%f", spaces[0..depth*2], name, fill, *cast(const(double)*)addr);
              break;
            case TypeInfo.Type.Bool:
              stream.format("%s%s%s%s", spaces[0..depth*2], name, fill, (*cast(const(bool)*)addr) ? "true" : "false");
              break;
            case TypeInfo.Type.Array:
              serializeArray(addr, name, plainType);
              break;
            case TypeInfo.Type.StaticArray:
              serializeStaticArray(addr, name, plainType);
              break;
            case TypeInfo.Type.Pointer:
              stream.format("%s%s%s%x", spaces[0..depth*2], name, fill, (*cast(const(void)**)addr));
              break;
            case TypeInfo.Type.Delegate:
              stream.format("%s%s%s%s", spaces[0..depth*2], name, fill, "delegate");
              break;
            case TypeInfo.Type.Function:
              stream.format("%s%s%s%s", spaces[0..depth*2], name, fill, "function");
              break;
            case TypeInfo.Type.Enum:
              serialize(addr, name, type.next);
              break;
            default:
              asm { int 3; }
              break;
          }
        }

        __gshared string spaces  = "                                                                                                                              ";

        void serializeIntegral(T)(void* addr, const(char)[] name, string fill)
        {
          stream.format("%s%s%s%d", spaces[0..depth*2], name, fill, *cast(const(T)*)addr);
        }

        void serializeClass(void* addr, const(char)[] name, const TypeInfo type)
        {
          if(!plugin.isInPluginMemory(addr))
          {
            stream.format("%s%s%s{ __extern = %x }", spaces[0..depth*2], name, (name.length > 0) ? " = " : "", addr);
            return;
          }
          auto rttiInfo = cast(thBase.rtti.thMemberInfo[])getRttiInfo(type);
          if(rttiInfo.length == 0)
          {
            stream.format("%s%s%s{ __noRTTI }", spaces[0..depth*2], name, (name.length > 0) ? " = " : "");
            return;
          }
          string className = rttiInfo[0].name;
          if(m_serializedObjects.exists(addr))
          {
            stream.format("%s%s%s{\n%s__refObject = %d}", spaces[0..depth*2], name, (name.length > 0) ? " = " : "", spaces[0..depth*2+2], m_serializedObjects[addr]);
            return;
          }
          uint id = nextId++;
          m_serializedObjects[addr] = id;
          stream.format("%s%s%s{\n%s__id = %d", spaces[0..depth*2], name, (name.length > 0) ? " = " : "", spaces[0..depth*2+2], id);
          depth++;
          foreach(size_t i, info; rttiInfo[1..$])
          {
            stream.format(",\n");
            serialize(addr + info.offset, info.name, info.type);
          }
          depth--;
          stream.format("\n%s}", spaces[0..depth*2]);
        }

        void serializeStruct(void* addr, const(char)[] name, const TypeInfo type)
        {
          auto rttiInfo = getRttiInfo(type);
          if(rttiInfo.length == 0)
          {
            auto typeName = (cast(TypeInfo)type).toString();
            stream.format("%s%s%s{ __noRTTI = %s }", spaces[0..depth*2], name, (name.length > 0) ? " = " : "", typeName[]);
            return;
          }
          string structName = rttiInfo[0].name;
          stream.format("%s%s%s{", spaces[0..depth*2], name, (name.length > 0) ? " = " : "");
          depth++;
          foreach(size_t i, info; rttiInfo[1..$])
          {
            if(i == 0)
              stream.format("\n");
            else
              stream.format(",\n");
            serialize(addr + info.offset, info.name, info.type);
          }
          depth--;
          stream.format("\n%s}", spaces[0..depth*2]);
        }

        void serializeArray(void* addr, const(char)[] name, const TypeInfo type)
        {
          auto elementType = unqualHelper(type.next);
          if(elementType.type == TypeInfo.Type.Char)
          {
            auto str = *cast(const(char)[]*)addr;
            stream.format("%s%s%s\"%s\"",spaces[0..depth*2], name, (name.length > 0) ? " = " : "", str);
          }
          else
          {
            size_t elementSize = elementType.tsize;
            auto array = *cast(void[]*)addr;

            stream.format("%s%s%s[",spaces[0..depth*2], name, (name.length > 0) ? " = " : "");
            if(array.ptr is null)
            {
              stream.format("]");
              return;
            }
            depth++;
            void* cur = array.ptr;
            for(size_t i=0; i<array.length; i++, cur += elementSize)
            {
              if(i == 0)
                stream.format("\n");
              else
                stream.format(",\n");
              serialize(cur, null, elementType);
            }
            depth--;
            stream.format("\n%s]", spaces[0..depth*2]);
          }
        }

        void serializeStaticArray(void* addr, const(char)[] name, const TypeInfo type)
        {
          auto t = cast(const(TypeInfo_StaticArray))cast(void*)type;
          auto elementType = unqualHelper(type.next);
          if(elementType.type == TypeInfo.Type.Char)
          {
            auto str = (cast(const(char)*)addr)[0..t.len];
            stream.format("%s%s%s\"%s\"",spaces[0..depth*2], name, (name.length > 0) ? " = " : "", str);
          }
          else
          {
            size_t elementSize = elementType.tsize;

            stream.format("%s%s%s[",spaces[0..depth*2], name, (name.length > 0) ? " = " : "");
            depth++;
            void* cur = addr;
            for(size_t i=0; i<t.len; i++, cur += elementSize)
            {
              if(i == 0)
                stream.format("\n");
              else
                stream.format(",\n");
              serialize(cur, null, elementType);
            }
            depth--;
            stream.format("\n%s]", spaces[0..depth*2]);
          }
        }
      }
  }

  PluginRegistry g_pluginRegistry;

  shared static this()
  {
    g_pluginRegistry = New!PluginRegistry();
    g_pluginRegistry.AddValue("StdAllocator", cast(void*)cast(IAdvancedAllocator)(StdAllocator.globalInstance));
  }

  shared static ~this()
  {
    Delete(g_pluginRegistry);
  }
}