module thBase.directory;

import core.sys.windows.windows;
import core.stdc.stdlib;
import thBase.windows;

class DirectoryWatcher
{
  private:
    HANDLE m_directoryHandle;
    HANDLE m_completionPort;
    void[] m_buffer;
    WatchSubdirs m_watchSubdirs;
    DWORD m_filter;
    OVERLAPPED m_overlapped;

  public:
    enum Watch : uint
    {
      Reads =  1 << 0,
      Writes = 1 << 1
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

    this(const(char)[] path, WatchSubdirs watchSubdirs)
    {
      m_watchSubdirs = watchSubdirs;
      //TODO do filter

      mixin(stackCString("path", "cstrPath"));
      m_directoryHandle = CreateFileA(
                 cstrPath.ptr,					// pointer to the file name
                 FILE_LIST_DIRECTORY,                // access (read/write) mode
                 FILE_SHARE_READ						// share mode
                 | FILE_SHARE_WRITE
                 | FILE_SHARE_DELETE,
                 NULL,                               // security descriptor
                 OPEN_EXISTING,                      // how to create
                 FILE_FLAG_BACKUP_SEMANTICS			// file attributes
                 | FILE_FLAG_OVERLAPPED,
                 NULL); 
      if(m_directoryHandle == INVALID_HANDLE_VALUE)
      {
        throw New!RCException(format("Couldn't open directory '%s'. Maybe it does not exist?", path));
      }

      m_completionPort = CreateIoCompletionPort(m_directoryHandle, null, 0, 1);
      if(m_completionPort == INVALID_HANDLE_VALUE)
      {
        throw New!RCException(format("Couldn't create io completion port for directory '%s'", path));
      }

      m_buffer = NewArray!void(4096); //4kb buffer
      DoRead();
    }

    private final DoRead()
    {
      memset(&m_overlapped, 0, m_overlapped.sizeof);
      ReadDirectoryChangesW(m_directoryHandle, m_buffer.ptr, m_buffer.length, (m_watchSubdirs == WatchSubdirs.Yes),
                            m_filter, null, &m_overlapped, null);
    }

    final void EnumerateChanges(scope void function(const(char)[] filename, Action action) func)
    {
      OVERLAPPED* lpOverlapped;
      uint numberOfBytes;
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
        do
        {
          //TODO convert wchar[] to char[]
          WCHAR[] directory = info.FileName.ptr[0..info.FileNameLength];

        }
        while(info.NextEntryOffset != 0);
      }
    }
}