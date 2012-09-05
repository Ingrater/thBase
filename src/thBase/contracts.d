module thBase.contracts;
import core.refcounted;

void enforce(bool condition, rcstring message)
{
  if(!condition)
  {
    debug {
      asm { int 3; }
    }
    throw New!RCException(message);
  }
}