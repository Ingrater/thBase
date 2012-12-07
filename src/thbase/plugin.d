module thBase.plugin;

import thBase.container.hashmap;
import thBase.format;
import thBase.logging;
import core.sys.windows.windows;
import core.allocator;
import core.sync.mutex;

struct ScanPair
{
  void* addr;
  TypeInfo type;
}

interface IPlugin
{
  @property string name();
  size_t GetScanRoots(ScanPair[] roots);
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
  IPluginRegistry g_pluginRegistry;

  class PluginTrackingAllocator
  {
    private:
      Mutex m_mutex;

    public:
      this(IAllocator allocator)
      {

      }
  }

  void InitPluginSystem()
  {
    IAllocator stdAllocator = cast(IAllocator)g_pluginRegistry.GetValue("StdAllocator");

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
    g_pluginRegistry.AddValue("StdAllocator", cast(void*)cast(IAllocator)(StdAllocator.globalInstance));
  }

  shared static ~this()
  {
    Delete(g_pluginRegistry);
  }
}