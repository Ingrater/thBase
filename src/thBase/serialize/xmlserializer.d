module thBase.serialize.xmlserializer;

import core.refcounted;
import thBase.tinyxml;
public import thBase.serialize.common;
public import thBase.serialize.wrapper;
import std.traits, thBase.traits, core.traits;
import thBase.allocator;

class XmlSerializerBase {
public:
  enum IsOptional : bool
  {
    No = false,
    Yes = true
  }

	static void DoSerializeAttribute(int value, TiXmlElement pElement, TiXmlString name){
		pElement.SetAttribute(name,value);
	}
	
	static void DoSerializeAttribute(float value, TiXmlElement pElement, TiXmlString name){
		pElement.SetDoubleAttribute(name,value);
	}
	
	static void DoSerializeAttribute(double value, TiXmlElement pElement, TiXmlString name){
		pElement.SetDoubleAttribute(name,value);
	}
	
	static void DoSerializeAttribute(bool value, TiXmlElement pElement, TiXmlString name){
		if(value)
			pElement.SetAttribute(name, TiXmlString("true", IsStatic.Yes));
		else
			pElement.SetAttribute(name, TiXmlString("false", IsStatic.Yes));
	}

  static void ProcessNativeArrayMember(MT)(ref MT pValue, TiXmlNode pFather, IAllocator allocator)
  {
    TiXmlElement element = AllocatorNew!TiXmlElement(allocator, TiXmlString("el", IsStatic.Yes), allocator);
    pFather.LinkEndChild(element);
    DoSerializeAttribute(pValue, element, TiXmlString("value", IsStatic.Yes));
  }

  static void DoProcessMember(MT)(ref MT pValue, TiXmlNode pFather, string pName, IsOptional isOptional, IAllocator allocator)
  {
    static if(NativeType!(MT)){
      DoSerializeAttribute(pValue, pFather.ToElement(), TiXmlString(pName, IsStatic.Yes));
    }
    else static if(std.traits.isArray!(MT))
    {
      static assert(!is(MT == string), "serializing of strings is not supported, use rcstring instead");
      if(!isOptional || pValue.length > 0)
      {
        TiXmlElement element = AllocatorNew!TiXmlElement(allocator, TiXmlString(pName, IsStatic.Yes), allocator);
        pFather.LinkEndChild(element);
        element.SetAttribute(TiXmlString("size", IsStatic.Yes), cast(int)pValue.length);
        
        string name;
        alias AT = arrayType!MT;
        static if(NativeType!AT)
          name = AT.stringof;
        else static if (HasSetterGetter!AT && !NativeType!(GetterType!AT) && hasAttribute!(GetterType!AT, NiceName))
        {
          name = getAttribute!(GetterType!AT, NiceName).value;
        }
        else static if(hasAttribute!(AT, NiceName))
          name = getAttribute!(AT, NiceName).value;
        else
          name = AT.stringof;
          
        foreach(int i,ref v;pValue){
          static if(NativeType!(ArrayType!(MT)))
            ProcessNativeArrayMember(v, element, allocator);
          else
            DoProcessMember(v, element, name, IsOptional.No, allocator);
        }
      }
    }
    else static if(isRCArray!(MT)){
      static if(is(MT == rcstring))
      {
        if(!isOptional || pValue.length > 0)
        {
          TiXmlElement element = pFather.ToElement();
          element.SetAttribute(TiXmlString(pName, IsStatic.Yes), cast(TiXmlString)pValue);
        }
      }
      else
      {
        if(!isOptional || pValue.length > 0)
        {
          TiXmlElement element = AllocatorNew!TiXmlElement(allocator, TiXmlString(pName, IsStatic.Yes), allocator);
          pFather.LinkEndChild(element);
          element.SetAttribute(TiXmlString("size", IsStatic.Yes), cast(int)pValue.length);

          string name;
          alias AT = arrayType!MT;
          static if(NativeType!AT)
            name = AT.stringof;
          else static if (HasSetterGetter!AT && !NativeType!(GetterType!AT) && hasAttribute!(GetterType!AT, NiceName))
          {
            name = getAttribute!(GetterType!AT, NiceName).value;
          }
          else static if(hasAttribute!(AT, NiceName))
            name = getAttribute!(AT, NiceName).value;
          else
            name = AT.stringof;

          foreach(int i, ref v;pValue[])
          {
            static if(NativeType!(arrayType!(MT)))
              ProcessNativeArrayMember(v, element, allocator);
            else
              DoProcessMember(v, element, name, IsOptional.No, allocator);
          }
        }
      }
    }
    else static if(RecursiveType!(MT)){
      //writefln("recursive type");
      static if(HasSetterGetter!(MT)){
        static if(__traits(hasMember,GetterType!(MT),"DoXmlSerialize"))
          pValue.XmlGetValue().DoXmlSerialize(pFather, pName);
        else
        {
          auto proxyValue = pValue.XmlGetValue();
          DoProcessMember(proxyValue, pFather, pName, isOptional, allocator);
        }
      }
      else {
        //writefln("processing members");
        TiXmlElement element = AllocatorNew!TiXmlElement(allocator, TiXmlString(pName, IsStatic.Yes), allocator);
        pFather.LinkEndChild(element);
        foreach(m;__traits(allMembers,MT)){
          //writefln("testing " ~ m);
          static if(m.length < 2 || m[0..2] != "__"){
            //writefln(m ~ " passed 1");
            static if(__traits(compiles,typeof(__traits(getMember,MT,m)))){
              //writefln(m ~ " passed 2");
              static if(!isFunction!(typeof(__traits(getMember,pValue,m)))){
                //writefln(m ~ " passed 3");
                auto memberOptional = hasAttribute!(__traits(getMember, pValue, m), Optional) ?
                  IsOptional.Yes : IsOptional.No;
                static if(__traits(hasMember,typeof(__traits(getMember, MT, m)),"DoXmlSerialize"))
                  __traits(getMember,pValue,m).DoXmlSerialize(element, m);
                else
                {
                  static if(!hasAttribute!(__traits(getMember, pValue, m), Ignore))
                    XmlSerializerBase.DoProcessMember(__traits(getMember, pValue, m), element, m, memberOptional, allocator);
                }
              }
            }
          }
        }
      }
    }	
  }
	
