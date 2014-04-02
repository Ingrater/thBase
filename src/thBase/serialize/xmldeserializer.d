module thBase.serialize.xmldeserializer;

import thBase.tinyxml;
import thBase.serialize.common;
import thBase.conv, thBase.format;
import std.traits, thBase.traits, core.traits;
import core.refcounted;
import thBase.error;
import thBase.allocator;
import thBase.conv;
import thBase.casts;

public import thBase.serialize.wrapper;

/**
 * Exception thrown on Desierializer error
 */
class XmlDeserializerException : RCException {
	this(rcstring msg){
		super(msg);
	}
	
	this(char[] msg){
		super(rcstring(msg));
	}
	
	void Append(rcstring msg){
		this.rcmsg ~= msg;
    this.msg = rcmsg[];
	}
}

class XmlDeserializerBase {
protected:
	static void HandleError(AttributeQueryEnum pType, TiXmlElement pElement, const(char)[] name, const(char)[] type){
		auto path = pElement.Value();
		for(TiXmlNode next = pElement.Parent();next !is null && next.Type() != TiXmlNode.NodeType.DOCUMENT;next = next.Parent())
    {
			path = format("%s.%s",next.Value()[], path[]);
    }
		if(pType == AttributeQueryEnum.TIXML_NO_ATTRIBUTE){
			throw New!XmlDeserializerException(FormatError("Couldn't find Attribute '%s' at '%s'", name, path[]));
		}
		else {
			throw New!XmlDeserializerException(FormatError("Expected type '%s' for Attribute '%s' at '%s'", type, name, path[]));
		}
	}
	
	static void HandleError(TiXmlNode pNode, const(char)[] msg)
  {
		auto path = pNode.Value();
		for(TiXmlNode next = pNode.Parent();next !is null && next.Type() != TiXmlNode.NodeType.DOCUMENT;next = next.Parent())
			path = next.Value() ~ "." ~ path;
		throw New!XmlDeserializerException(FormatError("path: '%s' error: %s", path[], msg));
	}
	
	static bool DoDeserializeAttribute(ref int value, TiXmlElement pElement, string name, bool optional){
		auto error = ErrorScope(ErrorContext.create("int-attribute", name));
    auto type = pElement.QueryIntAttribute(name, value);
		if(type == AttributeQueryEnum.TIXML_WRONG_TYPE || type == AttributeQueryEnum.TIXML_NO_ATTRIBUTE)
    {
      if(!optional)
			  HandleError(type, pElement, name, "int");
      return false;
    }
    return true;
	}

	static bool DoDeserializeAttribute(ref uint value, TiXmlElement pElement, string name, bool optional){
		auto error = ErrorScope(ErrorContext.create("uint-attribute", name));
    auto type = pElement.QueryUIntAttribute(name, value);
		if(type == AttributeQueryEnum.TIXML_WRONG_TYPE || type == AttributeQueryEnum.TIXML_NO_ATTRIBUTE)
    {
      if(!optional)
			  HandleError(type, pElement, name, "uint");
      return false;
    }
    return true;
	}

	static bool DoDeserializeAttribute(ref ubyte value, TiXmlElement pElement, string name, bool optional){
		auto error = ErrorScope(ErrorContext.create("ubyte-attribute", name));
    uint temp = 0;
    auto type = pElement.QueryUIntAttribute(name, temp);
		if(type == AttributeQueryEnum.TIXML_WRONG_TYPE || type == AttributeQueryEnum.TIXML_NO_ATTRIBUTE)
    {
      if(!optional)
			  HandleError(type, pElement, name, "ubyte");
      return false;
    }
    if(temp > 0xFF)
    {
      HandleError(AttributeQueryEnum.TIXML_WRONG_TYPE, pElement, name, "ubyte");
    }
    value = int_cast!ubyte(temp);
    return true;
	}
	
	static void DoDeserializeAttribute(ref float value, TiXmlElement pElement, string name, bool optional){
		auto error = ErrorScope(ErrorContext.create("float-attribute", name));
    auto type = pElement.QueryFloatAttribute(name,value);
		if(type == AttributeQueryEnum.TIXML_WRONG_TYPE || type == AttributeQueryEnum.TIXML_NO_ATTRIBUTE && !optional)
			HandleError(type, pElement ,name, "float");
	}
	
