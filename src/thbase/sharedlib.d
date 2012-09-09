module thBase.sharedlib;

version(Windows){
	public import std.c.windows.windows;
}

version(linux){
	public import std.c.linux.linux;
}

public import thBase.constref;
public import core.runtime;

public import thBase.metatools;
public import std.traits;
public import thBase.string;

string generateDllCode(T)(string function(string name) func){
	string result = "";
	foreach(m;__traits(allMembers,T)){
		static if( !is(typeof(__traits(getMember,T,m)) == function) && m[0..2] != "__" ){
			static if(__traits(compiles, std.traits.isFunctionPointer!(__traits(getMember,T,m))) && std.traits.isFunctionPointer!(__traits(getMember,T,m)) )
      {
        result ~= func(m) ~ "\n";
      }
		}
	}
	return result;
}

mixin template SharedLib() {
private:
	version(Windows){
		alias HMODULE handle_t;
	}
	
	version(linux){
		alias void* handle_t;
	}
	
	static handle_t m_Handle = null;
	static bool m_IsLoaded = false;
	static string m_LibName;
	
	static void LoadImpl(string windowsName, string linuxName)
		in 
		{
			version(Windows){
				assert(windowsName !is null);
			}
			version(linux){
				assert(linuxName !is null);
			}
		}
		body 
		{
			version(Windows){
				m_LibName = windowsName;
				//m_Handle = cast(handle_t)Runtime.loadLibrary(m_LibName);
				m_Handle = LoadLibraryA(toCString(m_LibName));
			}
			version(linux){
				m_LibName = linuxName;
				m_Handle = dlopen(toCString(m_LibName),RTLD_NOW);
			}
			
			if(m_Handle != null){
				m_IsLoaded = true;
			}
			else {
				string error = "Couldn't load '" ~ m_LibName ~ "'";
				version(linux){
					char* extended = dlerror();
					if(extended !is null)
						error ~= "\nExtended Information: " ~ std.conv.to!string(extended);
				}
				throw new Exception(error);
			}
		}
		
	static void* GetProc(string procName)
		in {
			assert(procName !is null);
		}
		body {
			version(Windows){
				void *proc = std.c.windows.windows.GetProcAddress(m_Handle,toCString(procName));
				if(proc is null){
					throw new Exception("Couldn't find '" ~ procName ~ "' inside '" ~ m_LibName ~ "'");
				}
				return proc;
			}
			version(linux){
				void *proc = dlsym(m_Handle,toCString(procName));
				if(proc is null){
					char* error = dlerror();
					string message = "Couldn't find '" ~ procName ~ "' inside '" ~ m_LibName ~ "'";
					if(error !is null){
						message ~= "\nExtended Information: " ~ std.conv.to!string(error);
					}
					throw new Exception(message);
				}
				return proc;
			}
			assert(0,"Not implemented on this platform");
		}
	
public:
	static void Unload(){
		if(m_IsLoaded){
			m_IsLoaded = false;
			version(Windows){
				//Runtime.unloadLibrary(m_Handle);
				FreeLibrary(m_Handle);
			}
			version(linux){
				dlclose(m_Handle);
			}
		}
	}
	
};
