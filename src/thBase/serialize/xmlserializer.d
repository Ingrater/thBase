module thBase.serialize.xmlserializer;

import core.refcounted;
import thBase.tinyxml;
public import thBase.serialize.common;
public import thBase.serialize.wrapper;
public import thBase.metainfo;
import std.traits, thBase.traits, core.traits;
import thBase.allocator;

class XmlSerializerBase {
public:
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
	
	static void ProcessMember(MT)(ref MT pValue, TiXmlNode pFather, string pName, bool pIgnoreAll, IAllocator allocator){
		//writefln("Processing " ~ MT.stringof ~ " normal");
		static if(!HasMetaAttribute!(MT,XmlIgnore)){
			if(!pIgnoreAll || pIgnoreAll && HasMetaAttribute!(MT,XmlSerialize)){
				static bool IgnoreAll = HasMetaAttribute!(MT,XmlIgnoreAll);
				static if(NativeType!(MT)){
					DoSerializeAttribute(pValue,pFather.ToElement(), TiXmlString(pName, IsStatic.Yes));
				}
				else static if(std.traits.isArray!(MT)){
          static assert(!is(MT == string), "serializing of strings is not supported, use rcstring instead");
					TiXmlElement element = AllocatorNew!TiXmlElement(allocator, TiXmlString(pName, IsStatic.Yes), allocator);
					pFather.LinkEndChild(element);
					element.SetAttribute(TiXmlString("size", IsStatic.Yes), cast(int)pValue.length);
          string name;
          static if(is(typeof(ArrayType!(MT).XmlName)))
            name = ArrayType!(MT).XmlName;
          else
            name = ArrayType!(MT).stringof;
					foreach(int i,ref v;pValue){
						ProcessMember(v, element, name, false, allocator);
					}
				}
        else static if(isRCArray!(MT)){
          static if(is(MT == rcstring))
          {
            TiXmlElement element = pFather.ToElement();
            element.SetAttribute(TiXmlString(pName, IsStatic.Yes), cast(TiXmlString)pValue);
          }
          else
          {
            TiXmlElement element = AllocatorNew!TiXmlElement(allocator, TiXmlString(pName, IsStatic.Yes), allocator);
            pFather.LinkEndChild(element);
            element.SetAttribute(TiXmlString("size", IsStatic.Yes), cast(int)pValue.length);
            string name;
            static if(is(typeof(ArrayType!(MT).XmlName)))
              name = arrayType!(MT).XmlName;
            else
              name = arrayType!(MT).stringof;
            foreach(int i, ref v;pValue[])
            {
              ProcessMember(v, element, name, false, allocator);
            }
          }
        }
				else static if(RecursiveType!(MT)){
					//writefln("recursive type");
					static if(HasSetterGetter!(MT)){
						static if(__traits(hasMember,GetterType!(MT),"DoXmlSerialize"))
							pValue.XmlGetValue().DoXmlSerialize(pFather,pName,IgnoreAll);
						else
            {
              auto proxyValue = pValue.XmlGetValue();
							ProcessMember(proxyValue, pFather, pName, IgnoreAll, allocator);
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
										static if(__traits(hasMember,typeof(__traits(getMember,MT,m)),"DoXmlSerialize"))
											__traits(getMember,pValue,m).DoXmlSerialize(element,m,IgnoreAll);
										else
											XmlSerializerBase.ProcessMember(__traits(getMember,pValue,m),element,m,IgnoreAll, allocator);
									}
								}
							}
						}
					}
				}	
			}
		}
		//writefln("finished " ~ MT.stringof);
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
		XmlSerializerBase.ProcessMember(pValue,doc,rootName,false, allocator);

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

  static struct test {

    ~this()
    {
      Delete(s);
    }

    float f;
    int i;
    rcstring name;
    special[] s;
    RCArray!special s2;
  }

  {
    test t;
    t.f = 0.5f;
    t.i = 16;
    t.name = _T("testnode");
    t.s = NewArray!(special)(4);
    t.s2 = RCArray!special(4);
    for(int i=0; i<4; i++)
    {
      t.s[i].x = cast(float)i;
      t.s[i].y = cast(float)i; //this shouldn't be serialized

      t.s2[i].x = cast(float)i;
      t.s2[i].y = cast(float)i; //this shouldn't be serialized
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