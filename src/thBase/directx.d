module thBase.directx;

import core.sys.windows.windows;
import std.c.windows.com;
import thBase.casts;
import thBase.singleton;

void ReleaseAndNull(T)(ref T ptr)
{
  if(ptr !is null)
  {
    ptr.Release();
    ptr = null;
  }
}

struct ComRef(T)
{
  T m_ref;

  alias m_ref this;

  this(T ptr)
  {
    m_ref = ptr;
    if(m_ref !is null)
      m_ref.AddRef();
  }

  this(this)
  {
    if(m_ref !is null)
      m_ref.AddRef();
  }

  ~this()
  {
    if(m_ref !is null)
      m_ref.Release();
  }

  void opAssign(ref ComRef rh)
  {
    if(m_ref is rh.m_ref)
      return;
    if(m_ref !is null)
      m_ref.Release();
    m_ref = rh.m_ref;
    if(m_ref !is null)
      rh.AddRef();
  }

  void opAssign(ComRef rh)
  {
    if(m_ref !is null)
      m_ref.Release();
    m_ref = rh.m_ref;
    rh.m_ref = null;
  }

  void opAssign(typeof(null))
  {
    if(m_ref !is null)
    {
      m_ref.Release();
      m_ref = null;
    }
  }

  static assert(ComRef!T.sizeof == (void*).sizeof);
}

ComRef!T InitiallyUnowned(T)(T obj)
{
  ComRef!T result;
  result.m_ref = obj;
  return result;
}

interface ID3DUserDefinedAnnotation : IUnknown
{
extern(Windows):
  INT BeginEvent( LPCWSTR Name);   
  INT EndEvent();    
  void SetMarker( LPCWSTR Name);  
  BOOL GetStatus();   
}

extern(Windows)
{
  alias int function() D3DPERF_EndEvent_Func;
  alias int function(DWORD, LPCWSTR) D3DPERF_BeginEvent_Func;
}

__gshared D3DPERF_EndEvent_Func D3DPREF_EndEvent;
__gshared D3DPERF_BeginEvent_Func D3DPREF_BeginEvent;
__gshared bool g_debugMarkerActive = false;

ID3DUserDefinedAnnotation g_userDefinedAnnotation;

void InitDebugMarker(T)(T context)
{
  const GUID IDD_ID3DUserDefinedAnnotation = { 0xb2daad8b, 0x03d4, 0x4dbf, [ 0x95, 0xeb,  0x32,  0xab,  0x4b,  0x63,  0xd0,  0xab ] };
  context.QueryInterface(&IDD_ID3DUserDefinedAnnotation, cast(void**)&g_userDefinedAnnotation);
  if(g_userDefinedAnnotation is null || g_userDefinedAnnotation.GetStatus() == 0)
  {
    g_userDefinedAnnotation = null;
    HMODULE pModule = LoadLibraryA("d3d9.dll".ptr);
    D3DPREF_BeginEvent = cast(D3DPERF_BeginEvent_Func)GetProcAddress(pModule, "D3DPERF_BeginEvent");
    D3DPREF_EndEvent = cast(D3DPERF_EndEvent_Func)GetProcAddress(pModule, "D3DPERF_EndEvent");
    if(D3DPREF_BeginEvent !is null && D3DPREF_EndEvent !is null)
      g_debugMarkerActive = true;
  }
  if(g_userDefinedAnnotation !is null)
  {
    g_debugMarkerActive = true;
  }
}

struct DebugMarker
{
  @disable this();
  this(const(char)[] name)
  {
    debug
    {
      if(g_debugMarkerActive)
      {
        wchar[1024] buffer;
        auto charsWritten = MultiByteToWideChar(CP_UTF8, 0, name.ptr, int_cast!int(name.length), buffer.ptr, int_cast!int(buffer.length) - 1);
        buffer[charsWritten] = '\0';
        if(g_userDefinedAnnotation !is null)
          g_userDefinedAnnotation.BeginEvent(buffer.ptr);
        else
          D3DPREF_BeginEvent(0x0000FF00, buffer.ptr);
      }
    }
  }

  ~this()
  {
    debug
    {
      if(g_debugMarkerActive)
      {
        if(g_userDefinedAnnotation !is null)
          g_userDefinedAnnotation.EndEvent();
        else
          D3DPREF_EndEvent();
      }
    }
  }
}

/// \brief
///   A helper class that helps to find leaks of reference counted com objects which inherit from IUnknown
class ComLeakFinder : Singleton!GlobalManager
{
private:
  extern(Windows)
  {
    alias ULONG function(IUnknown self) AddRefFunc;
    alias ULONG function(IUnknown self) ReleaseFunc;
  }

  enum TraceType : ushort
  {
    initial,
    addRef,
    release
  };

  struct trace
  {
    ulong addresses[16];
    ushort numAddresses;
    ushort refCount;
    TraceType type;
  };

  struct InterfaceData
  {
    void** oldVptr;
    void** newVptr;
    composite!(Vector!trace) traces;
    uint refCount;
    AddRefFunc AddRef;
    ReleaseFunc Release;

