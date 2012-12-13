module thBase.windows;

import core.sys.windows.windows;

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
}