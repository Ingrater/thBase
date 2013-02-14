/*
www.sourceforge.net/projects/tinyxml
Original code (2.0 and earlier )copyright (c) 2000-2002 Lee Thomason (www.grinninglizard.com)

This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any
damages arising from the use of this software.

Permission is granted to anyone to use this software for any
purpose, including commercial applications, and to alter it and
redistribute it freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must
not claim that you wrote the original software. If you use this
software in a product, an acknowledgment in the product documentation
would be appreciated but is not required.

2. Altered source versions must be plainly marked as such, and
must not be misrepresented as being the original software.

3. This notice may not be removed or altered from any source
distribution.
*/
module thBase.tinyxml;

//comment this in to do the xml performance test
//version = XML_PERFORMANCE_TEST;

import thBase.stream;
import thBase.string;
import thBase.conv;
import thBase.file;
import thBase.types;
import thBase.format;
import thBase.tools;
import std.uni;
import std.ascii;
import core.allocator;
import core.refcounted;

public {
enum TiXmlEncoding
{
	TIXML_ENCODING_UNKNOWN,
	TIXML_ENCODING_UTF8,
	TIXML_ENCODING_LEGACY
};
}
private 
{
	//import std.utf;
	const char TIXML_UTF_LEAD_0 = 0xefU;
	const char TIXML_UTF_LEAD_1 = 0xbbU;
	const char TIXML_UTF_LEAD_2 = 0xbfU;

	class TiXmlParsingData
	{
		
		public {
			void Stamp( TiXmlString now, TiXmlEncoding encoding )
			in { assert(now.length > 0); }
			body
			{
				// Do nothing if the tabsize is 0.
			}

			
			TiXmlCursor Cursor()	{ return cursor; }
		}
		public{
			this( TiXmlString start, int _tabsize, int row, int col )
			{
				stamp = start;
				tabsize = _tabsize;
				cursor.row = row;
				cursor.col = col;
			}
		}
	
		TiXmlCursor		cursor;
		TiXmlString		stamp;
		int				tabsize;
	};


}
public {

const int TIXML_MAJOR_VERSION = 2;
const int TIXML_MINOR_VERSION = 4;
const int TIXML_PATCH_VERSION = 3;
const int NUM_ENTITY = 5;


struct TiXmlCursor
{
	void Clear()		{ row = row.init; col = col.init; }
	int row = -1;	// 0 based.
	int col = -1;	// 0 based.
};


enum AttributeQueryEnum
{ 
	TIXML_SUCCESS,
	TIXML_NO_ATTRIBUTE,
	TIXML_WRONG_TYPE
};



const TiXmlEncoding TIXML_DEFAULT_ENCODING = TiXmlEncoding.TIXML_ENCODING_UNKNOWN;

alias RCArray!(immutable(char), IAllocator) TiXmlString;

class TiXmlBase
{
	public {
	this(IAllocator allocator) { userData = null; m_allocator = allocator; }

	abstract void Print( IOutputStream Stream, int depth );

	static void SetCondenseWhiteSpace( bool condense )		{ condenseWhiteSpace = condense; }

	/// Return the current white space setting.
	static bool IsWhiteSpaceCondensed()						{ return condenseWhiteSpace; }

	int Row() { return location.row + 1; }
	int Column() { return location.col + 1; }	///< See Row()

	void  SetUserData( void* user )			{ userData = user; }
	void* GetUserData()						{ return userData; }

	static const int utf8ByteTable[256];

	abstract TiXmlString Parse(	TiXmlString p, 
								TiXmlParsingData data, 
								TiXmlEncoding encoding);

	enum TiXmlError
	{
		TIXML_NO_ERROR = 0,
		TIXML_ERROR,
		TIXML_ERROR_OPENING_FILE,
		TIXML_ERROR_OUT_OF_MEMORY,
		TIXML_ERROR_PARSING_ELEMENT,
		TIXML_ERROR_FAILED_TO_READ_ELEMENT_NAME,
		TIXML_ERROR_READING_ELEMENT_VALUE,
		TIXML_ERROR_READING_ATTRIBUTES,
		TIXML_ERROR_PARSING_EMPTY,
		TIXML_ERROR_READING_END_TAG,
		TIXML_ERROR_PARSING_UNKNOWN,
		TIXML_ERROR_PARSING_COMMENT,
		TIXML_ERROR_PARSING_DECLARATION,
		TIXML_ERROR_DOCUMENT_EMPTY,
		TIXML_ERROR_EMBEDDED_NULL,
		TIXML_ERROR_PARSING_CDATA,
		TIXML_ERROR_DOCUMENT_TOP_ONLY,

		TIXML_ERROR_STRING_COUNT
	};
	}
protected{

	static TiXmlString	SkipWhiteSpace( TiXmlString op, TiXmlEncoding encoding )
	{
		return stripLeft(op);
	}
	
	static bool	IsWhiteSpace( char c )
	{ 
		return (  std.uni.isWhite( c ) || c == '\n' || c == '\r' ); 
	}
	static bool	IsWhiteSpace( int c )
	{
		if ( c < 256 )
			return IsWhiteSpace( cast(char) c );
		return false;
	}
	
	void StreamOut (IOutputStream o);

	static TiXmlString ReadName( TiXmlString p, out TiXmlString name, TiXmlEncoding encoding )
	in
	{ assert(p); }
	body
	{
		name = _T("");
	
		int i = 0;
		
		if ( p && p.length > 0
			 && ( IsAlpha( cast(ubyte) p[0], encoding ) || p[0] == '_' ) )
		{
			while( i < p.length &&	( IsAlphaNum( p[i], encoding ) 
							 || p[i] == '_'
							 || p[i] == '-'
							 || p[i] == '.'
							 || p[i] == ':' ) )
			{
				++i;
			}
      name = p[0..i];
			return p[i..p.length];
		}
		return TiXmlString();
	}

	static int ReadText(	TiXmlString sin,				// where to start
									ref TiXmlString text,			// the string read
									bool ignoreWhiteSpace,		// whether to keep the white space
									string endTag,			// what ends this text
									bool ignoreCase,			// whether to ignore case in the end tag
									TiXmlEncoding encoding) // the current encoding	
	{
		text = TiXmlString("", IsStatic.Yes);
		static if(size_t.sizeof == 4)
			int p = 0;
		else
			long p = 0;
		if (!(!ignoreWhiteSpace			// certain tags always keep whitespace
			 || !condenseWhiteSpace ))	// if true, whitespace is always kept
			 sin = SkipWhiteSpace( sin, encoding );
			 
		p = (!ignoreCase)?(indexOf(sin, endTag)):(indexOf(sin,endTag,CaseSensitive.no));
		if (p == -1)
		{
			text = sin;
			return cast(int)sin.length;
		}
		else
		{
			text = sin[0..p];
			return cast(int)(p + endTag.length);
		}
	}

	static void PutString( TiXmlString str, IOutputStream outs )
	{
		foreach (int i, char c;str[])
		{
			ubyte _c = cast(ubyte) c;

			if ( _c == '&' 
          && i < ( str.length - 2 )
          && str[i+1] == '#'
          && str[i+2] == 'x' )
			{
				while ( i<str.length-1 )
				{
					outs.write(str[i]);
					if ( str[i] == ';' )
						break;
				}
			}
			else if ( c == '&' )
			{
				outs.write(entity[0].str); 
			}
			else if ( c == '<' )
			{
				outs.write(entity[1].str); 
			}
			else if ( c == '>' )
			{
				outs.write(entity[2].str); 
			}
			else if ( c == '\"' )
			{
				outs.write(entity[3].str); 
			}
			else if ( c == '\'' )
			{
				outs.write(entity[4].str); 
			}
			else if ( c < 32 )
			{
				outs.format("&#x%02X;", cast(uint) ( c & 0xff ));
			}
			else
			{
				outs.write(c);	
			}
		}
	}

	/*static void PutString( char[] str, ref StringAppendBuffer!(immutable(char)) buf )
	{	
		foreach (int i, char c;str[])
		{
			ubyte _c = cast(ubyte) c;
	
			if ( _c == '&' 
				 && i < ( str.length - 2 )
				 && str[i+1] == '#'
				 && str[i+2] == 'x' )
			{
				while ( i<str.length-1 )
				{
					buf ~= str[i];
					if ( str[i] == ';' )
						break;
				}
			}
			else if ( c == '&' )
			{
				buf ~= entity[0].str; 
			}
			else if ( c == '<' )
			{
				buf ~= entity[1].str; 
			}
			else if ( c == '>' )
			{
				buf ~= entity[2].str; 
			}
			else if ( c == '\"' )
			{
				buf ~= entity[3].str; 
			}
			else if ( c == '\'' )
			{
				buf ~= entity[4].str;
			}
			else if ( c < 32 )
			{
				buf.format("&#x%02X;", cast(uint) ( c & 0xff ));
			}
			else
			{
				buf ~= c;	
			}
		}
	}*/

	/*static bool StringEqual(	char[] p,
								char[] endTag,
								bool ignoreCase,
								TiXmlEncoding encoding )
	in { assert(p); assert(endTag); assert(p.length > 0); }
	body
	{
		if ( ignoreCase )
			return (indexOf(p, endTag,CaseSensitive.no) == 0);
		else
			return (indexOf(p, endTag) == 0);
	}*/


	static string[] errorString = [
	"No error",
	"Error",
	"Failed to open file",
	"Memory allocation failed.",
	"Error parsing Element.",
	"Failed to read Element name",
	"Error reading Element value.",
	"Error reading Attributes.",
	"Error: empty tag.",
	"Error reading end tag.",
	"Error parsing Unknown.",
	"Error parsing Comment.",
	"Error parsing Declaration.",
	"Error document empty.",
	"Error null (0) or unexpected EOF found in input stream.",
	"Error parsing CDATA.",
	"Error when TiXmlDocument added to document, because TiXmlDocument can only be at the root.",
];

	TiXmlCursor location;

    /// Field containing a generic user pointer
	void*			userData;
  IAllocator m_allocator;
	
	static int IsAlpha( char anyByte, TiXmlEncoding encoding )
	{
		return std.ascii.isAlpha(anyByte);
	}

	static int IsAlphaNum( char anyByte, TiXmlEncoding encoding )
	{
		if ( anyByte < 127 )
			return (IsAlpha(anyByte,encoding) || isDigit(anyByte));
		else
			return 1;
	}

	
	static int ToLower( int v, TiXmlEncoding encoding )
	{
		return std.ascii.toLower(v);
	}
	}
	private
	{
		struct Entity
		{
			string      str;
			char		    chr;
		};
		static Entity entity[ NUM_ENTITY ];
		static bool condenseWhiteSpace;
	}
}

class TiXmlNode : TiXmlBase
{

	public {

	enum NodeType
	{
		DOCUMENT,
		ELEMENT,
		COMMENT,
		UNKNOWN,
		TEXT,
		DECLARATION,
		TYPECOUNT
	};

	~this()
	{
		TiXmlNode node = firstChild;
		TiXmlNode temp = null;

    while(node !is null)
    {
      temp = node;
      node = node.next;
      AllocatorDelete(temp.m_allocator, temp);
    }
	}

	TiXmlString Value() { return value; }

	void SetValue(TiXmlString _value) { value = _value;}

	/// Delete all the children of this node. Does not affect 'this'.
	void Clear()
	{
		TiXmlNode node = firstChild;
		TiXmlNode temp = null;

    while(node !is null)
    {
      temp = node;
      node = node.next;
      AllocatorDelete(temp.m_allocator, temp);
    }

		firstChild = null;
		lastChild = null;
	} 	

	/// One step up the DOM.
	TiXmlNode Parent()							{ return parent; }

	TiXmlNode FirstChild()					{ return firstChild; }

  TiXmlNode FirstChild( string _value )
  {
    for(TiXmlNode node = firstChild; node !is null; node = node.next)
    {
      if( node.Value == _value )
        return node;
    }
    return null;
  }

	final TiXmlNode FirstChild( TiXmlString _value )	
  {
    return FirstChild(_value[]);
  }

	TiXmlNode LastChild()	{ return lastChild; }
	TiXmlNode LastChild( string _value ) 
	{
		TiXmlNode node;
		for ( node = lastChild; node; node = node.prev )
		{
			if ( node.Value == _value )
				return node;
		}
		return null;
	}
  final TiXmlNode LastChild( TiXmlString _value )
  {
    return LastChild(_value[]);
  }

	TiXmlNode IterateChildren( TiXmlNode previous )
	{
		if ( !previous )
		{
			return FirstChild();
		}
		else
		{
			assert( previous.parent == this );
			return previous.NextSibling();
		}
	}

	/// This flavor of IterateChildren searches for children with a particular 'value'
	TiXmlNode IterateChildren( string val, TiXmlNode previous )
	{
		if ( !previous )
		{
			return FirstChild( val );
		}
		else
		{
			assert( previous.parent == this );
			return previous.NextSibling( val );
		}
	}

  final TiXmlNode IterateChildren( TiXmlString val, TiXmlNode previous )
  {
    return IterateChildren( val[], previous );
  }
	
	TiXmlNode InsertEndChild( TiXmlNode addThis )
	{
		if ( addThis.Type == NodeType.DOCUMENT )
		{
			if ( GetDocument() ) GetDocument().SetError( TiXmlError.TIXML_ERROR_DOCUMENT_TOP_ONLY, TiXmlString(),null, TiXmlEncoding.TIXML_ENCODING_UNKNOWN );
			return null;
		}
		TiXmlNode node = addThis.Clone();
		if ( !node )
			return null;
	
		return LinkEndChild( node );
	}
	
	TiXmlNode LinkEndChild( TiXmlNode node )
	in
	{
		
		assert( node.parent is null || node.parent == this );
		assert( node.GetDocument() is null || node.GetDocument() == this.GetDocument() );
	}
	body
	{
	
		if ( node.Type() == NodeType.DOCUMENT )
		{
      AllocatorDelete(node.m_allocator, node);
			if ( GetDocument() ) GetDocument().SetError( TiXmlError.TIXML_ERROR_DOCUMENT_TOP_ONLY, TiXmlString(),null, TiXmlEncoding.TIXML_ENCODING_UNKNOWN );
			return null;
		}
	
		node.parent = this;
	
		node.prev = lastChild;
		node.next = null;
	
		if ( lastChild )
			lastChild.next = node;
		else
			firstChild = node;			// it was an empty list.
	
		lastChild = node;
		return node;
	}

	TiXmlNode InsertBeforeChild( TiXmlNode beforeThis, TiXmlNode addThis )
	{	
		if ( !beforeThis || beforeThis.parent != this ) {
			return null;
		}
		if ( addThis.Type == NodeType.DOCUMENT )
		{
			if ( GetDocument() ) GetDocument().SetError( TiXmlError.TIXML_ERROR_DOCUMENT_TOP_ONLY, TiXmlString(),null, TiXmlEncoding.TIXML_ENCODING_UNKNOWN );
			return null;
		}
	
		TiXmlNode node = addThis.Clone();
		node.parent = this;
	
		node.next = beforeThis;
		node.prev = beforeThis.prev;
		if ( beforeThis.prev )
		{
			beforeThis.prev.next = node;
		}
		else
		{
			assert( firstChild == beforeThis );
			firstChild = node;
		}
		beforeThis.prev = node;
		return node;
	}


	TiXmlNode InsertAfterChild(  TiXmlNode afterThis, TiXmlNode addThis )
	{
		if ( !afterThis || afterThis.parent != this ) {
			return null;
		}
		if ( addThis.Type == NodeType.DOCUMENT )
		{
			if ( GetDocument() ) GetDocument().SetError( TiXmlError.TIXML_ERROR_DOCUMENT_TOP_ONLY, TiXmlString(),null, TiXmlEncoding.TIXML_ENCODING_UNKNOWN );
			return null;
		}
	
		TiXmlNode node = addThis.Clone();

		node.parent = this;
	
		node.prev = afterThis;
		node.next = afterThis.next;
		if ( afterThis.next )
		{
			afterThis.next.prev = node;
		}
		else
		{
			assert( lastChild == afterThis );
			lastChild = node;
		}
		afterThis.next = node;
		return node;
	}
	
	TiXmlNode ReplaceChild( TiXmlNode replaceThis, TiXmlNode withThis )
	{
		if ( replaceThis.parent != this )
			return null;
	
		TiXmlNode node = withThis.Clone();
		if ( !node )
			return null;
	
		node.next = replaceThis.next;
		node.prev = replaceThis.prev;
	
		if ( replaceThis.next )
			replaceThis.next.prev = node;
		else
			lastChild = node;
	
		if ( replaceThis.prev )
			replaceThis.prev.next = node;
		else
			firstChild = node;
	
    AllocatorDelete(replaceThis.m_allocator, replaceThis);
		node.parent = this;
		return node;
	}


	/// Delete a child of this node.
	bool RemoveChild( TiXmlNode removeThis )
	in { assert(removeThis.parent == this); }
	body
	{
		if ( removeThis.next )
			removeThis.next.prev = removeThis.prev;
		else
			lastChild = removeThis.prev;
	
		if ( removeThis.prev )
			removeThis.prev.next = removeThis.next;
		else
			firstChild = removeThis.next;
	
    AllocatorDelete(removeThis.m_allocator, removeThis);
		return true;
	}
		

	/// Navigate to a sibling node.
	TiXmlNode PreviousSibling()						{ return prev; }

	/// Navigate to a sibling node.
	TiXmlNode PreviousSibling( string _value )
	{
		TiXmlNode node;
		for ( node = prev; node; node = node.prev )
		{
			if ( _value == node.Value())
				return node;
		}
		return null;
	}
  final TiXmlNode PreviousSibling( TiXmlString _value )
  {
    return PreviousSibling( _value[] );
  }

	/// Navigate to a sibling node.
	TiXmlNode NextSibling()							{ return next; }

	TiXmlNode NextSibling( string _value )
	{
		TiXmlNode node;
		for ( node = next; node; node = node.next )
		{
			if ( node.Value == _value )
				return node;
		}
		return null;
	}
  final TiXmlNode NextSibling( TiXmlString _value )
  {
    return NextSibling(_value[]);
  }

	TiXmlElement NextSiblingElement()
	{
		TiXmlNode node;
	
		for (node = NextSibling();	node;	node = node.NextSibling() )
		{
			if ( node.ToElement() )
				return node.ToElement();
		}
		return null;
	} 

	TiXmlElement NextSiblingElement( string _value )
	{
		TiXmlNode node;
	
		for (node = NextSibling( _value );node;node = node.NextSibling( _value ) )
		{
			if ( node.ToElement() )
				return node.ToElement();
		}
		return null;
	}
  final TiXmlElement NextSiblingElement( TiXmlString _value )
  {
    return NextSiblingElement(_value[]);
  }


	/// Convenience function to get through elements.
	TiXmlElement FirstChildElement()
	{
		TiXmlNode node;
	
		for (node = FirstChild;node;node = node.NextSibling )
		{
			if ( node.ToElement )
				return node.ToElement;
		}
		return null;
	}



	/// Convenience function to get through elements.
	TiXmlElement FirstChildElement( string _value )
	{
		TiXmlNode node;
	
		for (node = FirstChild( _value );node;node = node.NextSibling( _value ) )
		{
			if ( node.ToElement )
				return node.ToElement;
		}
		return null;
	} 
  final TiXmlElement FirstChildElement( TiXmlString _value )
  {
    return FirstChildElement(_value[]);
  }



	int Type() { return type; }

	TiXmlDocument GetDocument()
	{
		TiXmlNode node;
	
		for( node = this; node; node = node.parent )
		{
			if ( node.ToDocument() )
				return node.ToDocument();
		}
		return null;
	}

	/// Returns true if this node has no children.
	bool NoChildren() 							{ return !firstChild; }

	TiXmlDocument    ToDocument()    { return null; } ///< Cast to a more defined type. Will return null if not of the requested type.
	TiXmlElement     ToElement()     { return null; } ///< Cast to a more defined type. Will return null if not of the requested type.
	TiXmlComment     ToComment()     { return null; } ///< Cast to a more defined type. Will return null if not of the requested type.
	TiXmlUnknown     ToUnknown()     { return null; } ///< Cast to a more defined type. Will return null if not of the requested type.
	TiXmlText        ToText()        { return null; } ///< Cast to a more defined type. Will return null if not of the requested type.
	TiXmlDeclaration ToDeclaration() { return null; } ///< Cast to a more defined type. Will return null if not of the requested type.

	abstract TiXmlNode Clone();
	}
protected{
	this( NodeType _type, IAllocator allocator )
	{
    super(allocator);
		parent = null;
		type = _type;
		firstChild = null;
		lastChild = null;
		prev = null;
		next = null;
	}

	// Copy to the allocated object. Shared functionality between Clone, Copy constructor,
	// and the assignment operator.
	void CopyTo( TiXmlNode target ) {
		target.SetValue(value);
		target.userData = userData;
	}
	// Figure out what is at *p, and parse it. Returns null if it is not an xml node.
	TiXmlNode Identify( TiXmlString start, TiXmlEncoding encoding )
	{
		auto p = start;
		TiXmlNode returnNode = null;
	
		p = SkipWhiteSpace( p, encoding );
		if( p.length == 0 || p[0] != '<' )
		{
			return null;
		}
		
		TiXmlDocument doc = GetDocument();
	
		if ( p.length == 0 )
		{
			return null;
		}
	
		static string xmlHeader = "<?xml";
		static string commentHeader = "<!--";
		static string dtdHeader = "<!";
		static string cdataHeader = "<![CDATA[";
		
		if ( startsWith( p, xmlHeader, CaseSensitive.yes ) )
		{
			debug {
				//TIXML_LOG( "XML parsing Declaration\n" );
			}
			returnNode = AllocatorNew!TiXmlDeclaration(m_allocator, m_allocator);
		}
		else if ( startsWith( p, commentHeader, CaseSensitive.yes ) )
		{
			debug {
				//TIXML_LOG( "XML parsing Comment\n" );
			}
			returnNode = AllocatorNew!TiXmlComment(m_allocator, m_allocator);
		}
		else if ( startsWith( p, cdataHeader, CaseSensitive.yes ) )
		{
			debug {
				//TIXML_LOG( "XML parsing CDATA\n" );
			}
			TiXmlText text = AllocatorNew!TiXmlText( m_allocator, TiXmlString("", IsStatic.Yes), m_allocator );
			text.SetCDATA( true );
			returnNode = text;
		}
		else if ( startsWith( p, dtdHeader, CaseSensitive.yes ) )
		{
			debug {
				//TIXML_LOG( "XML parsing Unknown(1)\n" );
			}
			returnNode = AllocatorNew!TiXmlUnknown( m_allocator, m_allocator);
		}
		else if (    IsAlpha( p[1], encoding )
				  || p[1] == '_' )
		{
			debug {
				//TIXML_LOG( "XML parsing Element\n" );
			}
			returnNode = AllocatorNew!TiXmlElement(m_allocator, TiXmlString("", IsStatic.Yes), m_allocator );
		}
		else
		{
			debug {
				//TIXML_LOG( "XML parsing Unknown(2)\n" );
			}
			returnNode = AllocatorNew!TiXmlUnknown(m_allocator, m_allocator);
		}
	
		if ( returnNode )
		{
			// Set the parent, so it can report errors
			returnNode.parent = this;
		}
		else
		{
			if ( doc )
				doc.SetError( TiXmlError.TIXML_ERROR_OUT_OF_MEMORY, TiXmlString(), null, TiXmlEncoding.TIXML_ENCODING_UNKNOWN );
		}
		return returnNode;
	}


	TiXmlNode		parent;
	NodeType		type;

	TiXmlNode		firstChild;
	TiXmlNode		lastChild;

	TiXmlString	value;

	TiXmlNode		prev;
	TiXmlNode		next;
	}
};

class TiXmlAttribute : TiXmlBase
{
	public{
	alias Object.opEquals opEquals;
	alias Object.opCmp opCmp;
	/// Construct an empty attribute.
	this(IAllocator allocator) 
	{
		super(allocator);
		document = null;
		prev = next = null;
	}


	/// Construct an attribute with a name and value.
	this( TiXmlString _name, TiXmlString _value, IAllocator allocator )
	{
		name = _name;
		value = _value;
		this(allocator);
	}

	TiXmlString		Name()  { return name; }		///< Return the name of this attribute.
	TiXmlString		Value() { return value; }		///< Return the value of this attribute.
	int			IntValue() { return to!int(value); }									///< Return the value of this attribute, converted to an integer.
	double			DoubleValue() { return to!double(value); }								///< Return the value of this attribute, converted to a double.

	// Get the tinyxml string representation
	TiXmlString NameTStr() { return name; }

	AttributeQueryEnum QueryIntValue( out int _value )
	{
		if (to!int(value[],_value) == thResult.SUCCESS)
		{
			return AttributeQueryEnum.TIXML_SUCCESS;
		}
		return AttributeQueryEnum.TIXML_WRONG_TYPE;
	}
	/// QueryDoubleValue examines the value string. See QueryIntValue().
	AttributeQueryEnum QueryDoubleValue( out double _value ) 
	{
		if (to!double(value[],_value) == thResult.SUCCESS)
		{
			return AttributeQueryEnum.TIXML_SUCCESS;
		}
		return AttributeQueryEnum.TIXML_WRONG_TYPE;
	}

	void SetName( TiXmlString _name )	{ name = _name; }				///< Set the name of this attribute.
	void SetValue( TiXmlString _value )	{ value = _value; }				///< Set the value.

	void SetIntValue( int _value ) { value = format("%d",_value); }										///< Set the value from an integer.
	void SetDoubleValue( double _value ) { value = format("%f",_value); }								///< Set the value from a double.


	/// Get the next sibling attribute in the DOM. Returns null at end.
	TiXmlAttribute Next()
	{
		if ( next.value.length == 0 && next.name.length == 0 )
			return null;
		return next;
	}

	
	/// Get the previous sibling attribute in the DOM. Returns null at beginning.
	TiXmlAttribute Previous()
	{
		if ( prev.value.length == 0 && prev.name.length == 0 )
			return null;
		return prev;
	}


	bool opEquals(TiXmlAttribute rhs) { return rhs.name == name; }
	int opCmp( TiXmlAttribute rhs ) { 
		if (rhs is null)
			return 0;
		if (name < rhs.name) return -1;
		if (name > rhs.name) return 1;
		return 0;
	}
	
	override TiXmlString Parse( TiXmlString p, TiXmlParsingData data, TiXmlEncoding encoding )
	body
	{
		p = SkipWhiteSpace( p, encoding );
		size_t Q = 0;
		if ( p.length == 0) 
      return TiXmlString();
	
		if ( data )
		{
			data.Stamp( p, encoding );
			location = data.Cursor;
		}
		// Read the name, the '=' and the value.
		auto pErr = p;
		p = ReadName( p, name, encoding );
		
		if ( p.length == 0)
		{
			if ( document ) document.SetError( TiXmlError.TIXML_ERROR_READING_ATTRIBUTES, pErr, data, encoding );
			  return TiXmlString();
		}
		p = SkipWhiteSpace( p, encoding );
		if ( p.length == 0 || p[0] != '=' )
		{
			if ( document ) document.SetError( TiXmlError.TIXML_ERROR_READING_ATTRIBUTES, p, data, encoding );
			  return TiXmlString();
		}
	
		p = p[1..p.length];	// skip '='
		p = SkipWhiteSpace( p, encoding );
		if ( p.length == 0)
		{
			if ( document ) document.SetError( TiXmlError.TIXML_ERROR_READING_ATTRIBUTES, p, data, encoding );
			  return TiXmlString();
		}
		
		string end;
		char SINGLE_QUOTE = '\'';
		char DOUBLE_QUOTE = '\"';
	
		if ( p[0] == SINGLE_QUOTE )
		{
			p = p[1..p.length];
			end = "\'";		// single quote in string
			p = p[ReadText( p, value, false, end, false, encoding ) .. p.length];
		}
		else if ( p[0] == DOUBLE_QUOTE )
		{
			p = p[1..p.length];
			end = "\"";		// double quote in string
			p = p[ReadText( p, value, false, end, false, encoding ) .. p.length];
		}
		else
		{			
      auto start = Q;
			while ( Q < p.length
					&& !IsWhiteSpace( p[Q] ) && p[Q] != '\n' && p[Q] != '\r'	// whitespace
					&& p[Q] != '/' && p[Q] != '>' )							// tag end
			{
				if ( p[Q] == SINGLE_QUOTE || p[Q] == DOUBLE_QUOTE ) {
					if ( document ) document.SetError( TiXmlError.TIXML_ERROR_READING_ATTRIBUTES, p, data, encoding );
					  return TiXmlString();
				}
				++Q;
			}
      value = p[start..Q];
		}
		return p[Q .. p.length];
	}


	// Prints this Attribute to a FILE stream.
	override void Print( IOutputStream Stream, int depth )
	{
		StreamOut(Stream);
	}


	override void StreamOut( IOutputStream Stream ) 
	{
		if (indexOf (value[], '\"') == -1)
    {
      Stream.write(name[]);
      Stream.write("=\"");
      Stream.write(value[]);
      Stream.write('\"');
    }
		else
    {
      Stream.write(name[]);
      Stream.write("='");
      Stream.write(value[]);
      Stream.write('\'');
    }
	}
	// [internal use]
	// Set the document pointer so the attribute can report errors.
	void SetDocument( TiXmlDocument doc )	{ document = doc; }
	}
	private{

	TiXmlDocument	document = null;	// A pointer back to a document, for error reporting.
	TiXmlString name;
	TiXmlString value;
	TiXmlAttribute	prev = null;
	TiXmlAttribute	next = null;
	}
};

class TiXmlAttributeSet
{
public {
	this(IAllocator allocator) 
  { 
    sentinel = AllocatorNew!TiXmlAttribute(allocator, allocator); 
    sentinel.next = sentinel; 
    sentinel.prev = sentinel; 
  }
	~this() { 
    AllocatorDelete(sentinel.m_allocator, sentinel );
    sentinel = null; 
  }
	void Add( TiXmlAttribute addMe )
	{
		//assert( !Find( TIXML_STRING( addMe->Name() ) ) );	// Shouldn't be multiply adding to the set.
		assert( !Find( addMe.Name  ) );
		addMe.next = sentinel;
		addMe.prev = sentinel.prev;

		sentinel.prev.next = addMe;
		sentinel.prev      = addMe;
	}
	void Remove( TiXmlAttribute removeMe )
	{
		TiXmlAttribute node;
	
		for( node = sentinel.next; node != sentinel; node = node.next )
		{
			if ( node == removeMe )
			{
				node.prev.next = node.next;
				node.next.prev = node.prev;
				node.next = null;
				node.prev = null;
				return;
			}
		}
		assert( 0 );		// we tried to remove a non-linked attribute.
	} 

	TiXmlAttribute First()					{ return ( sentinel.next == sentinel ) ? null : sentinel.next; }
	TiXmlAttribute Last()					{ return ( sentinel.prev == sentinel ) ? null : sentinel.prev; }

	TiXmlAttribute	Find( string name ) 
	{
		TiXmlAttribute node;

		for( node = sentinel.next; node != sentinel; node = node.next )
		{
			if ( node.name == name )
				return node;
		}
		return null;
	}
  final TiXmlAttribute Find( TiXmlString name )
  {
    return Find(name[]);
  }
	}


private:
	TiXmlAttribute sentinel;
};

class TiXmlElement : TiXmlNode
{
public {
	this(IAllocator allocator) {
		super(TiXmlNode.NodeType.ELEMENT, allocator);
    attributeSet = composite!TiXmlAttributeSet(DefaultCtor());
    attributeSet.construct(allocator);
	}
	/// Construct an element.
	this(TiXmlString in_value, IAllocator allocator)
	{
		this(allocator);
		firstChild = lastChild = null;
		value = in_value;
	}


	~this() { 
    ClearThis(); 
  }

	TiXmlString Attribute( string name )
	{
		TiXmlAttribute node = attributeSet.Find(name);
		if (node)
			return node.Value;
			
		return TiXmlString();
	}
  final TiXmlString Attribute( TiXmlString name )
  {
    return Attribute(name[]);
  }

	TiXmlString Attribute( string name, out int i ) 
  {
		auto s = Attribute( name );
		if ( s )
			i = to!int( s );
		else
			i = 0;

		return s;
	}
  final TiXmlString Attribute( TiXmlString name, out int i )
  {
    return Attribute(name[],i);
  }

	TiXmlString Attribute( string name, out double i ) 
  {
		auto s = Attribute( name );
		if ( s )
			i = to!double( s );
		else
			i = 0;

		return s;
	}
  TiXmlString Attribute( TiXmlString name, out double i )
  {
    return Attribute( name[], i );
  }

	AttributeQueryEnum QueryIntAttribute( string name, out int _value ) 
  {
		TiXmlAttribute node = attributeSet.Find( name );
		if ( !node )
			return AttributeQueryEnum.TIXML_NO_ATTRIBUTE;
	
		return node.QueryIntValue( _value );
	}
  final AttributeQueryEnum QueryIntAttribute( TiXmlString name, out int _value )
  {
    return QueryIntAttribute( name[], _value );
  }
	
	AttributeQueryEnum QueryDoubleAttribute( string name, out double _value ) 
  {
		TiXmlAttribute node = attributeSet.Find( name );
		if ( !node )
			return AttributeQueryEnum.TIXML_NO_ATTRIBUTE;
	
		return node.QueryDoubleValue( _value );
	}
  final AttributeQueryEnum QueryDoubleAttribute( TiXmlString name, out double _value)
  {
    return QueryDoubleAttribute( name[], _value );
  }


	AttributeQueryEnum QueryFloatAttribute( string name, out float _value )
	{
		double d;
		AttributeQueryEnum result = QueryDoubleAttribute( name, d );
		if ( result == AttributeQueryEnum.TIXML_SUCCESS ) {
			_value = cast(float)d;
		}
		return result;
	}
  final AttributeQueryEnum QueryFloatAttribute( TiXmlString name, out float _value )
  {
    return QueryFloatAttribute( name[], _value );
  }


	void SetAttribute( TiXmlString name, int val )
	{	
		SetAttribute( name, formatAllocator(m_allocator, "%d", val) ); //TODO replace with to!string (implement first)
	}



	void SetAttribute( TiXmlString _name, TiXmlString _value )
	{
		TiXmlAttribute node = attributeSet.Find( _name );
		if ( node )
		{
			node.SetValue( _value );
			return;
		}
	
		TiXmlAttribute attrib = AllocatorNew!TiXmlAttribute( m_allocator, _name, _value, m_allocator );
		if ( attrib )
		{
			attributeSet.Add( attrib );
		}
		else
		{
			TiXmlDocument document = GetDocument();
			if ( document ) 
        document.SetError( TiXmlError.TIXML_ERROR_OUT_OF_MEMORY, TiXmlString(),null, TiXmlEncoding.TIXML_ENCODING_UNKNOWN );
		}
	}



	void SetDoubleAttribute( TiXmlString name, double val )
	{	
		SetAttribute( name, formatAllocator(m_allocator, "%f", val) ); //TODO replace with to!string
	}


	void RemoveAttribute( string name )
	{
		TiXmlAttribute node = attributeSet.Find( name );
		if ( node )
		{
			attributeSet.Remove( node );
      AllocatorDelete(node.m_allocator, node);
		}
	}
  final void RemoveAttribute( TiXmlString name )
  {
    RemoveAttribute( name[] );
  }


	TiXmlAttribute FirstAttribute() 				{ return attributeSet.First; }
	TiXmlAttribute LastAttribute()					{ return attributeSet.Last; }

	TiXmlString GetText() 
	{
		TiXmlNode child = FirstChild;
		if ( child ) {
			TiXmlText childText = child.ToText;
			if ( childText ) {
				return childText.Value;
			}
		}
		return TiXmlString();
	}
	

	/// Creates a new Element and returns it - the returned element is a copy.
	override
	{
		TiXmlNode Clone() { 
			TiXmlElement x = AllocatorNew!TiXmlElement(m_allocator, m_allocator);
			CopyTo(x);
			TiXmlAttribute attribute;
			for(attribute = attributeSet.First;attribute;attribute = attribute.Next )
			{
				x.SetAttribute( attribute.Name, attribute.Value );
			}
		
			TiXmlNode node;
			for ( node = firstChild; node; node = node.NextSibling )
			{
				x.LinkEndChild( node.Clone );
			}

			return x; 
		}
		void Print( IOutputStream Stream, int depth ) 
		{
			int i;
			for ( i=0; i<depth; i++ )
				Stream.write("    ");
		
      Stream.write('<');
			Stream.write(value[]);
		
			TiXmlAttribute attrib;
			for ( attrib = attributeSet.First; attrib; attrib = attrib.Next )
			{
				Stream.write(' ');
				attrib.Print( Stream, depth );
			}
		
			TiXmlNode node;
			if ( !firstChild )
				Stream.write(" />");
			else if ( firstChild == lastChild && firstChild.ToText )
			{
				Stream.write('>');
				firstChild.Print( Stream, depth + 1 );
				Stream.write("</");
        Stream.write(value[]);
        Stream.write('>');
			}
			else
			{
				Stream.write('>');
				for ( node = firstChild; node; node=node.NextSibling )
				{
					if ( !node.ToText() )
					{
						Stream.write("\n");
					}
					node.Print( Stream, depth+1 );
				}
				Stream.write("\n");
				for( i=0; i<depth; ++i )
					Stream.write("    ");
				
				Stream.write("</");
        Stream.write(value[]);
        Stream.write('>');
			}
		}
		
		override TiXmlString Parse( TiXmlString p, TiXmlParsingData data, TiXmlEncoding encoding )
		{
			p = SkipWhiteSpace( p, encoding );
			TiXmlDocument document = GetDocument();
		
			if ( p.length == 0 )
			{
				if ( document ) document.SetError( TiXmlError.TIXML_ERROR_PARSING_ELEMENT, TiXmlString(),null, encoding );
				return TiXmlString();
			}
		
			if ( data )
			{
				data.Stamp( p, encoding );
				location = data.Cursor;
			}
		
			if ( p[0] != '<' )
			{
				if ( document ) document.SetError( TiXmlError.TIXML_ERROR_PARSING_ELEMENT, p, data, encoding );
				  return TiXmlString();
			}
		
			p = SkipWhiteSpace( p[1..p.length], encoding );
			// Read the name.
			auto pErr = p;
		
			p = ReadName( p, value, encoding );
			//writefln("name: '%s', ret: '%s'", value, p);
			if ( p.length == 0 )
			{
				if ( document )	document.SetError( TiXmlError.TIXML_ERROR_FAILED_TO_READ_ELEMENT_NAME, pErr, data, encoding );
				  return TiXmlString();
			}
		
			TiXmlString endTag = "</" ~ value ~ ">";
		
			while ( p.length > 0 )
			{
				pErr = p;
				p = SkipWhiteSpace( p, encoding );
				if ( p.length == 0 )
				{
					if ( document ) document.SetError( TiXmlError.TIXML_ERROR_READING_ATTRIBUTES, pErr, data, encoding );
					  return TiXmlString();
				}

				if ( p[0] == '/' )
				{
					p = p[1..p.length];
					// Empty tag.
					if ( p[0]  != '>' )
					{
						if ( document ) document.SetError( TiXmlError.TIXML_ERROR_PARSING_EMPTY, p, data, encoding );
						  return TiXmlString();
					}
					return p[1..p.length];
				}
				else if ( p[0] == '>' )
				{

					p = p[1..p.length];
					p = ReadValue( p, data, encoding );		// Note this is an Element method, and will set the error if one happens.
					if ( p.length == 0 )
						return TiXmlString();
		
					// We should find the end tag now
					if ( startsWith( p[], endTag[], CaseSensitive.yes ) )
						return p[endTag.length..p.length];
					else
					{
						if ( document ) document.SetError( TiXmlError.TIXML_ERROR_READING_END_TAG, p, data, encoding );
						return TiXmlString();
					}
				}
				else
				{
					TiXmlAttribute attrib = AllocatorNew!TiXmlAttribute(m_allocator, m_allocator);
					attrib.SetDocument( document );
					p = attrib.Parse( p, data, encoding );
					if ( p.length == 0 )
					{
						if ( document ) 
              document.SetError( TiXmlError.TIXML_ERROR_PARSING_ELEMENT, pErr, data, encoding );
						AllocatorDelete( attrib.m_allocator, attrib );
            return TiXmlString();
					}
		
					// Handle the strange case of double attributes:
					auto temp = attrib.NameTStr();
					
					TiXmlAttribute node = attributeSet.Find( temp[] );
					if ( node )
					{
						node.SetValue( attrib.Value );
            AllocatorDelete( attrib.m_allocator, attrib );
						return TiXmlString();
					}
		
					attributeSet.Add( attrib );
				}
			}
			return p;
		}
		TiXmlElement     ToElement()     { return this; } ///< Cast to a more defined type. Will return null not of the requested type.
	}
	}
protected{


	
	void ClearThis() {
		Clear();
    while( attributeSet.First() !is null )
    {
      TiXmlAttribute node = attributeSet.First();
      attributeSet.Remove( node );
      AllocatorDelete( node.m_allocator, node );
    }
	}



	override void StreamOut( IOutputStream _Stream ) {
    _Stream.write('<');
		_Stream.write(value[]);
	
		TiXmlAttribute attrib;
		for ( attrib = attributeSet.First; attrib; attrib = attrib.Next )
		{
			_Stream.write(' ');
			attrib.StreamOut( _Stream );
		}
	
		TiXmlNode node;
		if ( !firstChild )
			_Stream.write(" />");
		else if ( firstChild == lastChild && firstChild.ToText )
		{
			_Stream.write('>');
			firstChild.StreamOut( _Stream );
      _Stream.write("</");
			_Stream.write(value[]);
      _Stream.write('>');
		}
		else
		{
			_Stream.write('>');
			for ( node = firstChild; node; node=node.NextSibling )
			{
				if ( !node.ToText() )
				{
					_Stream.write("\n");
				}
				node.StreamOut( _Stream  );
			}
			_Stream.write("\n");
			
      _Stream.write("</");
			_Stream.write(value[]);
      _Stream.write('>');
		}
	}

	TiXmlString ReadValue( TiXmlString p, TiXmlParsingData prevData, TiXmlEncoding encoding )
	{
		TiXmlDocument document = GetDocument();
	
		// Read in text and elements in any order.
		auto pWithWhiteSpace = p;
		p = SkipWhiteSpace( p, encoding );
	
		while ( p.length > 0 )
		{
			if ( p[0] != '<' )
			{
				// Take what we have, make a text element.
				TiXmlText textNode = AllocatorNew!TiXmlText( m_allocator, TiXmlString("", IsStatic.Yes), m_allocator );
				
				if ( TiXmlBase.IsWhiteSpaceCondensed() )
				{
					p = textNode.Parse( p, prevData, encoding );
				}
				else
				{

					p = textNode.Parse( pWithWhiteSpace, prevData, encoding );
				}
				if ( !textNode.Blank )
					LinkEndChild( textNode );
			} 
			else 
			{
				if ( startsWith( p, "</", CaseSensitive.yes ) )
				{
					return p;
				}
				else
				{
					TiXmlNode node = Identify( p, encoding );
					if ( node )
					{
						p = node.Parse( p, prevData, encoding );
						LinkEndChild( node );
					}				
					else
					{
						return TiXmlString();
					}
				}
			}
			pWithWhiteSpace = p;
			p = SkipWhiteSpace( p, encoding );
		}
	
		if ( p.length == 0 )
		{
			if ( document ) document.SetError( TiXmlError.TIXML_ERROR_READING_ELEMENT_VALUE, TiXmlString(), null, encoding );
		}	
		return p;
	}

	}
	//private TiXmlAttributeSet attributeSet;
  private composite!TiXmlAttributeSet attributeSet;

};


/**	An XML comment.
*/
class TiXmlComment : TiXmlNode
{
public{
	/// Constructs an empty comment.
	this(IAllocator allocator) { super( TiXmlNode.NodeType.COMMENT, allocator ); }

	/// Returns a copy of this Comment.
	override TiXmlNode Clone() { 
		auto x = AllocatorNew!TiXmlComment(m_allocator, m_allocator);
		CopyTo(x);
		return x;
	}
	override void Print( IOutputStream stream, int depth ) 
	{
		for ( int i=0; i<depth; i++ )
		{
			stream.write("    ");
		}
		StreamOut(stream);
	}
	
	override TiXmlString Parse( TiXmlString p, TiXmlParsingData data, TiXmlEncoding encoding )
	{
		TiXmlDocument document = GetDocument();
		value = _T("");
	
		p = SkipWhiteSpace( p, encoding );
	
		if ( data )
		{
			data.Stamp( p, encoding );
			location = data.Cursor;
		}
		static string startTag = "<!--";
		static string endTag   = "-->";
	
		if ( !startsWith( p[], startTag, CaseSensitive.yes) )
		{
			document.SetError( TiXmlError.TIXML_ERROR_PARSING_COMMENT, p, data, encoding );
			return TiXmlString();
		}
		p = p[startTag.length..p.length];
		p = p[ReadText( p, value, false, endTag, false, encoding )..p.length];
		return p;
	}

	

	override TiXmlComment  ToComment() { return this; } ///< Cast to a more defined type. Will return null not of the requested type.
	}
protected
	override void StreamOut( IOutputStream Stream ) 
	{
		Stream.write("<!--");
    Stream.write(value[]);
    Stream.write("-->");
	}	



};

class TiXmlText : TiXmlNode
{
public{

	this(IAllocator allocator) { super(TiXmlNode.NodeType.TEXT, allocator); }
	this (TiXmlString initValue, IAllocator allocator ) 
	{
		this(allocator);
		SetValue( initValue );
		cdata = false;
	}
	override void Print( IOutputStream Stream, int depth ) {
		if ( cdata )
		{
			int i;
			Stream.write("\n");
			for ( i=0; i<depth; i++ ) 
				Stream.write("    ");
			
			Stream.write("<![CDATA[");
      Stream.write(value[]); 
      Stream.write("]]>\n");
		}
		else
		{
			Stream.write(value[]);
		}
	}

	bool CDATA()					{ return cdata; }

	void SetCDATA( bool _cdata )	{ cdata = _cdata; }

	override TiXmlString Parse( TiXmlString p, TiXmlParsingData data, TiXmlEncoding encoding )
	{
		value = _T("");
		TiXmlDocument document = GetDocument();
	
		if ( data )
		{
			data.Stamp( p, encoding );
			location = data.Cursor;
		}
	
		static string startTag = "<![CDATA[";
		static string endTag   = "]]>";
	
		if ( cdata || startsWith( p[], startTag, CaseSensitive.yes))
		{
			cdata = true;
	
			if ( !startsWith( p[], startTag, CaseSensitive.yes) )
			{
				document.SetError( TiXmlError.TIXML_ERROR_PARSING_CDATA, p, data, encoding );
				return TiXmlString();
			}
			p = p[startTag.length..p.length];
	
      size_t pos = 0;
			while ( p.length > pos
					&& !startsWith( p[pos..p.length][], endTag, CaseSensitive.yes)
				  )
			{
        pos++;
			}
      value = p[0..pos];
      p = p[pos..p.length];
	
			TiXmlString dummy; 
			p = p[ReadText( p, dummy, false, endTag, false, encoding )..p.length];
			return p;
		}
		else
		{
			bool ignoreWhite = true;
	
			auto f = indexOf(p, "<");
			if (f == -1)
			{
				value = p;
				return TiXmlString();
			}
			else
			{
				value = p[0..f];
				return p[f..p.length];
			}
		}
	}


	override TiXmlText       ToText()       { return this; } ///< Cast to a more defined type. Will return null not of the requested type.
	}
protected {
	override TiXmlNode Clone() { 
		auto x = AllocatorNew!TiXmlText(m_allocator, m_allocator);
		CopyTo(x);
		x.cdata = cdata;
		return x;
	}

	override void StreamOut ( IOutputStream Stream ) { 
		if ( cdata )
		{
			int i;
			Stream.write("<![CDATA[");
      Stream.write(value[]);
      Stream.write("]]>\n");
		}
		else
		{
			Stream.write(value[]);
		} 
	}
	bool Blank()
	{
		foreach(i,v;value)
		{
			if ( !IsWhiteSpace( v ) )
				return false;
		}
		return true;
	}

	}

private bool cdata;			// true if this should be input and output as a CDATA style text element
};


class TiXmlDeclaration : TiXmlNode
{
public{
	/// Construct an empty declaration.
	this(IAllocator allocator) { super(TiXmlNode.NodeType.DECLARATION, allocator ); }

	/// Construct.
	this(	TiXmlString _version, TiXmlString _encoding, TiXmlString _standalone, IAllocator allocator )
	{
		this(allocator);
		mversion = _version;
		encoding = _encoding;
		standalone = _standalone;
	}

	/// Version. Will return an empty string if none was found.
	TiXmlString Version() 		{ return mversion; }
	/// Encoding. Will return an empty string if none was found.
	TiXmlString Encoding() 		{ return encoding; }
	/// Is this a standalone document?
	TiXmlString Standalone() 	{ return standalone; }

	/// Creates a copy of this Declaration and returns it.
	override TiXmlNode Clone() { 
		auto target = AllocatorNew!TiXmlDeclaration(m_allocator, m_allocator);
		CopyTo(target);

		target.mversion = mversion;
		target.encoding = encoding;
		target.standalone = standalone;
		return target;
	}
	override void Print( IOutputStream Stream, int depth ) 
	{
		StreamOut(Stream);
	}

	override TiXmlString Parse( TiXmlString p, TiXmlParsingData data, TiXmlEncoding _encoding )
	{
		p = SkipWhiteSpace( p, _encoding );
		// Find the beginning, find the end, and look for
		// the stuff in-between.
		TiXmlDocument document = GetDocument();
		
		if ( p.length == 0 || !startsWith(p[], "<?xml", CaseSensitive.yes) )
		{
			if ( document ) document.SetError( TiXmlError.TIXML_ERROR_PARSING_DECLARATION, TiXmlString(),null, _encoding );
			return TiXmlString();
		}
		if ( data )
		{
			data.Stamp( p, _encoding );
			location = data.Cursor();
		}
		
		p = p[5..p.length];
		
		mversion = _T("");
		encoding = _T("");
		standalone = _T("");
	
		while ( p.length > 0 )
		{
			if ( p[0] == '>' )
				return p[1..p.length];

	
			p = SkipWhiteSpace( p, _encoding );
			if ( startsWith( p[], "version", CaseSensitive.no) )
			{
				TiXmlAttribute attrib = AllocatorNew!TiXmlAttribute(m_allocator, m_allocator);
        scope(exit) AllocatorDelete( attrib.m_allocator, attrib );
				p = attrib.Parse( p, data, _encoding );		
				mversion = attrib.Value;
			}
			else if ( startsWith( p[], "encoding", CaseSensitive.no) )
			{
				TiXmlAttribute attrib = AllocatorNew!TiXmlAttribute(m_allocator, m_allocator);
        scope(exit) AllocatorDelete( attrib.m_allocator, attrib );
				p = attrib.Parse( p, data, _encoding );		
				encoding = attrib.Value;
			}
			else if ( startsWith( p[], "standalone", CaseSensitive.no) )
			{
				TiXmlAttribute attrib = AllocatorNew!TiXmlAttribute(m_allocator, m_allocator);
        scope(exit) AllocatorDelete(attrib.m_allocator, attrib );
				p = attrib.Parse( p, data, _encoding );		
				standalone = attrib.Value;
			}
			else
			{
				// Read over whatever it is.
        size_t pos = 0;
				while( p.length > pos && p[pos] != '>' && !IsWhiteSpace( p[pos] ) )
					pos++;
        p = p[pos..p.length];
			}
		}
		return TiXmlString();
	}


	override TiXmlDeclaration ToDeclaration()       { return this; } ///< Cast to a more defined type. Will return null not of the requested type.
	}
protected {
	override void StreamOut ( IOutputStream Stream)	
	{
		Stream.write("<?xml ");
	
		if ( !mversion.length == 0 )
    {
			Stream.write("version=\"");
      Stream.write(mversion[]);
      Stream.write("\" ");
    }
		if ( !encoding.length == 0 )
    {
			Stream.write("encoding=\"");
      Stream.write(encoding[]);
      Stream.write("\" ");
    }
		if ( !standalone.length == 0 )
    {
			Stream.write("standalone=\"");
      Stream.write(standalone[]);
      Stream.write('"');
    }
			
		Stream.write("?>");
	}
	}
private{

	TiXmlString mversion;
	TiXmlString encoding;
	TiXmlString standalone;
	}
};

class TiXmlUnknown : TiXmlNode
{
public{
	this(IAllocator allocator) { super(TiXmlNode.NodeType.UNKNOWN, allocator); }

	/// Creates a copy of this Unknown and returns it.
	override TiXmlNode Clone() { 
		auto x = AllocatorNew!TiXmlUnknown(m_allocator, m_allocator);
		CopyTo(x);
		return x;
	}
	override void Print( IOutputStream Stream, int depth ) {
		for ( int i=0; i<depth; i++ )
			Stream.write("    ");
		StreamOut(Stream);
	}


	override TiXmlString Parse( TiXmlString p, TiXmlParsingData	 data, TiXmlEncoding encoding )
	{
		TiXmlDocument document = GetDocument();
		p = SkipWhiteSpace( p, encoding );
	
		if ( data )
		{
			data.Stamp( p, encoding );
			location = data.Cursor();
		}
		if ( p.length == 0 || p[0] != '<' )
		{
			if ( document ) document.SetError( TiXmlError.TIXML_ERROR_PARSING_UNKNOWN, p, data, encoding );
			return TiXmlString();
		}
		p = p[1..p.length];

    size_t pos = 0;
	
		while ( p.length > pos && p[pos] != '>' )
		{
			pos++;
		}

    value = p[0..pos];
    p = p[pos..p.length];
	
		if ( p.length == 0 )
		{
			if ( document )	document.SetError( TiXmlError.TIXML_ERROR_PARSING_UNKNOWN, TiXmlString(),null, encoding );
		}
		if ( p[0] == '>' )
			return p[1..p.length];
		return p;
	}


	override TiXmlUnknown  ToUnknown()	    { return this; } ///< Cast to a more defined type. Will return null not of the requested type.
	}
protected{


	override void StreamOut ( IOutputStream Stream ) {
    Stream.write('<');
		Stream.write(value[]);
    Stream.write('>');
	}
	}

};


class TiXmlDocument : TiXmlNode
{
public {
	/// Create an empty document, that has no name.
	this(IAllocator allocator) { 
		super(TiXmlNode.NodeType.DOCUMENT, allocator); 
		tabsize = 4;
		useMicrosoftBOM = false;
		ClearError();
	}
	/// Create a document with a name. The name of the document is also the filename of the xml.
	this( TiXmlString documentName, IAllocator allocator )
	{
		value = documentName;
		this(allocator);
	}

	bool LoadFile( TiXmlEncoding encoding = TIXML_DEFAULT_ENCODING )
	{
		return ( LoadFile( value, encoding ) );
	}

	/// Save a file using the current document value. Returns true if successful.
	bool SaveFile() 
	{
		return SaveFile(value[]);
	}

	/// Load a file using the given filename. Returns true if successful.
	bool LoadFile( TiXmlString filename, TiXmlEncoding encoding = TIXML_DEFAULT_ENCODING )
	{
		value = filename;
	
		// reading in binary mode so that tinyxml can normalize the EOL
		auto file = RawFile(filename[], "rb");
		
		if ( file.isOpen() )
		{
			auto b = LoadFile( file, encoding );
			return b;
		}
		else
		{
			SetError( TiXmlError.TIXML_ERROR_OPENING_FILE, TiXmlString(),null, TiXmlEncoding.TIXML_ENCODING_UNKNOWN );
			return false;
		}
	}

	/// Save a file using the given filename. Returns true if successful.
	bool SaveFile( string filename ) {
		// The old c stuff lives on...
		FileOutStream file;
		try {
			file = AllocatorNew!FileOutStream(m_allocator, filename);
		}
		catch (StreamException e)
		{
      AllocatorDelete(m_allocator, file);
			file = null;
      Delete(e); //Execptions are alway allocated by the default allocator
		}
		if ( !(file is null) )
		{
			auto result = SaveFile( file );
      AllocatorDelete(m_allocator, file);
			return result;
		}
		return false;
	}

	bool LoadFile( ref RawFile file, TiXmlEncoding encoding = TIXML_DEFAULT_ENCODING )
	{
		Clear();
		location.Clear();
		size_t length = file.size;
		
		// Strange case, but good to handle up front.
		if ( file.eof )
		{
			SetError( TiXmlError.TIXML_ERROR_DOCUMENT_EMPTY, TiXmlString(), null, TiXmlEncoding.TIXML_ENCODING_UNKNOWN );
			return false;
		}
	
		// If we have a file, assume it is all one big XML file, and read it in.
		// The document parser may decide the document ends sooner than the entire file, however.
		auto data = RCArray!char(length);
    size_t bytesRead = file.readArray(data);
    assert(bytesRead == length);
	
		/*int lastPos = 0;
		int p = 0;
		
		while( p < buf.length ) {
			if ( buf[p] == 0xa ) {
				// Newline character. No special rules for this. Append all the characters
				// since the last string, and include the newline.
				data ~= buf[lastPos..(p+1)];	// append, include the newline
				++p;									// move past the newline
				lastPos = p;							// and point to the new buffer (may be 0)
			}
			else if ( buf[p] == 0xd ) {
				if ( (p-lastPos) > 0 ) 
					data ~= buf[lastPos..p];	// do not add the CR

				data ~= cast(char)0xa;						// a proper newline
				if ( buf[p+1] == 0xa ) {
					// Carriage return - new line sequence
					p += 2;
					lastPos = p;
				}
				else {
					++p;
					lastPos = p;
				}
			}
			else {
				++p;
			}
		}
		// Handle any left over characters.
		if ( (p-lastPos) > 0 ) {
			data ~= buf[lastPos..p];
		}		
		buf = null;*/
		Parse( cast(TiXmlString)data, null, encoding );
	
		if ( Error() )
			return false;
		else
			return true;
	}

	bool SaveFile( FileOutStream pf ) {
		if ( useMicrosoftBOM ) 
		{
			ubyte TIXML_UTF_LEAD_0 = 0xefU;
			ubyte TIXML_UTF_LEAD_1 = 0xbbU;
			ubyte TIXML_UTF_LEAD_2 = 0xbfU;
	
			pf.write(TIXML_UTF_LEAD_0);
			pf.write(TIXML_UTF_LEAD_1);
			pf.write(TIXML_UTF_LEAD_2);
		}
		Print( pf, 0 );
		return true;
	}

	override TiXmlString Parse( TiXmlString p, TiXmlParsingData prevData = null, TiXmlEncoding encoding = TIXML_DEFAULT_ENCODING )
	{
		ClearError();
	
		if ( p.length == 0 )
		{
			SetError( TiXmlError.TIXML_ERROR_DOCUMENT_EMPTY, TiXmlString(), null, TiXmlEncoding.TIXML_ENCODING_UNKNOWN );
			return TiXmlString();
		}
	
		location.Clear();
		if ( ! (prevData is null))
		{
			location.row = prevData.cursor.row;
			location.col = prevData.cursor.col;
		}
		else
		{
			location.row = 0;
			location.col = 0;
		}
		auto data = AllocatorNew!TiXmlParsingData( m_allocator, p, TabSize, location.row, location.col );
    scope(exit) AllocatorDelete(m_allocator, data);
		location = data.Cursor();
		
		if ( encoding == TiXmlEncoding.TIXML_ENCODING_UNKNOWN )
		{
			// Check for the Microsoft UTF-8 lead bytes.
			immutable(ubyte)[] pU = cast(immutable(ubyte)[])p[];
			if (pU.length >= 3 && 
				pU[0] == TIXML_UTF_LEAD_0 &&
				pU[1] == TIXML_UTF_LEAD_1 &&
				pU[2] == TIXML_UTF_LEAD_2 )
			{
				encoding = TiXmlEncoding.TIXML_ENCODING_UTF8;
				useMicrosoftBOM = true;
			}
		}
		
		p = SkipWhiteSpace( p, encoding );
		if ( p.length == 0 )
		{
			SetError( TiXmlError.TIXML_ERROR_DOCUMENT_EMPTY, TiXmlString(), null, TiXmlEncoding.TIXML_ENCODING_UNKNOWN );
			return TiXmlString();
		}
	
		while ( p.length > 0 )
		{
			TiXmlNode node = Identify( p, encoding );
			if ( node )
			{
				p = node.Parse( p, data, encoding );
				LinkEndChild( node );
			}
			else
			{
				break;
			}
	
			// Did we get encoding info?
			if ( encoding == TiXmlEncoding.TIXML_ENCODING_UNKNOWN
				 && node.ToDeclaration )
			{
				TiXmlDeclaration dec = node.ToDeclaration;
				auto enc = dec.Encoding;
	
				if ( enc.length == 0 )
					encoding = TiXmlEncoding.TIXML_ENCODING_UTF8;
				else if ( equal( enc[], "UTF-8", CaseSensitive.no ) )
					encoding = TiXmlEncoding.TIXML_ENCODING_UTF8;
				else if ( equal( enc[], "UTF8", CaseSensitive.no ) )
					encoding = TiXmlEncoding.TIXML_ENCODING_UTF8;	// incorrect, but be nice
				else 
					encoding = TiXmlEncoding.TIXML_ENCODING_LEGACY;
			}
	
			p = SkipWhiteSpace( p, encoding );
		}
	
		// Was this empty?
		if ( firstChild is null ) {
			SetError( TiXmlError.TIXML_ERROR_DOCUMENT_EMPTY, TiXmlString(), null, encoding );
			return TiXmlString();
		}
	
		// All is well.
		return p;
	}
		
	TiXmlElement RootElement()					{ return FirstChildElement; }
	
	bool Error() { return error; }

	auto ErrorDesc() { return errorDesc; }

	int ErrorId()	{ return errorId; }

	int ErrorRow()	{ return errorLocation.row+1; }
	int ErrorCol()	{ return errorLocation.col+1; }	///< The column where the error occured. See ErrorRow()

	void SetTabSize( int _tabsize )		{ tabsize = _tabsize; }

	int TabSize() { return tabsize; }

	void ClearError()						{	error = false; 
												errorId = 0; 
												errorDesc = ""; 
												errorLocation.row = errorLocation.col = 0; 
												//errorLocation.last = 0; 
											}

	/// Print this Document to a out stream.
	override void Print( IOutputStream Stream, int depth = 0 ) {
		TiXmlNode node;
		for ( node=FirstChild; node; node=node.NextSibling )
		{
			node.Print( Stream, depth );
			Stream.write("\n");
		}
	}

	void SetError( TiXmlError err, TiXmlString errorLocation, TiXmlParsingData prevData, TiXmlEncoding encoding )
	{	
		// The first error in a chain is more accurate - don't set again!
		if ( error )
			return;
	
		error   = true;
		errorId = err;
		errorDesc = errorString[ errorId ];
	
		//errorLocation = "".dup; wtf? TODO
	}
	


	override TiXmlDocument          ToDocument()          { return this; } ///< Cast to a more defined type. Will return null not of the requested type.
	}
protected {
	override void StreamOut ( IOutputStream Stream ){
		TiXmlNode node;
		for ( node=FirstChild; node; node=node.NextSibling )
		{
			node.StreamOut( Stream );
	
			// Special rule for streams: stop after the root element.
			// The stream in code will only read one element, so don't
			// write more than one.
			if ( node.ToElement )
				break;
		}
	}

	override TiXmlNode Clone() {
	
		TiXmlDocument clone = AllocatorNew!TiXmlDocument(m_allocator, m_allocator);
		CopyTo(clone);
		clone.error = error;
		clone.errorDesc = errorDesc;
		TiXmlNode node;
		for ( node = firstChild; node; node = node.NextSibling )
		{
			clone.LinkEndChild( node.Clone );
		}
		return clone;
	}
	}


private {
	bool error = false;
	int  errorId = 0;
	string errorDesc;
	int tabsize = 4;
	TiXmlCursor errorLocation;
	bool useMicrosoftBOM = false;		// the UTF-8 BOM were found when read. Note this, and try to write.
	}
};

}