	static void ProcessMember(alias M, MT)(ref MT pValue, TiXmlNode pFather, string pName, IAllocator allocator){
    static if(!hasAttribute!(M, Ignore)){
      DoProcessMember(pValue, pFather, pName, allocator);
		}
	}	
}

/**
 * Serializes a given value into a xml file
 * $(BR) does a deep serialize
 * Params:
 *  pValue = the value to serialize
 *	pFilename = the filename of the xml to save to
 */
void ToXmlFile(T)(ref T pValue, string pFilename){
  auto allocator = GetNewTemporaryAllocator();
  scope(exit) Delete(allocator);

	TiXmlDocument doc = AllocatorNew!TiXmlDocument(allocator, allocator);
  scope(exit)
  {
    AllocatorDelete(allocator, doc);
  }

	TiXmlDeclaration decl = AllocatorNew!TiXmlDeclaration( allocator,
                                                         TiXmlString("1.0", IsStatic.Yes), 
                                                         TiXmlString("UTF-8", IsStatic.Yes), 
                                                         TiXmlString("", IsStatic.Yes),
                                                         allocator);
	doc.LinkEndChild( decl );
	
	static if(std.traits.isArray!(T))
		__gshared string rootName = (ArrayType!(T)).stringof;
	else
		__gshared string rootName = T.stringof;
	
	static if(__traits(hasMember,pValue,"DoXmlSerialize"))
		pValue.DoXmlSerialize(doc,rootName,false);
	else
		XmlSerializerBase.DoProcessMember(pValue,doc,rootName, XmlSerializerBase.IsOptional.No, allocator);

	doc.SaveFile(pFilename);
}

