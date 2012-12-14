module thBase.utf;

import core.refcounted;
import thBase.traits;
import core.traits;
import std.typetuple;

class UTFException : RCException
{
  public:

  uint[4] sequence;
  size_t character;

  this(rcstring msg, size_t character, string file = __FILE__, size_t line = __LINE__)
  {
    super(msg,file,line);
    this.character = character;
  }

  void setSequence(uint[] seq)
  {
    this.sequence[] = seq[];
  }
}

/++
--- Taken from phobos std.utf http://github.com/D-Programming-Language/phobos ---

Returns whether $(D c) is a valid UTF-32 character.

$(D '\uFFFE') and $(D '\uFFFF') are considered valid by $(D isValidDchar),
as they are permitted for internal use by an application, but they are
not allowed for interchange by the Unicode standard.
+/
@safe
pure nothrow bool isValidDchar(dchar c)
{
  /* Note: FFFE and FFFF are specifically permitted by the
  * Unicode standard for application internal use, but are not
  * allowed for interchange.
  * (thanks to Arcane Jill)
  */

  return c < 0xD800 ||
    (c > 0xDFFF && c <= 0x10FFFF /*&& c != 0xFFFE && c != 0xFFFF*/);
}

unittest
{
  debug(utf) printf("utf.isValidDchar.unittest\n");
  assert(isValidDchar(cast(dchar)'a') == true);
  assert(isValidDchar(cast(dchar)0x1FFFFF) == false);

  assert(!isValidDchar(cast(dchar)0x00D800));
  assert(!isValidDchar(cast(dchar)0x00DBFF));
  assert(!isValidDchar(cast(dchar)0x00DC00));
  assert(!isValidDchar(cast(dchar)0x00DFFF));
  assert(isValidDchar(cast(dchar)0x00FFFE));
  assert(isValidDchar(cast(dchar)0x00FFFF));
  assert(isValidDchar(cast(dchar)0x01FFFF));
  assert(isValidDchar(cast(dchar)0x10FFFF));
  assert(!isValidDchar(cast(dchar)0x110000));
}

/++
--- Taken from phobos std.utf http://github.com/D-Programming-Language/phobos ---

Decodes and returns the character starting at $(D str[index]). $(D index)
is advanced to one past the decoded character. If the character is not
well-formed, then a $(D UTFException) is thrown and $(D index) remains
unchanged.

Throws:
$(D UTFException) if $(D str[index]) is not the start of a valid UTF
sequence.
+/
dchar decode(S)(S str, ref size_t index) @trusted
if( thBase.traits.isSomeString!S && is(StripModifier!(arrayType!S) == char))
in
{
  assert(index < str.length, "Attempted to decode past the end of a string");
}
body
{
  if (str[index] < 0x80)
    return str[index++];
  else
    return decodeImpl(str.ptr + index, str.length - index, index);
}

/*
* This function does it's own bounds checking to give a more useful
* error message when attempting to decode past the end of a string.
* Subsequently it uses a pointer instead of an array to avoid
* redundant bounds checking.
*/
private dchar decodeImpl(const(char)* pstr, size_t length, ref size_t index) @trusted
in
{
  assert(pstr[0] & 0x80);
}
body
{
  /* The following encodings are valid, except for the 5 and 6 byte
  * combinations:
  *  0xxxxxxx
  *  110xxxxx 10xxxxxx
  *  1110xxxx 10xxxxxx 10xxxxxx
  *  11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
  *  111110xx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
  *  1111110x 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
  */

  /* Dchar bitmask for different numbers of UTF-8 code units.
  */
  enum bitMask = [(1 << 7) - 1, (1 << 11) - 1, (1 << 16) - 1, (1 << 21) - 1];

  ubyte fst = pstr[0], tmp=void;
  dchar d = fst; // upper control bits are masked out later
  fst <<= 1;

  foreach(i; TypeTuple!(1, 2, 3))
  {
    if (i == length)
      goto Ebounds;

    tmp = pstr[i];

    if ((tmp & 0xC0) != 0x80)
      goto Eutf;

    d = (d << 6) | (tmp & 0x3F);
    fst <<= 1;

    if (!(fst & 0x80)) // no more bytes
    {
      d &= bitMask[i]; // mask out control bits

      // overlong, could have been encoded with i bytes
      if ((d & ~bitMask[i - 1]) == 0)
        goto Eutf;

      // check for surrogates only needed for 3 bytes
      static if (i == 2)
      {
        if (!isValidDchar(d))
          goto Eutf;
      }

      index += i + 1;
      return d;
    }
  }

  static UTFException exception(const(char)[] str, rcstring msg)
  {
    uint[4] sequence = void;
    size_t i;
    do
    {
      sequence[i] = str[i];
    } while (++i < str.length && i < 4 && (str[i] & 0xC0) == 0x80);

    auto ex = New!UTFException(msg, i);
    ex.setSequence(sequence[0 .. i]);
    return ex;
  }

Eutf:
  throw exception(pstr[0 .. length], _T("Invalid UTF-8 sequence"));
Ebounds:
  throw exception(pstr[0 .. length], _T("Attempted to decode past the end of a string"));
}

/* =================== Encode ======================= */