version(unittest) import thBase.devhelper;

unittest 
{
  auto leak = LeakChecker("tiny xml unittest creating xml file");
  {
    TiXmlDocument doc = New!TiXmlDocument( StdAllocator.globalInstance );
    scope(exit) Delete(doc);
    TiXmlDeclaration decl = New!TiXmlDeclaration( TiXmlString("1.0", IsStatic.Yes), 
                                                  TiXmlString("UTF-8", IsStatic.Yes), 
                                                  TiXmlString("", IsStatic.Yes),
                                                  StdAllocator.globalInstance);
    doc.LinkEndChild( decl );

    auto root = New!TiXmlElement( TiXmlString("root", IsStatic.Yes), StdAllocator.globalInstance );
    doc.LinkEndChild( root );

    for(int i=0;i<10;i++)
    {
      auto element = New!TiXmlElement( formatAllocator!IAllocator(StdAllocator.globalInstance, "element%d", i),
                                       StdAllocator.globalInstance);
      root.LinkEndChild(element);
      for(int j=0;j<5;j++)
        element.SetAttribute( formatAllocator!IAllocator(StdAllocator.globalInstance, "attribute%d", j), 
                              formatAllocator!IAllocator(StdAllocator.globalInstance, "%d",j) );
    }
    doc.SaveFile("unittest.xml");
  }
}

