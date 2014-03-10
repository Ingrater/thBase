module thBase.directx;

void ReleaseAndNull(T)(ref T ptr)
{
  if(ptr !is null)
  {
    ptr.Release();
    ptr = null;
  }
}