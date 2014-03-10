module thBase.copy;

import thBase.traits;

void shallowCopyFrom(T)(T to, T from)
{
  foreach(m; __traits(allMembers, T))
  {
    static if(m.length < 2 || m[0..2] != "__"){
      static if(__traits(compiles,typeof(__traits(getMember, MT, m))))
      {
        static if(!isFunction!(typeof(__traits(getMember, to, m))))
        {
          __traits(getMember, to) = __traits(getMember, from);
        }
      }
    }
  }
}