/++
Encodes $(D c) into the static array, $(D buf), and returns the actual
length of the encoded character (a number between $(D 1) and $(D 4) for
$(D char[4]) buffers and a number between $(D 1) and $(D 2) for
$(D wchar[2]) buffers.

Throws:
$(D UTFException) if $(D c) is not a valid UTF code point.
+/
size_t encode(ref char[4] buf, dchar c) @trusted
{
  if (c <= 0x7F)
  {
    assert(isValidDchar(c));
    buf[0] = cast(char)c;
    return 1;
  }
  if (c <= 0x7FF)
  {
    assert(isValidDchar(c));
    buf[0] = cast(char)(0xC0 | (c >> 6));
    buf[1] = cast(char)(0x80 | (c & 0x3F));
    return 2;
  }
  if (c <= 0xFFFF)
  {
    if (0xD800 <= c && c <= 0xDFFF)
      throw (New!UTFException(_T("Encoding a surrogate code point in UTF-8"), c));

    assert(isValidDchar(c));
    buf[0] = cast(char)(0xE0 | (c >> 12));
    buf[1] = cast(char)(0x80 | ((c >> 6) & 0x3F));
    buf[2] = cast(char)(0x80 | (c & 0x3F));
    return 3;
  }
  if (c <= 0x10FFFF)
  {
    assert(isValidDchar(c));
    buf[0] = cast(char)(0xF0 | (c >> 18));
    buf[1] = cast(char)(0x80 | ((c >> 12) & 0x3F));
    buf[2] = cast(char)(0x80 | ((c >> 6) & 0x3F));
    buf[3] = cast(char)(0x80 | (c & 0x3F));
    return 4;
  }

  assert(!isValidDchar(c));
  throw (New!UTFException(_T("Encoding an invalid code point in UTF-8"), c));
}

/*
 From here on my own implementations
*/

/* ============ Decode Reverse ============= */

/+
Decodes and returns the character starting at $(D str[index]). $(D index)
is decremented to one past the decoded character. If the character is not
well-formed, then a $(D UTFException) is thrown and $(D index) remains
unchanged.

Throws:
$(D UTFException) if $(D str[index]) is not the end of a valid UTF
sequence.
+/
dchar decodeReverse(S)(S str, ref size_t index) @trusted
if( thBase.traits.isSomeString!S && is(StripModifier!(arrayType!S) == char))
in
{
  assert(index < str.length, "Decode out of bounds");
}
body
{
  if (str[$-index-1] < 0x80)
    return str[$-1-(index++)];
  else
    return decodeReverseImpl(str.ptr, str.length, index);
}


/*
* This function does it's own bounds checking to give a more useful
* error message when attempting to decode past the end of a string.
* Subsequently it uses a pointer instead of an array to avoid
* redundant bounds checking.
*/
private dchar decodeReverseImpl(const(char)* pstr, size_t len, ref size_t index) @trusted
{
  /* The following encodings are valid, except for the 5 and 6 byte
  * combinations:
  *  0xxxxxxx
  *  110xxxxx 10xxxxxx
  *  1110xxxx 10xxxxxx 10xxxxxx
  *  11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
  *  111110xx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
  *  1111110x 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
  */

  /* Dchar bitmask for different numbers of UTF-8 code units.
  */
  enum bitMask = [0, 0xc0, 0xe0, 0xf0]; 

  uint charLen = 0;
  dchar result = 0;

  foreach(i; TypeTuple!(0,1,2,3))
  {
    sizediff_t pos = len - index - i - 1;
    if(pos < 0)
      goto Ebounds;

    dchar c = pstr[pos];

    if((c & 0xC0) == 0x80)
    {
      charLen++;
    }
    else
    {
      if(i != charLen)
        goto Eutf;

      if((c & bitMask[i]) != bitMask[i])
        goto Eutf;

      result = (c & (~bitMask[i])) << (i * 6);
      break;
    }
  }

  for(uint i=1; i<=charLen; i++)
  {
    result |= (pstr[len-index-i] & 0x3f) << ((charLen-i) * 6);
  }

  index += charLen+1;
  return result;


  static UTFException exception(const(char)[] str, rcstring msg)
  {
    uint[4] sequence = void;
    size_t i=0;
    do
    {
      sequence[i] = str[i];
    } while (++i < str.length && i < 4 && (str[i] & 0xC0) == 0x80);

    auto ex = New!UTFException(msg, i);
    ex.setSequence(sequence[0 .. i]);
    return ex;
  }

Eutf:
  throw exception(pstr[(len-index-charLen-1) .. len], _T("Invalid UTF-8 sequence") );
Ebounds:
  throw exception(pstr[(len-index-charLen-1) .. len], _T("Attempted to decode past the end of a string") );
}

version(unittest)
{
  import thBase.devhelper;
}

unittest
{
  auto leak = LeakChecker("thBase.utf.decodeReverse unittest");
  {
    size_t index;

    assert(decodeReverse("A", index) == 'A');
    assert(index == 1);

    index = 0;
    dchar result = decodeReverse("ш", index);
    assert(result == 'ш');
    assert(index == 2);

    auto test = "Мaшa";
    auto testResult = "Мaшa"d;
    index = 0;
    foreach(size_t i, dchar d; testResult)
    {
      result = decodeReverse(test, index);
      switch(i)
      {
        case 0:
          assert(result == 'a');
          assert(index == 1);
          break;
        case 1:
          assert(result == 'ш');
          assert(index == 3);
          break;
        case 2:
          assert(result == 'a');
          assert(index == 4);
          break;
        case 3:
          assert(result == 'М');
          assert(index == 6);
          break;
        default:
          assert(0, "non handeled index");
      }
    }
  }
}