	static void DoDeserializeAttribute(ref double value, TiXmlElement pElement, string name, bool optional){
		auto error = ErrorScope(ErrorContext.create("double-attribute", name));
    auto type = pElement.QueryDoubleAttribute(name,value);
		if(type == AttributeQueryEnum.TIXML_WRONG_TYPE || type == AttributeQueryEnum.TIXML_NO_ATTRIBUTE && !optional)
			HandleError(type,pElement,name,"double");
	}
	
	static void DoDeserializeAttribute(ref bool value, TiXmlElement pElement, string name, bool optional){
		auto error = ErrorScope(ErrorContext.create("bool-attribute", name));
    auto text = pElement.Attribute(name);
		if(text[] is null){
			if(optional)
				return;
			else
				HandleError(AttributeQueryEnum.TIXML_NO_ATTRIBUTE,pElement,name,"bool");
		}
		if(text == "true"){
			value = true;
		}
		else if(text == "false"){
			value = false;
		}
		else {
			HandleError(AttributeQueryEnum.TIXML_WRONG_TYPE,pElement,name,"bool");
		}
	}

  static void DoDeserializeAttribute(ref rcstring value, TiXmlElement pElement, string name, bool optional)
  {
    auto error = ErrorScope(ErrorContext.create("rcstring-attribute", name));
		auto text = pElement.Attribute(name);
		if(text[] is null){
			if(optional)
				return;
			else
				HandleError(AttributeQueryEnum.TIXML_NO_ATTRIBUTE,pElement,name,"rcstring");
		}
    value = rcstring(text[]);
  }

  static void DoDeserializeEnumAttribute(T)(ref T value, TiXmlElement element, string name, bool optional)
  {
    auto error = ErrorScope(ErrorContext.create("enum-attribute", name));
		auto text = element.Attribute(name);
		if(text[] is null){
			if(optional)
				return;
			else
				HandleError(AttributeQueryEnum.TIXML_NO_ATTRIBUTE, element, name, "enum");
		}
    try 
    {
      value = StringToEnum!T(text[]);
    }
    catch(ConvException ex)
    {
      rcstring msg = ex.getMessage();
      Delete(ex);
      HandleError(element, msg[]);
    }
  }

  static void ProcessTextNode(ref rcstring value, TiXmlElement element, string name)
  {
    TiXmlNode textNode = element.FirstChildElement(name);
    if(textNode is null)
    {
      char[256] msg;
      formatStatic(msg, "missing child node '%s'", name);
      HandleError(cast(TiXmlNode)element, msg);
    }
    TiXmlText text = textNode.FirstTextElement();
    if(text !is null)
    {
      value = text.Value[];
    }
    else
    {
      value = rcstring();
    }
  }

  static void ProcessLineNumber(ref uint value, TiXmlElement element, string name, uint offset)
  {
    TiXmlNode node = element.FirstChildElement(name);
    if(node is null)
    {
      char[256] msg;
      formatStatic(msg, "missing child node '%s'", name);
      HandleError(cast(TiXmlNode)element, msg);
    }
    value = node.location.row + offset;
  }
	
