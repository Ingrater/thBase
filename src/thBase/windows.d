module thBase.windows;

import core.sys.windows.windows;
import thBase.casts;

/*enum
{
  CP_ACP                   = 0,
  CP_OEMCP                 = 1,
  CP_MACCP                 = 2,
  CP_THREAD_ACP            = 3,
  CP_SYMBOL                = 42,
  CP_UTF7                  = 65000,
  CP_UTF8                  = 65001
}*/

struct FILE_NOTIFY_INFORMATION {
  DWORD NextEntryOffset;
  DWORD Action;
  DWORD FileNameLength;
  WCHAR FileName[1];
}

struct RAWINPUTDEVICE {
  USHORT usUsagePage;
  USHORT usUsage;
  DWORD  dwFlags;
  HWND   hwndTarget;
}

struct RAWINPUTHEADER {
  DWORD  dwType;
  DWORD  dwSize;
  HANDLE hDevice;
  WPARAM wParam;
}

struct RAWMOUSE {
  /*
  * Indicator flags.
  */
  USHORT usFlags;

  /*
  * The transition state of the mouse buttons.
  */
  union {
    ULONG ulButtons;
    struct  {
      USHORT  usButtonFlags;
      USHORT  usButtonData;
    };
  };


  /*
  * The raw state of the mouse buttons.
  */
  ULONG ulRawButtons;

  /*
  * The signed relative or absolute motion in the X direction.
  */
  LONG lLastX;

  /*
  * The signed relative or absolute motion in the Y direction.
  */
  LONG lLastY;

  /*
  * Device-specific additional information for the event.
  */
  ULONG ulExtraInformation;
}

struct RAWKEYBOARD 


{
  /*
  * The "make" scan code (key depression).
  */
  USHORT MakeCode;

  /*
  * The flags field indicates a "break" (key release) and other
  * miscellaneous scan code information defined in ntddkbd.h.
  */
  USHORT Flags;

  USHORT Reserved;

  /*
  * Windows message compatible information
  */
  USHORT VKey;
  UINT   Message;

  /*
  * Device-specific additional information for the event.
  */
  ULONG ExtraInformation;
}

struct RAWHID {
  DWORD dwSizeHid;    // byte size of each report
  DWORD dwCount;      // number of input packed
  BYTE bRawData[1];
}

struct RAWINPUT {
  RAWINPUTHEADER header;
  union data_t
  {
    RAWMOUSE    mouse;
    RAWKEYBOARD keyboard;
    RAWHID      hid;
  } 
  data_t data;
}

enum {
  WM_INPUT = 0x00FF,
  RID_INPUT =             0x10000003,
  RID_HEADER =             0x10000005,
  RIM_TYPEMOUSE   =    0,
  RIM_TYPEKEYBOARD =   1,
  RIM_TYPEHID       =  2,
}

alias HRAWINPUT = void*;

extern(Windows)
{
  alias VOID function(DWORD dwErrorCode, DWORD dwNumberOfBytesTransfered, OVERLAPPED* lpOverlapped) LPOVERLAPPED_COMPLETION_ROUTINE;
  BOOL ReadDirectoryChangesW(HANDLE hDirectory, LPVOID lpBuffer, DWORD nBufferLength, BOOL bWatchSubtree,
                             DWORD dwNotifyFilter, DWORD* lpBytesReturned, OVERLAPPED* lpOverlapped, LPOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine);
  HANDLE CreateIoCompletionPort(HANDLE FileHandle, HANDLE ExistingCompletionPort, ULONG_PTR CompletionKey, DWORD NumberOfConcurrentThreads);
  BOOL GetQueuedCompletionStatus(HANDLE CompletionPort, DWORD* lpNumberOfBytes, PULONG_PTR lpCompletionKey, OVERLAPPED** lpOverlapped, DWORD dwMilliseconds);
  BOOL CancelIo(HANDLE hFile);
  void OutputDebugStringA(LPCTSTR lpOutputStr);
  BOOL SetDllDirectoryA(LPCTSTR lpPathName);
  BOOL IsDebuggerPresent();
  BOOL SetEnvironmentVariableA(LPCTSTR lpName, LPCTSTR lpValue);
  BOOL RegisterRawInputDevices(RAWINPUTDEVICE* pRawInputDevices, UINT uiNumDevices, UINT cbSize );
  UINT GetRawInputData(HRAWINPUT hRawInput, UINT uiCommand, LPVOID pData, PUINT pcbSize, UINT cbSizeHeader);
}

size_t formatLastError(char[] buffer)
{
  DWORD lastError = GetLastError();
  return int_cast!size_t(FormatMessageA(
                                       FORMAT_MESSAGE_FROM_SYSTEM |
                                       FORMAT_MESSAGE_IGNORE_INSERTS,
                                       null,
                                       lastError,
                                       MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
                                       buffer.ptr,
                                       int_cast!uint(buffer.length), 
                                       null )
                        );
}