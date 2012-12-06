module thBase.plugin;

import thBase.container.hashmap;
import thBase.format;
import core.sys.windows;

interface IPlugin
{
  @property string name();
}

interface IPluginRegistry
{
  void* GetValue(string key);
}

extern(C)
{
  alias void function(IPluginRegistry) PluginInitFunc;
}

version(Plugin)
{
  IPluginRegistry g_pluginRegistry;
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
        formatStatic(fileName, "%s%s%c", pluginName, ".dll", '\0');
        HMODULE hModule = LoadLibraryA(fileName.ptr);

        PluginInitFunc initFunc = cast(PluginInitFunc)GetProcAddress("InitPlugin");
      }
  }

  PluginRegistry g_pluginRegistry;

  shared static this()
  {
    g_pluginRegistry = New!PluginRegistry();
  }

  shared static ~this()
  {
    Delete(g_pluinRegistry);
  }
}