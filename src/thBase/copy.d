module thBase.copy;

import thBase.traits;

template isFunction(T){
	static if(is(T == function))
		enum bool isFunction = true;
	else
		enum bool isFunction = false;
}

void shallowCopyFrom(T)(T to, T from)
{
  foreach(m; __traits(allMembers, T))
  {
    pragma(msg, "member " ~ m);
    static if(m.length < 2 || m[0..2] != "__")
    {
      static if(__traits(compiles,typeof(__traits(getMember, T, m))))
      {
        static if(!isFunction!(typeof(__traits(getMember, to, m))))
        {
          pragma(msg, "copying " ~ m);
          __traits(getMember, to) = __traits(getMember, from);
        }
      }
      else
      {
        pragma(msg, "not accessible " ~ m);
      }
    }
  }
}