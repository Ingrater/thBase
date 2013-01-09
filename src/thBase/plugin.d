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
import thBase.io;
import thBase.file;
import thBase.directory;
import thBase.enumbitfield;
import thBase.string;
import core.thread : thread_findByAddr;

import core.stdc.string;

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
  alias bool function(IPluginRegistry, void*) PluginInitFunc;
  alias IPlugin function() PluginGetFunc;
  alias void function() PluginDeinitFunc;
}
alias bool function(uint id) IsDThreadFunc;

version(Plugin)
{
  __gshared IPluginRegistry g_pluginRegistry;
  __gshared IAdvancedAllocator g_executableStdAllocator;
  __gshared PluginTrackingAllocator g_pluginAllocator;
  __gshared IsDThreadFunc IsDThread;

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

  void InitPluginSystem(void* allocator)
  {
    IsDThread = cast(IsDThreadFunc)g_pluginRegistry.GetValue("thBase.plugin.IsDThread");
    _initStdAllocator(false);
    g_executableStdAllocator = cast(IAdvancedAllocator)g_pluginRegistry.GetValue("StdAllocator");
    if(allocator !is null)
    {
      g_pluginAllocator = cast(PluginTrackingAllocator)allocator;
    }
    else
    {
      g_pluginAllocator = AllocatorNew!PluginTrackingAllocator(g_executableStdAllocator, g_executableStdAllocator);
    }

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
      uint tempCounter = 0; //Number of the next temporary directory

      static struct PluginInfo
      {
        rcstring name;
        IPlugin plugin;
        PluginDeinitFunc PluginDeinit;
      }
      composite!(Vector!(PluginInfo)) m_loadedPlugins;
      DirectoryWatcher m_directoryWatcher;


    public:
      this()
      {
        m_storage = typeof(m_storage)();
        m_storage.construct();
        m_loadedPlugins = typeof(m_loadedPlugins)();
        m_loadedPlugins.construct();
        if(thBase.directory.exists("..\\plugins"))
          m_directoryWatcher = New!DirectoryWatcher("..\\plugins", DirectoryWatcher.WatchSubdirs.No, Flags(DirectoryWatcher.Watch.Writes));
      }

      ~this()
      {
        foreach(info; m_loadedPlugins)
        {
          info.PluginDeinit();
        }
        Delete(m_directoryWatcher);
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

      private final HMODULE CopyAndLoadPlugin(const(char)[] pluginName)
      {
        char[512] fileName;

        size_t fileNameLength = formatStatic(fileName, "..\\plugins\\%s.dll", pluginName);
        if(!thBase.file.exists(fileName[0..fileNameLength]))
        {
          throw New!RCException(format("The plugin '%s' could not be found", pluginName));
        }

        char[512] dirName;
        size_t dirNameLength = formatStatic(dirName, "plugin%d", tempCounter++);
        if(!thBase.directory.exists(dirName[0..dirNameLength]))
        {
          if(!thBase.directory.create(dirName[0..dirNameLength]))
          {
            throw New!RCException(format("Creating the directory '%s' failed", dirName[0..dirNameLength]));
          }
        }

        char[512] dstName;
        size_t dstNameLength = formatStatic(dstName, "%s\\%s%d.dll", dirName[0..dirNameLength], pluginName, tempCounter-1);

        if(!thBase.file.copy(fileName[0..fileNameLength], dstName[0..dstNameLength], OverwriteIfExists.Yes))
        {
          throw New!RCException(format("Failed to copy plugin '%s' to '%s'", pluginName, dstName[0..dstNameLength]));
        }

        char[512] pdbSource;
        size_t pdbSourceLength = formatStatic(pdbSource, "..\\plugins\\%s.pdb", pluginName);
        if(thBase.file.exists(pdbSource[0..pdbSourceLength]))
        {
          char[512] pdbDst;
          size_t pdbDstLength = formatStatic(pdbDst, "%s\\%s.pdb", dirName[0..dirNameLength], pluginName);
          thBase.file.copy(pdbSource[0..pdbSourceLength], pdbDst[0..pdbDstLength], OverwriteIfExists.Yes);
        }

        dstName[dstNameLength] = '\0';

        HMODULE hModule = LoadLibraryA(dstName.ptr);
        if(hModule is null)
        {
          throw New!RCException(format("Could not load plugin '%s'", fileName[0..fileNameLength-1]));
        }
        return hModule;
      }

      final IPlugin LoadPlugin(const(char)[] pluginName)
      {
        HMODULE hModule = CopyAndLoadPlugin(pluginName);

        PluginInitFunc initFunc = cast(PluginInitFunc)GetProcAddress(hModule, "InitPlugin");
        PluginDeinitFunc deinitFunc = cast(PluginDeinitFunc)GetProcAddress(hModule, "DeinitPlugin");
        PluginGetFunc getFunc = cast(PluginGetFunc)GetProcAddress(hModule, "GetPlugin");
        if(initFunc is null || getFunc is null || deinitFunc is null)
        {
          throw New!RCException(format("Loading plugin '%s' failed because %s%s%s", pluginName, 
                        (initFunc is null) ? "InitPlugin entry point not found " : "",
                        (getFunc is null) ? "GetPlugin entry point not found " : "",
                        (deinitFunc is null) ? "DeinitPlugin entry point not found " : ""));
        }

        if(!initFunc(g_pluginRegistry, null))
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
          m_loadedPlugins ~= PluginInfo(rcstring(pluginName), plugin, deinitFunc);
        }

        return plugin;
      }

      final void CheckForModifiedPlugins()
      {
        if(m_directoryWatcher is null)
          return;

        m_directoryWatcher.EnumerateChanges(
          (filename, action){
            if(filename.endsWith(".dll", CaseSensitive.no))
            {
              const(char)[] pluginName = filename[0..$-4];
              bool found = false;
              foreach(ref info; m_loadedPlugins)
              {
                if(info.name[] == pluginName)
                {
                  found = true;
                  //logInfo("Reloading plugin '%s'", filename);
                  ReloadPlugin(pluginName);
                  break;
                }
              }
              if(!found)
              {
                //logWarning("Plugin '%s' changed but is not yet loaded", filename);
              }
            }
          }
        );
      }

      final IPlugin ReloadPlugin(const(char)[] pluginName)
      {
        IPlugin oldPlugin;
        size_t pluginIndex;
        foreach(size_t i, ref info; m_loadedPlugins.toArray())
        {
          if(info.name[] == pluginName)
          {
            oldPlugin = info.plugin;
            pluginIndex = i;
            break;
          }
        }
        if(oldPlugin is null)
        {
          throw New!RCException(format("Can't reload plugin '%s' because it is not yet loaded", pluginName));
        }

        HMODULE hModule = CopyAndLoadPlugin(pluginName);

        PluginInitFunc initFunc = cast(PluginInitFunc)GetProcAddress(hModule, "InitPlugin");
        PluginDeinitFunc deinitFunc = cast(PluginDeinitFunc)GetProcAddress(hModule, "DeinitPlugin");
        PluginGetFunc getFunc = cast(PluginGetFunc)GetProcAddress(hModule, "GetPlugin");
        if(initFunc is null || getFunc is null || deinitFunc is null)
        {
          throw New!RCException(format("Loading plugin '%s' failed because %s%s%s", pluginName, 
                                       (initFunc is null) ? "InitPlugin entry point not found " : "",
                                       (getFunc is null) ? "GetPlugin entry point not found " : "",
                                       (deinitFunc is null) ? "DeinitPlugin entry point not found " : ""));
        }

        if(!initFunc(g_pluginRegistry, null))
        {
          throw New!RCException(format("Initializing plugin '%s' failed", pluginName));
        }

        IPlugin newPlugin = getFunc();
        if(newPlugin is null)
        {
          throw New!RCException(format("Getting reloaded plugin '%s' failed", pluginName));
        }

        //First build the type info for the new plugin
        auto types = New!(Hashmap!(string, const(thMemberInfo)[], StringHashPolicy))();
        scope(exit) Delete(types);
        BuildPluginTypeInfo(newPlugin, types);

        //Now patch the roots
        ScanPair[10] oldRoots;
        ScanPair[10] newRoots;
        size_t numOldRoots = oldPlugin.GetScanRoots(oldRoots);
        size_t numNewRoots = newPlugin.GetScanRoots(newRoots);
        if(numOldRoots != numNewRoots)
        {
          throw New!RCException(format("Error reloading plugin '%s': number of roots does not match", pluginName));
        }

        for(size_t i=0; i<numOldRoots; i++)
        {
          //If the address is null its a pure type root, and not a global variable
          if( oldRoots[i].addr !is null)
          {
            if(oldRoots[i].type != newRoots[i].type)
            {
              asm { int 3; } //root type does not match
            }
            //Patch the root
            memcpy(newRoots[i].addr, oldRoots[i].addr, oldRoots[i].type.tsize);
          }
        }

        //Now patch all vptrs
        {
          auto context = PatchObjectsContext(types, oldPlugin);
          foreach(ref root; oldRoots[0..numOldRoots])
          {
            if(root.addr !is null)
            {
              void* p = *cast(void**)root.addr;
              if(p !is null)
                context.PatchObject(p, root.type);
            }
          }
        }

        m_loadedPlugins[pluginIndex].plugin = newPlugin;
      }

      struct PatchObjectsContext
      {
        Hashmap!(string, const(thMemberInfo)[], StringHashPolicy) types;
        Hashmap!(void*, bool, PointerHashPolicy) alreadyPatched;
        IPlugin plugin;

        this(Hashmap!(string, const(thMemberInfo)[], StringHashPolicy) types, IPlugin plugin)
        {
          this.types = types;
          this.plugin = plugin;
          alreadyPatched = New!(typeof(alreadyPatched))();
        }

        ~this()
        {
          Delete(alreadyPatched);
        }

        //returns the TypeInfo for the given address and TypeInfo object. For class instances a additional lookup has to be done.
        static const(TypeInfo) resolveType(void* addr, const TypeInfo type)
        {
          if(type.type != TypeInfo.Type.Class)
            return type;
          Object o = cast(Object)addr;
          return o.classinfo;
        }

        //casts a interface to an object
        static Object resolveInterface(void* addr)
        {
          auto pi = **cast(Interface***)addr;
          auto o = cast(Object)(addr - pi.offset);
          return o;
        }

        //Patches an object
        void PatchObject(void* addr, const TypeInfo type)
        {
          if(addr is null)
            return;
          if(!plugin.isInPluginMemory(addr))
            return;

          //Make sure to patch each address only once
          if(alreadyPatched.exists(addr))
            return;
          alreadyPatched[addr] = true;

          auto rttiInfo = getRttiInfo(type);
          if(type.type == TypeInfo.Type.Class)
          {
            string mangeledTypeName = rttiInfo[0].name;
            if(!types.exists(mangeledTypeName))
            {
              asm { int 3; } //type not found in type list
            }
            TypeInfo_Class newType = cast(TypeInfo_Class)cast(void*)(types[mangeledTypeName][0].type);
            debug writefln("Patching %s at %x", newType.GetName(), addr);
            //Patch the vtbl and the rest of the object header
            void[] initMem = newType.init;
            memcpy(addr, initMem.ptr, __traits(classInstanceSize, Object)); 

            //Now patch all the interface vtbls
            for(TypeInfo_Class cur = newType; cur !is null; cur = cur.base)
            {
              foreach(ref i; cur.interfaces)
              {
                *cast(void**)(addr + i.offset) = *cast(void**)(newType.init.ptr + i.offset);
              }
            }
          }
          else if(type.type == TypeInfo.Type.Interface)
          {
            auto o = resolveInterface(addr);
            if(o.classinfo !is null) //if the object has already been deleted the classinfo is null
              PatchObject(cast(void*)o, o.classinfo);
            return;
          }

          if(rttiInfo.length <= 1)
            return;

          foreach(ref info; rttiInfo[1..$])
          {
            auto plainType = unqualHelper(info.type);
            switch(plainType.type)
            {
              case TypeInfo.Type.Class:
              case TypeInfo.Type.Interface:
                {
                  void* p = *cast(void**)(addr + info.offset);
                  if(p !is null)
                    PatchObject(p, plainType);
                }
                break;
              case TypeInfo.Type.Struct:
                PatchObject(addr + info.offset, plainType);
                break;
              case TypeInfo.Type.Pointer:
                {
                  void* p = addr + info.offset;
                  if(p !is null)
                    PatchObject(*cast(void**)p, plainType.next);
                }
                break;
              case TypeInfo.Type.Array:
                {
                  auto elementType = unqualHelper(plainType.next);
                  immutable elementSize = elementType.tsize();
                  void[] array = *cast(void[]*)(addr + info.offset);

                  void* cur = array.ptr;
                  void* end = cur + (elementSize * array.length);
                  if(elementType.type == TypeInfo.Type.Class || elementType.type == TypeInfo.Type.Interface)
                  {
                    for(; cur < end; cur += elementSize)
                    {
                      void* p = *cast(void**)cur;
                      if(p !is null)
                        PatchObject(p, elementType);
                    }
                  }
                  else if(elementType.type == TypeInfo.Type.Pointer)
                  {
                    for(; cur < end; cur += elementSize)
                    {
                      void* p = *cast(void**)cur;
                      if(p !is null)
                        PatchObject(p, elementType.next);
                    }
                  }
                  else
                  {
                    for(; cur < end; cur += elementSize)
                    {
                      PatchObject(cur, elementType);
                    }
                  }
                }
                break;
              case TypeInfo.Type.StaticArray:
                {
                  auto t = cast(const(TypeInfo_StaticArray))cast(void*)plainType;
                  auto elementType = unqualHelper(plainType.next);
                  immutable elementSize = elementType.tsize();

                  void* cur = addr + info.offset;
                  void* end = cur + (t.len * elementSize);
                  if(elementType.type == TypeInfo.Type.Class || elementType.type == TypeInfo.Type.Interface)
                  {
                    for(; cur < end; cur += elementSize)
                    {
                      void* p = *cast(void**)cur;
                      if(p !is null)
                        PatchObject(p, elementType);
                    }
                  }
                  else if(elementType.type == TypeInfo.Type.Pointer)
                  {
                    for(; cur < end; cur += elementSize)
                    {
                      void* p = *cast(void**)cur;
                      if(p !is null)
                        PatchObject(p, elementType.next);
                    }
                  }
                  else
                  {
                    for(; cur < end; cur += elementSize)
                    {
                      PatchObject(cur, elementType);
                    }
                  }
                }
                break;
              default:
                //non-recursive type, nothing to do
                break;
            }
          }
        }
      }

      private final void BuildPluginTypeInfo(IPlugin plugin, Hashmap!(string, const(thMemberInfo)[], StringHashPolicy) types)
      {
          ScanPair[10] roots;
          size_t numRoots = plugin.GetScanRoots(roots);
          foreach(ref root; roots[0..numRoots])
          {
            auto rttiInfo = getRttiInfo(root.type);
            auto context = BuildTypeInfoContext(types);
            context.buildInfo(rttiInfo);
          }
      }

      static struct BuildTypeInfoContext
      {
        Hashmap!(string, const(thMemberInfo)[], StringHashPolicy) types;

        void buildInfo(const(thMemberInfo[]) rttiInfo)
        {
          if(rttiInfo.length > 0)
          {
            //avoid endless recursion
            if(types.exists(rttiInfo[0].name))
              return;
            types[rttiInfo[0].name] = rttiInfo;

            //iterate all members
            foreach(ref info; rttiInfo[1..$])
            {
              if(info.next !is null)
                buildInfo(*info.next);
              else
              {
                auto tt = info.type.type;
                //For compond types use the next type
                if(tt == TypeInfo.Type.Array || tt == TypeInfo.Type.StaticArray || tt == TypeInfo.Type.Pointer)
                {
                  buildInfo(getRttiInfo(info.type.next));
                }
                else
                {
                  buildInfo(getRttiInfo(info.type));
                }
              }
            }
          }
        }
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

        void serialize(void* addr, const(char)[] name, const TypeInfo type, const(thMemberInfo[])* fallback = null)
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
              serializeStruct(addr,name,plainType,fallback);
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
          auto rttiInfo = getRttiInfo(type);
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
            serialize(addr + info.offset, info.name, info.type, info.next);
          }
          depth--;
          stream.format("\n%s}", spaces[0..depth*2]);
        }

        void serializeStruct(void* addr, const(char)[] name, const TypeInfo type, const(thMemberInfo[])* fallback)
        {
          auto rttiInfo = getRttiInfo(type);
          if(rttiInfo.length == 0 && fallback !is null)
            rttiInfo = *fallback;
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
            serialize(addr + info.offset, info.name, info.type, info.next);
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

  bool IsDThread(uint id)
  {
    return (thread_findByAddr(id) !is null);
  }

  shared static this()
  {
    g_pluginRegistry = New!PluginRegistry();
    g_pluginRegistry.AddValue("StdAllocator", cast(void*)cast(IAdvancedAllocator)(StdAllocator.globalInstance));
    g_pluginRegistry.AddValue("thBase.plugin.IsDThread", cast(void*)&IsDThread);
  }

  shared static ~this()
  {
    Delete(g_pluginRegistry);
  }
}