	static void ProcessMember(MT)(ref MT pValue, TiXmlNode pFather, string pName, IsOptional isOptional, TiXmlNode pNode = null)
  {
		static if(NativeType!(MT)){
			//writefln("deserializing " ~ pName ~ " type: " ~ MT.stringof);
			DoDeserializeAttribute(pValue,pFather.ToElement(), pName, isOptional);
		}
		else static if(std.traits.isArray!(MT))
    {
      static assert(!is(MT == string), "serialzing 'string' is not supported. Use rcstring instead");
			TiXmlNode node = (pNode is null) ? pFather.FirstChild(pName) : pNode;
			if(node is null && !isOptional){
        char[256] buffer;
        auto len = formatStatic(buffer, "'%s' does not exist", pName);
				HandleError(pFather, cast(string)buffer[0..len]);
			}
			else {
        if(node is null)
          return;
        auto error = ErrorScope(ErrorContext.create("array", pName));
				TiXmlElement element = node.ToElement();
				if(element is null){
					HandleError(node,"is not an element");
				}

        string name;
        alias AT = arrayType!MT;
        static if(NativeType!AT)
          name = "el";
        else static if (HasSetterGetter!AT && !NativeType!(GetterType!AT) && hasAttribute!(GetterType!AT, NiceName))
        {
          name = getAttribute!(GetterType!AT, NiceName).value;
        }
        else static if(hasAttribute!(AT, NiceName))
          name = getAttribute!(AT, NiceName).value;
        else
          name = AT.stringof;

				int size = 0;
				if(!DoDeserializeAttribute(size, element, "size", true))
        {
          TiXmlNode cur = element.FirstChildElement(name);
          for(;cur !is null;cur = cur.NextSiblingElement(name))
          {
            size++;
          }
        }
				if(pValue.length == 0){
					pValue = NewArray!(ArrayType!(MT))(size);
				}
				else if(pValue.length != size){
					static if(isStaticArray!(MT))
						HandleError(element, "array size does not match static array size");
					else
          {
            HandleError(element, "array is not empty and does not match size");
          }
				}

        TiXmlNode cur = element.FirstChildElement(name);            
        int i=0;
        for(;i<size && cur !is null;i++, cur = cur.NextSiblingElement(name)){
          static if(NativeType!AT)
            DoDeserializeAttribute(pValue[i], cur.ToElement(), "value", IsOptional.No);
          else
            ProcessMember(pValue[i], element, null, IsOptional.No, cur);
        }
        if(cur !is null)
        {
          HandleError(node, "there are more child elements then given in the size attribute");
        }
        if(i < size)
        {
          HandleError(node, "child elements are missing or size attribute to big");
        }
			}
		}
    else static if(isRCArray!(MT))
    {
      static if(isRCString!(MT))
      {
        static assert(is(RCArrayType!(MT) == immutable(char)), "wchar and dchar not implemented");
        DoDeserializeAttribute(pValue, pFather.ToElement(), pName, isOptional);
      }
      else
      {
        TiXmlNode node = (pNode is null) ? pFather.FirstChild(pName) : pNode;
        if(node is null && !isOptional)
        {
          char[256] buffer;
          auto len = formatStatic(buffer, "'%s' does not exist", pName);
          HandleError(pFather, cast(string)buffer[0..len]);
        }
        else {
          auto error = ErrorScope(ErrorContext.create("array", pName));
          TiXmlElement element = node.ToElement();
          if(element is null){
            HandleError(node, "is not an element");
          }
          int size;
          DoDeserializeAttribute(size,element,"size",false);
          pValue = MT(size);

          string name;
          alias AT = arrayType!MT;
          static if(NativeType!AT)
            name = "el";
          else static if (HasSetterGetter!AT && !NativeType!(GetterType!AT) && hasAttribute!(GetterType!AT, NiceName))
          {
            name = getAttribute!(GetterType!AT, NiceName).value;
          }
          else static if(hasAttribute!(AT, NiceName))
            name = getAttribute!(AT, NiceName).value;
          else
            name = AT.stringof;

          TiXmlNode cur = element.FirstChildElement(name);
          int i=0;
          for(;i<size && cur !is null;i++, cur = cur.NextSiblingElement(name)){
            static if(NativeType!AT)
              DoDeserializeAttribute(pValue[i], cur.ToElement(), "value", IsOptional.No);
            else
              ProcessMember(pValue[i], element, null, IsOptional.No, cur);
          }
          if(cur !is null)
          {
            HandleError(node, "there are more child elements then given in the size attribute");
          }
          if(i < size)
          {
            HandleError(node, "child elements are missing or size attribute to big");
          }
        }
      }
    }
		else static if(RecursiveType!(MT)){
			static if(HasSetterGetter!(MT))
      {
        if(isOptional && pName !is null && pFather.FirstChild(pName) is null)
          return;
				SetterType!MT temp = pValue.XmlGetValue();
				static if(__traits(hasMember,SetterType!(MT),"DoXmlDeserialize"))
					temp.DoXmlDeserialize(pFather, pName, isOptional, pNode);
				else
					ProcessMember(temp, pFather, pName, isOptional, pNode);
				pValue.XmlSetValue(temp);
			}
			else {
        auto error = ErrorScope(ErrorContext.create("group", pName));
				TiXmlNode node = (pNode is null) ? pFather.FirstChild(pName) : pNode;
				if(node is null)
        {
          if(!isOptional)
          {
            char[256] buffer;
            auto len = formatStatic(buffer, "'%s' does not exist", pName);
				    HandleError(pFather, cast(string)buffer[0..len]);
          }
				}
				else {
					TiXmlElement element = node.ToElement();
					if(element is null){
						HandleError(node,"is not a element");
					}
					foreach(m;__traits(allMembers,MT)){
						static if(m.length < 2 || m[0..2] != "__")
            {
              static if(__traits(compiles,typeof(__traits(getMember,pValue,m))))
              {
							  static if(__traits(compiles,__traits(getMember,pValue,m) = __traits(getMember,pValue,m).init) && !isFunction!(typeof(__traits(getMember,pValue,m))))
                { 
                  static if(!hasAttribute!(__traits(getMember, pValue, m), Ignore))
                  {
                    static if(hasAttribute!(__traits(getMember, pValue, m), LongText))
                    {
                      ProcessTextNode(__traits(getMember, pValue, m), element, m);
                    }
                    else static if(hasAttribute!(__traits(getMember, pValue, m), LineNumber))
                    {
                      alias attr = getAttribute!(__traits(getMember, pValue, m), LineNumber);
                      ProcessLineNumber(__traits(getMember, pValue, m), element, attr.nodeName, attr.offset);
                    }
                    else
                    {
                      auto isMemberOptional = hasAttribute!(__traits(getMember, pValue, m), Optional) ? IsOptional.Yes : IsOptional.No;
                      static if(__traits(hasMember,typeof(__traits(getMember,MT,m)),"DoXmlDeserialize"))
									      __traits(getMember,pValue,m).DoXmlDeserialize(element, m, isMemberOptional, pNode);
								      else
									      ProcessMember(__traits(getMember,pValue,m), element, m, isMemberOptional, pNode);
                    }
                  }
							  }
              }
						}
					}
				}
			}
		}	
    else static if(is(MT == enum))
    {
      DoDeserializeEnumAttribute(pValue, pFather.ToElement, pName, isOptional);
    }
    else
      static assert(0, "unsupported type " ~ MT.stringof);
	}	
}

