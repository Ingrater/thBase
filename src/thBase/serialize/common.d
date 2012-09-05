module thBase.serialize.common;

import std.traits;
import core.traits;

template isFunction(T){
	static if(is(T == function))
		enum bool isFunction = true;
	else
		enum bool isFunction = false;
}

template NativeType(T){
	static if(is(T == int) || is(T == float) || is(T == double) || is(T == bool))
		enum bool NativeType = true;
	else 
		enum bool NativeType = false;
}

template RecursiveType(T){
	static if(is(T == struct) || is(T == class))
		enum bool RecursiveType = true;
	else
		enum bool RecursiveType = false;
}

template GetterType(T){
	alias ReturnType!(__traits(getMember,T,"XmlGetValue")) GetterType;
}

template SetterType(T){
	alias ParameterTypeTuple!(__traits(getMember,T,"XmlSetValue"))[0] SetterType;
}

template isValueType(T){
	static if(is(T == enum))
		enum bool isValueType = false;
	else static if(is(typeof(T) == function))
		enum bool isValueType = false;
	else
		enum bool isValueType = true;
}

template HasSetterGetter(T){
	static if(__traits(hasMember,T,"XmlGetValue")){
		static if(__traits(hasMember,T,"XmlSetValue")){
			static assert(ParameterTypeTuple!(__traits(getMember,T,"XmlSetValue")).length == 1,"XmlSetValue has to many arguments for " ~ T.stringof);
			static assert(is(SetterType!T == GetterType!T),"Type of XmlSetValue and XmlGetValue do not match for " ~ T.stringof);
			enum bool HasSetterGetter = true;
		}
		else 
			static assert(0,T.stringof ~ " has a XmlGetValue member nut no XmlSetValue memeber");
	}
	else {
		static if(__traits(hasMember,T,"XmlSetValue"))
			static assert(0,T.stringof ~ " has a XmlSetValue member but no XmlGetValue member");
		else
			enum bool HasSetterGetter = false;
	}
}

template ArrayType(T : U[], U){
	alias U ArrayType;
}

template IsSpecial(T)
{
  static if(IsRCArray!T)
  {
    enum bool IsSpecial = true;
  }
  else
    enum bool IsSpecial = false;
}