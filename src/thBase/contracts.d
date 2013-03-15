module thBase.contracts;
import core.refcounted;

void enforce(bool condition, rcstring message)
{
  if(!condition)
  {
    debug {
      version(GNU)
        asm { "int $0x3"; }
      else
        asm { int 3; }
    }
    throw New!RCException(message);
  }
}