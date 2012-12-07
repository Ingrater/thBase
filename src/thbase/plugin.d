module thBase.plugin;

import thBase.container.hashmap;
import thBase.format;
import thBase.logging;
import core.sys.windows.windows;
import core.allocator;
import core.sync.mutex;

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
}

interface IPluginRegistry
{
  void* GetValue(string key);
}

extern(C)
{
  alias bool function(IPluginRegistry) PluginInitFunc;
  alias IPlugin function() PluginGetFunc;
}

version(Plugin)
{
  __gshared IPluginRegistry g_pluginRegistry;
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
    IAdvancedAllocator stdAllocator = cast(IAdvancedAllocator)g_pluginRegistry.GetValue("StdAllocator");
    g_pluginAllocator = AllocatorNew!PluginTrackingAllocator(stdAllocator, stdAllocator);

    // redirect all the allocations
    StdAllocator.globalInstance.OnAllocateMemoryCallback = &g_pluginAllocator.OnAllocateMemory;
    StdAllocator.globalInstance.OnFreeMemoryCallback = &g_pluginAllocator.OnFreeMemory;
    StdAllocator.globalInstance.OnReallocateMemoryCallback = &g_pluginAllocator.OnReallocateMemory;
  }
}
else
{
  class PluginRegistry : IPluginRegistry
  {
    private:
      composite!(Hashmap!(string, void*)) m_storage;

    public:
      this()
      {
        m_storage = typeof(m_storage)();
        m_storage.construct();
      }

      ~this()
      {
      }

      final void AddValue(string key, void* value)
      {
        m_storage[key] = value;
      }

      override void* GetValue(string key)
      {
        void* result = null;
        m_storage.ifExists(key, (ref v){ result = v; });
        return result;
      }

      final IPlugin LoadPlugin(string pluginName)
      {
        char[256] fileName;
        size_t fileNameLength = formatStatic(fileName, "%s%s%c", pluginName, ".dll", '\0');
        HMODULE hModule = LoadLibraryA(fileName.ptr);
        if(hModule is null)
        {
          logFatalError("Could not load plugin '%s'", fileName[0..fileNameLength-1]);
          return null;
        }

        PluginInitFunc initFunc = cast(PluginInitFunc)GetProcAddress(hModule, "InitPlugin");
        PluginGetFunc getFunc = cast(PluginGetFunc)GetProcAddress(hModule, "GetPlugin");
        if(initFunc is null || getFunc is null)
        {
          logFatalError("Loading plugin '%s' failed because %s%s", fileName[0..fileNameLength-1], 
                        (initFunc is null) ? "InitPlugin entry point not found" : "",
                        (getFunc is null) ? "GetPlugin entry point not found" : "");
          return null;
        }

        if(!initFunc(g_pluginRegistry))
        {
          logFatalError("Initializing plugin '%s' failed", fileName[0..fileNameLength-1]);
          return null;
        }

        IPlugin plugin = getFunc();
        if(plugin is null)
        {
          logFatalError("Initializing plugin '%s' failed, no plugin interface returned", fileName[0..fileNameLength-1]);
        }

        return plugin;
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