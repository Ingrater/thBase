module thBase.directory;

import core.sys.windows.windows;
import core.stdc.string;
import core.stdc.stdlib;

import thBase.windows;
import thBase.enumbitfield;
import thBase.string;
import thBase.format;

class DirectoryWatcher
{
  private:
    HANDLE m_directoryHandle;
    HANDLE m_completionPort;
    WatchSubdirs m_watchSubdirs;
    DWORD m_filter;
    OVERLAPPED m_overlapped;
    void[4096] m_buffer = void;

  public:
    enum Watch : uint
    {
      Reads =  1 << 0,
      Writes = 1 << 1,
      Creates = 1 << 2,
      Renames = 1 << 3
    }

    enum WatchSubdirs
    {
      No = 0,
      Yes = 1
    }

    enum Action
    {
      Added = FILE_ACTION_ADDED,
      Removed = FILE_ACTION_REMOVED,
      Modified = FILE_ACTION_MODIFIED,
      RenamedOldName = FILE_ACTION_RENAMED_OLD_NAME,
      RenamedNewName = FILE_ACTION_RENAMED_NEW_NAME
    }

    this(const(char)[] path, WatchSubdirs watchSubdirs, EnumBitfield!Watch watch)
    {
      m_watchSubdirs = watchSubdirs;
      m_filter = 0;
      if(watch.IsSet(Watch.Reads))
        m_filter |= FILE_NOTIFY_CHANGE_LAST_ACCESS;
      if(watch.IsSet(Watch.Writes))
        m_filter |= FILE_NOTIFY_CHANGE_LAST_WRITE;
      if(watch.IsSet(Watch.Creates))
        m_filter |= FILE_NOTIFY_CHANGE_CREATION;
      if(watch.IsSet(Watch.Renames))
        m_filter |= FILE_NOTIFY_CHANGE_FILE_NAME | FILE_NOTIFY_CHANGE_DIR_NAME;

      mixin(stackCString("path", "cstrPath"));
      m_directoryHandle = CreateFileA(
                 cstrPath.ptr,
                 FILE_LIST_DIRECTORY,               
                 FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                 null,                               
                 OPEN_EXISTING,                      
                 FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OVERLAPPED,
                 null); 
      if(m_directoryHandle == INVALID_HANDLE_VALUE)
      {
        throw New!RCException(format("Couldn't open directory '%s'. Maybe it does not exist?", path));
      }

      m_completionPort = CreateIoCompletionPort(m_directoryHandle, null, 0, 1);
      if(m_completionPort == INVALID_HANDLE_VALUE)
      {
        throw New!RCException(format("Couldn't create io completion port for directory '%s'", path));
      }

      DoRead();
    }

    ~this()
    {
      CancelIo(m_directoryHandle);
      CloseHandle(m_completionPort);
      CloseHandle(m_directoryHandle);
    }

    private final DoRead()
    {
      memset(&m_overlapped, 0, m_overlapped.sizeof);
      ReadDirectoryChangesW(m_directoryHandle, m_buffer.ptr, m_buffer.length, (m_watchSubdirs == WatchSubdirs.Yes),
                            m_filter, null, &m_overlapped, null);
    }

    final void EnumerateChanges(scope void delegate(const(char)[] filename, Action action) func)
    {
      OVERLAPPED* lpOverlapped;
      uint numberOfBytes;
      uint completionKey;
      if( GetQueuedCompletionStatus(m_completionPort, &numberOfBytes, &completionKey, &lpOverlapped, 0) != 0)
      {
        //Copy the buffer
        assert(numberOfBytes > 0);
        void[] buffer = alloca(numberOfBytes)[0..numberOfBytes];
        buffer[0..$] = m_buffer[0..numberOfBytes];

        //Reissue the read request
        DoRead();

        //Progress the messages
        auto info = cast(const(FILE_NOTIFY_INFORMATION)*)buffer.ptr;
        while(true)
        {
          const(WCHAR)[] directory = info.FileName.ptr[0..info.FileNameLength];
          int bytesNeeded = WideCharToMultiByte(CP_UTF8, 0, directory.ptr, directory.length, null, 0, null, null);
          if(bytesNeeded > 0)
          {
            char[] dir = (cast(char*)alloca(bytesNeeded))[0..bytesNeeded];
            WideCharToMultiByte(CP_UTF8, 0, directory.ptr, directory.length, dir.ptr, dir.length, null, null);
            func(dir, cast(Action)info.Action);
          }
          if(info.NextEntryOffset == 0)
            break;
          else
            info = cast(const(FILE_NOTIFY_INFORMATION)*)((cast(void*)info) + info.NextEntryOffset);
        }
      }
    }
}