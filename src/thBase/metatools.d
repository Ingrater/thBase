module thBase.metatools;

public import std.traits;

/**
 * resolves to true if the given type is a class, false otherwise
 */
template isClass(T){
	static if( is(T == class) )
		enum bool isClass = true;
	else
		enum bool isClass = false;
}

unittest {
	class cfoo {}
	struct sfoo {}
	interface ifoo {}
	static assert(isClass!(cfoo) == true);
	static assert(isClass!(sfoo) == false);
	static assert(isClass!(ifoo) == false);
	static assert(isClass!(int) == false);
}

/**
 * resolves to true if the given type is a interface, false otherwise
 */
template isInterface(T){
	static if( is (T == interface) )
		enum bool isInterface = true;
	else
		enum bool isInterface = false;
}

unittest {
	class cfoo {}
	struct sfoo {}
	interface ifoo {}
	static assert(isInterface!(cfoo) == false);
	static assert(isInterface!(sfoo) == false);
	static assert(isInterface!(ifoo) == true);
	static assert(isInterface!(int) == false);
}

/**
 * resolves to true if the given type is a delegate false otherwise
 */
template isDelegate(T){
	static if( is( T == delegate) )
		enum bool isDelegate = true;
	else
		enum bool isDelegate = false;
}

unittest {
	alias void delegate() dg;
	static assert(isDelegate!(int) == false);
	static assert(isDelegate!(void delegate()) == true);
	static assert(isDelegate!(dg) == true);
}

/**
 * resolves to true if it would be good for performance to use a reference when passing type T
 * false otherwise
 */ 
template useConstRef(T){
	static if(isClass!(T) || 
	          isInterface!(T) || 
	          isPointer!(T) ||
	          __traits(isRef,T) ||
	          isDelegate!(OriginalType!T) ||
	          T.sizeof <= (void*).sizeof ||
	          isNumeric!(T) )
		enum bool useConstRef = false;
	else
		enum bool useConstRef = true;
}

unittest {
	class cfoo {}
	struct sfoo { float f; }
	struct sfoo2 { float[5] f; }
	interface ifoo {}
	alias void delegate() dg;
	static assert(useConstRef!(cfoo) == false);
	static assert(useConstRef!(sfoo) == false);
	static assert(useConstRef!(sfoo2) == true);
	static assert(useConstRef!(ifoo) == false);
	static assert(useConstRef!(float) == false);
	static assert(useConstRef!(double) == false);
	static assert(useConstRef!(int*) == false);
	static assert(useConstRef!(dg) == false);
}

/**
 * resolves to true, if the given type is a typedef, false otherwise
 */
template isTypedef(T...){
	static if(T.length == 1)
		static if(is(T[0] == typedef) )
			enum bool isTypedef = true;
		else
			enum bool isTypedef = false;
	else
		enum bool isTypedef = false;
}

/**
 * removes the const from a type if any
 * const(T) -> T
 * T -> T
 */
template StripConst(T){
	static if(is(T V : const(V)))
		alias V StripConst;
	else
		alias T StripConst;
}
	
unittest {
	static assert(is(int == StripConst!(int)));
	static assert(is(int == StripConst!(const(int))));
}

struct Type2Type(T){
	alias T OriginalType;
}

struct Int2Type(T){
	enum T value = T.init;
}

template staticError(string STR){
	static assert(0,STR);
}