/**
 * Deserializes a certain value from a xml file
 * Params:
 *  pValue = the value to deserialize
 *  pFilename = the xml file to read from
 */
void FromXmlFile(T)(ref T pValue, rcstring pFilename){
  auto error = ErrorScope(ErrorContext.create("file", pFilename[]));
  auto allocator = GetNewTemporaryAllocator();
  scope(exit) Delete(allocator);
	TiXmlDocument doc = AllocatorNew!TiXmlDocument(allocator, cast(TiXmlString)pFilename, allocator);
  scope(exit)
  {
    AllocatorDelete(allocator, doc);
  }
	if(!doc.LoadFile()){
		throw New!XmlDeserializerException(doc.ErrorDesc() ~ " File: " ~ pFilename);
	}
	
	static if(std.traits.isArray!(T))
		enum string rootName = (ArrayType!(T)).stringof;
  else static if(isRCArray!(T))
    enum string rootName = (RCArrayType!(T)).stringof;
  else static if(hasAttribute!(T, NiceName))
    enum string rootName = getAttribute!(T, NiceName).value;
	else
		enum string rootName = T.stringof;
	
	try {
		static if(__traits(hasMember,pValue,"DoXmlDeserialize"))
			pValue.DoXmlDeserialize(doc,rootName,false);
		else
			XmlDeserializerBase.ProcessMember(pValue, doc, rootName, IsOptional.No);
	}
	catch(XmlDeserializerException e){
		e.Append(" inside file '" ~ pFilename ~ "'");
		throw e;
	}
}

