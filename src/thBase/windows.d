module thBase.windows;

import core.sys.windows.windows;

enum
{
  CP_ACP                   = 0,
  CP_OEMCP                 = 1,
  CP_MACCP                 = 2,
  CP_THREAD_ACP            = 3,
  CP_SYMBOL                = 42,
  CP_UTF7                  = 65000,
  CP_UTF8                  = 65001
}

struct FILE_NOTIFY_INFORMATION {
  DWORD NextEntryOffset;
  DWORD Action;
  DWORD FileNameLength;
  WCHAR FileName[1];
}

extern(Windows)
{
  alias VOID function(DWORD dwErrorCode, DWORD dwNumberOfBytesTransfered, OVERLAPPED* lpOverlapped) LPOVERLAPPED_COMPLETION_ROUTINE;
  BOOL ReadDirectoryChangesW(HANDLE hDirectory, LPVOID lpBuffer, DWORD nBufferLength, BOOL bWatchSubtree,
                             DWORD dwNotifyFilter, DWORD* lpBytesReturned, OVERLAPPED* lpOverlapped, LPOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine);
  HANDLE CreateIoCompletionPort(HANDLE FileHandle, HANDLE ExistingCompletionPort, ULONG_PTR CompletionKey, DWORD NumberOfConcurrentThreads);
  BOOL GetQueuedCompletionStatus(HANDLE CompletionPort, DWORD* lpNumberOfBytes, PULONG_PTR lpCompletionKey, OVERLAPPED** lpOverlapped, DWORD dwMilliseconds);
  BOOL CancelIo(HANDLE hFile);
}