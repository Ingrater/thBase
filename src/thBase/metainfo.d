module thBase.metainfo;

import std.traits;

struct MetaAttribute {}
alias MetaAttribute XmlIgnoreAll;
alias MetaAttribute XmlIgnore;
alias MetaAttribute XmlSerialize;
alias MetaAttribute XmlOptional;

template isMetaAttribute(T)
{
  static if(is(T == MetaAttribute))
    enum bool isMetaAttribute = true;
  else
    enum bool isMetaAttribute = false;
}

private string genAttributes(ATS...)(){
	string decl = "";
	foreach(i,A;ATS){
		static assert(isMetaAttribute!A, "All additional paramaters have to be MetaAttributes, type is " ~ A.stringof); 
		decl ~= "enum " ~ A.stringof ~ " MetaInfo"~(i+'0')~" = 0;";
	}
	return decl;
}

struct meta(T,ATS...){
	mixin(genAttributes!(ATS));
	T value;
	alias value this;
	
	this(T v){
		this.value = v;
	}
	
	T XmlGetValue(){
		return this.value;
	}
	
	void XmlSetValue(T value){
		this.value = value;
	}
}

bool HasMetaAttribute(T,M)(){
	static if(is(T == struct) || is(T == class)){
		foreach(m;__traits(allMembers,T)){
			static if(m.length > 8 && m[0..8] == "MetaInfo"){
				static if(is(typeof(__traits(getMember,T,m)) == M))
					return true;
			}
		}
	}
	return false;
}