version(unittest)
{
  import thBase.allocator;
  import thBase.policies.locking;
  version(XML_PERFORMANCE_TEST)
  {
    import thBase.timer;
    import core.stdc.stdio;
  }
}

unittest 
{
  {
    auto leak = LeakChecker("tiny xml unittest reading file");
    {
      IAllocator[2] allocators;
      allocators[0] = StdAllocator.globalInstance;
      alias RedirectAllocator!(ChunkAllocator!(NoLockPolicy), StdAllocator, NoLockPolicy) allocator_t;
      allocators[1] = New!allocator_t
        (4*1024, New!(ChunkAllocator!(NoLockPolicy))(4*1024,16), StdAllocator.globalInstance, allocator_t.Delete.Small);

      scope(exit) Delete(allocators[1]);

      foreach(allocator; allocators)
      {
        TiXmlDocument doc = AllocatorNew!TiXmlDocument(allocator, allocator);
        scope(exit) AllocatorDelete(allocator, doc);

        doc.LoadFile(TiXmlString("unittest.xml", IsStatic.Yes));

        assert( !doc.Error() );

        TiXmlElement root = doc.FirstChildElement("root");
        assert(root !is null);

        TiXmlElement element = root.FirstChildElement();
        for(int i=0; i<10; ++i)
        {
          assert( element !is null);
          auto name = formatAllocator!IAllocator(allocator, "element%d", i);
          assert( element.Value() == name );

          for(int j=0; j<5; j++)
          {
            int result = -1;
            assert( element.QueryIntAttribute( formatAllocator!IAllocator(allocator, "attribute%d",j), result) == AttributeQueryEnum.TIXML_SUCCESS );
            assert( result == j );
          }
          element = element.NextSiblingElement();
        }
      }
    }
  }

  version(XML_PERFORMANCE_TEST)
  {
    IAllocator[2] allocators;
    allocators[0] = StdAllocator.globalInstance;
    alias RedirectAllocator!(ChunkAllocator!(NoLockPolicy), StdAllocator, NoLockPolicy) allocator_t;
    allocators[1] = GetNewTemporaryAllocator();

	  auto timer = new shared(Timer)();
    scope(exit) Delete(timer);

    printf("Xml performance test\n");
    foreach(size_t i, allocator; allocators)
    {
      auto start = Zeitpunkt(timer);

      auto doc = AllocatorNew!TiXmlDocument(allocator, allocator);

      doc.LoadFile(TiXmlString("bigXmlFile.xml", IsStatic.Yes));

      AllocatorDelete(allocator, doc);

      if(i == 1)
      {
        Delete(allocator);
      }

      auto end = Zeitpunkt(timer);
      
      if( i== 0)
      {
        printf("StdAllocator => %lf ms\n", end - start);
      }
      else
      {
        printf("TemporaryAllocator => %lf ms\n", end - start);
      }
    }
  }
}