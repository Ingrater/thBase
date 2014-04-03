module thBase.directx;

import core.sys.windows.windows;
import core.sys.windows.stacktrace;
import std.c.windows.com;
import thBase.casts;
import thBase.singleton;
import thBase.container.vector;
import thBase.container.hashmap;
import core.sync.mutex;
import thBase.scoped;
import core.stdc.stdio;

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
  T m_ref = null;

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
    {
      m_ref.Release();
      m_ref = null;
    }
  }

  @disable void opAssign(ref const ComRef rh);

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

  @disable void Release();

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
    ReleaseAndNull(g_userDefinedAnnotation);
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

void DeinitDebugMarker()
{
  ReleaseAndNull(g_userDefinedAnnotation);
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
class ComLeakFinder : Singleton!ComLeakFinder
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
    Vector!trace m_traces;
    uint refCount;
    AddRefFunc AddRef;
    ReleaseFunc Release;

    this(void** oldVptr, void** newVptr, AddRefFunc addRef, ReleaseFunc release)
    {
      this.oldVptr = oldVptr;
      this.newVptr = newVptr;
      refCount = 1;
      AddRef = addRef;
      Release = release;
    }

    ~this()
    {
      Delete(m_traces);
    }

    Vector!trace traces()
    {
      if(m_traces is null)
        m_traces = New!(typeof(m_traces))();
      return m_traces;
    }
  }

  struct Unknown
  {
    void** vptr;
  }

  composite!(Hashmap!(IUnknown, InterfaceData)) m_trackedInstances;
  composite!Mutex m_mutex;
  uint m_addRefCalls;
  uint m_releaseCalls;
  uint m_initCalls;

  extern(Windows) static ULONG hookAddRef(IUnknown self)
  {
    auto inst = ComLeakFinder.instance();
    auto lock = ScopedLock!Mutex(inst.m_mutex);
    inst.m_addRefCalls++;

    assert(inst.m_trackedInstances.exists(self), "object is not tracked");

    auto info = &inst.m_trackedInstances[self];
    info.refCount++;

    info.traces.resize(info.traces.length() + 1);
    auto t = &info.traces[info.traces.length() - 1];
    t.refCount = int_cast!ushort(info.refCount);
    t.numAddresses = int_cast!ushort(StackTrace.trace(t.addresses, 1).length);
    t.type = TraceType.addRef;

    return info.AddRef(self);
  }

  extern(Windows) static ULONG hookRelease(IUnknown self)
  {
    auto inst = ComLeakFinder.instance();
    auto lock = ScopedLock!Mutex(inst.m_mutex);
    inst.m_releaseCalls++;

    assert(inst.m_trackedInstances.exists(self), "object is not tracked");

    auto info = &inst.m_trackedInstances[self];
    info.refCount--;

    if(info.refCount > 0)
    {
      info.traces.resize(info.traces.length() + 1);
      auto t = &info.traces[info.traces.length() - 1];
      t.refCount = int_cast!ushort(info.refCount);
      t.numAddresses = int_cast!ushort(StackTrace.trace(t.addresses, 1).length);
      t.type = TraceType.release;
    }

    auto releaseFunc = info.Release;
    if(info.refCount == 0)
    {
      auto h = cast(Unknown*)cast(void*)(self);
      Delete(h.vptr);
      h.vptr = info.oldVptr;
      inst.m_trackedInstances.remove(self);
    }
    return releaseFunc(self);
  }
public:

  this()
  {
    m_trackedInstances = typeof(m_trackedInstances)(defaultCtor);
    m_mutex = typeof(m_mutex)(defaultCtor);
  }

  /// \brief Destructors. Writes a ComLeaks.log file if leaks are found.
  ~this()
  {
    auto lock = ScopedLock!Mutex(m_mutex);

    if(m_trackedInstances.count() > 0)
    {
      FILE* f = fopen("ComLeaks.log", "w");
      fprintf(f, "init %d, AddRef %d, Release %d", m_initCalls, m_addRefCalls, m_releaseCalls);
      foreach(ref k, ref v; m_trackedInstances)
      {
        fprintf(f, "leaked instance 0x%x\n", k);
        foreach(ref t; v.traces)
        {
          fprintf(f, "\nRefcount %d Trace: ", t.refCount);
          final switch(t.type)
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
          rcstring[trace.addresses.length] buffer;
          auto frames = StackTrace.resolve(t.addresses, buffer);
          foreach(frame; frames)
          {
            fprintf(f, "%.*s\n", frame.length, frame.ptr);
          }
        }
        Delete(v.newVptr);
        fprintf(f, "=========================================\n");
        fflush(f);
      }
      fclose(f);
    }
  }

  /// \brief adds the given object for tracking
  void trackComObject(IUnknown pObject)
  {
    auto lock = ScopedLock!Mutex(m_mutex);
    m_initCalls++;

    // Do not add it twice
    if(m_trackedInstances.exists(pObject))
      return;

    //Check if the reference count is 1
    pObject.AddRef();
    ULONG count = pObject.Release();
    //assert(count == 1, "reference count of com object is not 1");

    auto h = cast(Unknown*)cast(void*)(pObject);

    // copy the vtable
    size_t vtableSize = 0;
    while(h.vptr[vtableSize] != null && vtableSize < 64)
    {
      vtableSize++;
    }
    assert(vtableSize >= 3);
    void** newVtable = NewArray!(void*)(vtableSize).ptr;
    memcpy(newVtable, h.vptr, (void*).sizeof * vtableSize);

    //patch the methods
    newVtable[1] = &hookAddRef;
    newVtable[2] = &hookRelease;

    m_trackedInstances[pObject] = InterfaceData(h.vptr, newVtable,
                                                cast(AddRefFunc)(h.vptr[1]),
                                                cast(ReleaseFunc)(h.vptr[2]));
    auto info = &m_trackedInstances[pObject];
    h.vptr = newVtable;

    // do the stacktrace
    info.traces.resize(1);
    auto t = &info.traces[0];
    t.numAddresses = int_cast!ushort(StackTrace.trace(t.addresses, 0).length);
    t.refCount = int_cast!ushort(info.refCount);
    t.type = TraceType.initial;
  }
}