/**
 * Deserializes a certain value from a xml file
 * Params:
 *  pFilename = the xml file to read from
 * Returns: the read value
 */
T FromXmlFile(T)(rcstring pFilename){
	T temp;
	FromXmlFile(temp,pFilename);
	return temp;
}

mixin template MakeXmlDeserializeable(){
	alias typeof(this) MT;
	void DoXmlDeserialize(TiXmlNode pFather, string pName, bool pIgnoreAll, bool pIsOptional, TiXmlNode pNode){
		static if(!HasMetaAttribute!(MT,XmlIgnore) && !is(UnderlingType!(MT) == MetaAttribute)){
			if(!pIgnoreAll || pIgnoreAll && HasMetaAttribute!(MT,XmlSerialize)){
				static bool IgnoreAll = HasMetaAttribute!(MT,XmlIgnoreAll);
				static if(HasSetterGetter!(MT)){
					SetterType!MT temp = this.XmlGetValue();
					static if(__traits(hasMember,SetterType!(MT),"DoXmlDeserialize"))
						temp.DoXmlDeserialize(pFather,pName,IgnoreAll,HasMetaAttribute!(MT,XmlOptional), pNode);
					else
						ProcessMember(temp,pFather,pName,IgnoreAll,HasMetaAttribute!(MT,XmlOptional), pNode);
					this.XmlSetValue(temp);
				}
				else {
					TiXmlNode node = (pNode is null) ? pFather.FirstChild(pName) : pNode;
					if(node is null && !pIsOptional){
						static if(!HasMetaAttribute!(MT,XmlOptional)){
              char[256] buffer;
              auto msg = formatStatic(buffer, "'%s' does not exist", pName);
							XmlDeserializerBase.HandleError(pFather, msg);
						}
					}
					else {
						TiXmlElement element = node.ToElement();
						if(element is null){
							XmlDeserializerBase.HandleError(pFather,"is not a element");
						}
						foreach(m;__traits(allMembers,MT)){
							static if(m.length < 2 || m[0..2] != "__"){
								static if(__traits(compiles,__traits(getMember,this,m) = __traits(getMember,this,m).init) && !isFunction!(typeof(__traits(getMember,this,m)))){
									static if(__traits(hasMember,typeof(__traits(getMember,MT,m)),"DoXmlDeserialize"))
										__traits(getMember,this,m).DoXmlDeserialize(element,m,IgnoreAll,HasMetaAttribute!(typeof(__traits(getMember,MT,m)),XmlOptional));
									else
										XmlDeserializerBase.ProcessMember(__traits(getMember,this,m),element,m,IgnoreAll,HasMetaAttribute!(typeof(__traits(getMember,MT,m)),XmlOptional));
								}
							}
						}
					}
				}
			}
		}
	}
}

version(unittest)
{
  import thBase.devhelper;
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

  static struct DoNotTouch
  {
    void XmlSetValue(XmlValue!int x)
    {
      assert(0, "should not be called");
    }

    XmlValue!int XmlGetValue()
    {
      assert(0, "should not be called");
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
    @Optional DoNotTouch doNotTouch;
  }

  try 
  {
    test t = FromXmlFile!(test)(_T("XmlDeserializeTest.xml"));
    assert(t.f == 0.5f, "field f has a incorrect value");
    assert(t.i == 16, "field i has a incorrect value");
    assert(t.name == "testnode", "field name has a incorrect value");
    assert(t.s.length == 4, "array s has a incorrect length");
    for(int i=0; i<4; i++)
    {
      assert(t.s[i].x == cast(float)i, "field x has a incorrect value");
      //NAN check
      assert(t.s[i].y != t.s[i].y, "field y has a incorrect value");
    }
    assert(t.s2.length == 4, "rcarray s2 has incorrect length");
    for(int i=0; i<4; i++)
    {
      assert(t.s2[i].x == cast(float)i, "field x has incorret value");
      //NAN check
      assert(t.s2[i].y != t.s[i].y, "field y has a incorrect value");
    }
  }
  catch(RCException ex)
  {
    auto error = ex.toString();
    Delete(ex);
    assert(0, error[]);
  }

  //TODO add test for class serialization
}