    this(void** oldVptr, void** newVptr, AddRefFunc addRef, ReleaseFunc release)
    {
      this.oldVptr = oldVptr;
      this.newVptr = newVptr;
      refCount = 1;
      AddREf = addRef;
      Release = release;
    }
  }

  struct Unknown
  {
    void** vptr;
  }

  composite!(Hashmap!(IUnknown, InterfaceData)) m_trackedInstances;
  composite!Mutex m_mutex;

  extern(Windows) static ULONG hookAddRef(IUnknown self)
  {
    auto inst = ComLeakFinder.instance();
    auto lock = ScopedLock!Mutex(inst.m_mutex);

    assert(inst.m_trackedInstances.exists(self), "object is not tracked");

    auto info = &inst.m_trackedInstances[self];
    info.refCount++;

    info.traces.resize(info.traces.length() + 1);
    auto t = &info.traces[info.traces.length() - 1];
    t.refCount = info.refCount;
    t.numAddresses = (uint16)StackWalker.getCallstack(1, ArrayPtr<StackWalker.address_t>(t.addresses));
    t.type = TraceType.addRef;

    return info.AddRef(self);
  }

  extern(Windows) static ULONG hookRelease(IUnknown self)
  {
    auto inst = ComLeakFinder.instance();
    auto lock = ScopedLock!Mutex(inst.m_mutex);

    assert(inst.m_trackedInstances.exists(self), "object is not tracked");

    auto info = &inst.m_trackedInstances[self];
    info.refCount--;

    info.traces.resize(info.traces.length() + 1);
    auto t = &info.traces[info.traces.length() - 1];
    t.refCount = info.refCount;
    t.numAddresses = (uint16)StackWalker.getCallstack(1, ArrayPtr<StackWalker.address_t>(t.addresses));
    t.type = TraceType.release;

    if(info.refCount == 0)
    {
      auto h = cast(Unknown*)cast(void*)(self);
      delete[] h.vptr;
      h.vptr = info.oldVptr;
      inst.m_trackedInstances.remove(self);
    }
    return info.Release(self);
  }
public:

  this()
  {
  }

  /// \brief Destructors. Writes a ComLeaks.log file if leaks are found.
  ~this()
  {
    auto lock = ScopedLock!Mutex(m_mutex);

    if(m_trackedInstances.count() > 0)
    {
      FILE* f = fopen("ComLeaks.log", "w");
      foreach(ref k, ref v; m_trackedInstances)
      {
        fprintf(f, "leaked instance 0x%x\n", k);
        foreach(ref t; v.traces)
        {
          fprintf(f, "\nTrace: ");
          switch(t.type)
          {
            case TraceType.initial:
              fprintf(f, "initial\n");
              break;
            case TraceType.addRef:
              fprintf(f, "AddRef\n");
              break;
            case TraceType.release:
              fprintf(f, "Release\n");
              break;
          }
          #define LINE_LENGTH 256
          char outBuf[LINE_LENGTH * GEP_ARRAY_SIZE(t.addresses)];
          StackWalker.resolveCallstack(ArrayPtr<StackWalker.address_t>(t.addresses, t.numAddresses), outBuf, LINE_LENGTH);
          for(uint16 i=0; i<t.numAddresses; i++)
          {
            fprintf(f, "%s\n", outBuf + (LINE_LENGTH * i));
          }
        }
        delete[] v.newVptr;
        fprintf(f, "=========================================\n");
        fflush(f);
        ++kit;
        ++vit;
      }
      fclose(f);
    }
  }

  /// \brief adds the given object for tracking
  void trackComObject(IUnknown pObject)
  {
    auto lock = ScopedLock!Mutex(m_mutex);

    // Do not add it twice
    if(m_trackedInstances.exists(pObject))
      return;

    //Check if the reference count is 1
    pObject.AddRef();
    ULONG count = pObject.Release();
    assert(count == 1, "reference count of com object is not 1", count);

    auto h = reinterpret_cast<Unknown*>(pObject);

    // copy the vtable
    size_t vtableSize = 0;
    while(h.vptr[vtableSize] != nullptr && vtableSize < 64)
    {
      vtableSize++;
    }
    assert(vtableSize >= 3);
    void** newVtable = new void*[vtableSize];
    memcpy(newVtable, h.vptr, sizeof(void*) * vtableSize);

    //patch the methods
    newVtable[1] = &hookAddRef;
    newVtable[2] = &hookRelease;

    auto& info = m_trackedInstances[pObject] = InterfaceData(h.vptr,
                                                             newVtable,
                                                             reinterpret_cast<AddRefFunc>(h.vptr[1]),
                                                             reinterpret_cast<ReleaseFunc>(h.vptr[2]));
    h.vptr = newVtable;

    // do the stacktrace
    info.traces.resize(1);
    auto& t = info.traces[0];
    t.numAddresses = (uint16)StackWalker.getCallstack(0, ArrayPtr<StackWalker.address_t>(t.addresses));
    t.refCount = info.refCount;
    t.type = TraceType.initial;
  }
}