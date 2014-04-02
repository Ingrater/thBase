module thBase.directx;

import core.sys.windows.windows;
import std.c.windows.com;
import thBase.casts;

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