mixin template MakeXmlSerializeable() {
	alias typeof(this) T;
	void DoXmlSerialize(TiXmlNode pFather, string pName, bool pIgnoreAll){
		//writefln("Processing " ~ T.stringof ~ " special");
		//if(pIgnoreAll)
			//writefln("ingore all");
		static if(!HasMetaAttribute!(T,XmlIgnore)){
			if(!pIgnoreAll || pIgnoreAll && HasMetaAttribute!(T,XmlSerialize)){
				static bool IgnoreAll = HasMetaAttribute!(T,XmlIgnoreAll);
				static if(HasSetterGetter!(T)){
					static if(__traits(hasMember,GetterType!(T),"DoXmlSerialize"))
						XmlGetValue().DoXmlSerialize(pFather,pName,IgnoreAll);
					else
						ProcessMember(XmlGetValue(),pFather,pName,IgnoreAll);
				}
				else {
					TiXmlElement element = new TiXmlElement(pName.dup);
					pFather.LinkEndChild(element);
					foreach(m;__traits(allMembers,T)){
						//writefln("member " ~ m);
						static if((m.length < 2 || m[0..2] != "__") && m != "this"){
							//writefln("testing "~m);
							static if(__traits(compiles,typeof(__traits(getMember,T,m)))){
								//writefln(m ~ " passed 1 type");
								static if(!isFunction!(typeof(__traits(getMember,this,m)))){
									//writefln(m ~ " passed 2 " ~  typeof(__traits(getMember,this,m)).stringof );
									static if(__traits(hasMember,typeof(__traits(getMember,this,m)),"DoXmlSerialize"))
										__traits(getMember,this,m).DoXmlSerialize(element,m,IgnoreAll);
									else
										XmlSerializerBase.ProcessMember(__traits(getMember,this,m),element,m,IgnoreAll);
								}
							}
						}
					}
				}
			}
		}
		//writefln("finished " ~ T.stringof);
	}
}

version(unittest)
{
  import thBase.devhelper;
  import thBase.serialize.xmldeserializer;
  import thBase.math3d.vecs;
}

unittest
{
  static struct special
  {
    float x,y;

    void XmlSetValue(XmlValue!float x)
    {
      this.x = x.value;
    }

    XmlValue!float XmlGetValue()
    {
      return XmlValue!float(x);
    }
  }

  static struct DontTouch
  {
    void XmlSetValue(int value)
    {
      assert(0, "should not be called");
    }

    int XmlGetValue()
    {
      assert(0, "should not be called");
    }
  }

  @NiceName("NiceName")
  static struct Named
  {
    int i;
  }

  static struct Named2
  {
    int i;

    Named XmlGetValue()
    {
      return Named(i);
    }

    void XmlSetValue(Named v)
    {
      i = v.i;
    }
  }

  static struct test {

    ~this()
    {
      Delete(s);
      Delete(n1);
      Delete(n2);
    }

    float f;
    int i;
    rcstring name;
    special[] s;
    Named[] n1;
    Named2[] n2;
    RCArray!special s2;
    @Optional int[] opt;
    @Optional RCArray!int opt2;
    @Ignore DontTouch ignore;
    vec3 v3;
    ivec3 iv3;
    vec2 v2;
    ivec2 iv2;
    vec4 v4;
    ivec4 iv4;
  }

  {
    test t;
    t.f = 0.5f;
    t.i = 16;
    t.name = _T("testnode");
    t.s = NewArray!(special)(4);
    t.n1 = NewArray!(Named)(2);
    t.n2 = NewArray!(Named2)(2);
    t.s2 = RCArray!special(4);
    t.opt2 = RCArray!int(4);
    for(int i=0; i<4; i++)
    {
      t.s[i].x = cast(float)i;
      t.s[i].y = cast(float)i; //this shouldn't be serialized

      t.s2[i].x = cast(float)i;
      t.s2[i].y = cast(float)i; //this shouldn't be serialized

      t.opt2[i] = i;
    }
    ToXmlFile(t, "XmlSerializeTest.xml");
  }

  {
    auto t = FromXmlFile!(test)(_T("XmlSerializeTest.xml"));
    assert(t.f == 0.5f, "t.f a has invalid value");
    assert(t.i == 16, "t.i has a invalid value");
    assert(t.name == "testnode", "t.name has a invalid value");
    for(int i=0; i<4; i++)
    {
      assert(t.s[i].x == cast(float)i, "t.s[].x has a invalid value");
      assert(t.s[i].y != t.s[i].y, "t.s[].y has a invalid value"); //NAN check
      
      assert(t.s2[i].x == cast(float)i, "t.s2[].x has a invalid value");
      assert(t.s2[i].y != t.s2[i].y, "t.s2[].y has a invalid value");
    }
  }
}