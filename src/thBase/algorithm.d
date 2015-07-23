module thBase.algorithm;
import thBase.traits;
import core.traits;
import core.refcounted;
import std.traits;
import core.stdc.string : memcpy;

version(unittest) import thBase.devhelper;

sizediff_t find(alias pred,T,U)(T a, U c) 
  if(thBase.traits.isArray!T && is(StripModifier!U == StripModifier!(arrayType!T)))
{
  foreach(i,el;a[])
  {
    if(pred(el,c))
      return i;
  }
  return -1;
}

version(unittest)
{
  import std.uni;
}

unittest
{
  auto leak = LeakChecker("find char in string with compare lambda");
  {
  auto bla = _T("Hello World");
  assert(find!((immutable(char) a, char b){ return std.uni.toLower(a) == std.uni.toLower(b); })
         (bla,'h') == 0);
  assert(find!((immutable(char) a, char b){ return std.uni.toLower(a) == std.uni.toLower(b); })
         (bla,'w') == 6);
  assert(find!((immutable(char) a, char b){ return std.uni.toLower(a) == std.uni.toLower(b); })
         (bla,'z') == -1);
  }
}

sizediff_t find(T,U)(T a, U c) 
if(thBase.traits.isArray!T && is(StripModifier!(arrayType!T) == StripModifier!U))
{
  foreach(i,el;a[])
  {
    if(el == c)
      return i;
  }
  return -1;
}

unittest 
{
  auto leak = LeakChecker("find char in array");
  {
    auto bla = _T("Hello World");
    assert(find(bla,'H') == 0);
    assert(find(bla,'W') == 6);
    assert(find(bla,'Z') == -1);
  }
}

// find one array in the other
sizediff_t find(T,U)(T a1, U a2)
 if(thBase.traits.isArray!T && thBase.traits.isArray!U 
    && is(StripModifier!(arrayType!T) == StripModifier!(arrayType!U)))
 {
  sizediff_t maxSkip = find(a2[1..a2.length],a2[0]);
  if(maxSkip < 0)
    maxSkip = sizediff_t.max;
  else
    maxSkip++;
  auto len1 = a1.length;
  auto len2 = a2.length;
  for(size_t i = 0; i < a1.length; ++i)
  {
    size_t j = 0;
    while(j < len2 && a1[i+j] == a2[j])
      j++;
    if(j == len2)
      return i;
    else if( j > 0)
      i += ( j < maxSkip) ? j - 1 : maxSkip - 1;
  }
  return -1;
}

unittest 
{
  auto leak = LeakChecker("Find array in array unittest");
  {
    auto result = find(_T("bbrbrobrotbrot"),_T("brotbrot"));
    assert(result == 6);

    result = find(_T("bbrbrobrotbrot"),_T("brot"));
    assert(result == 6);

    result = find(_T("Hello  World"), _T("World"));
    assert(result == 7);
  }
}

sizediff_t find(alias pred,T,U)(T a1, U a2)
if(thBase.traits.isArray!T && thBase.traits.isArray!U 
   && (is(arrayType!T == char) || is(arrayType!T == wchar))
   && is(StripModifier!(arrayType!T) == StripModifier!(arrayType!U)))
{
  foreach(i, dchar c1; a1[])
  {
    bool found = true;
    foreach(dchar c2; a2[])
    {
      if(!pred(c1,c2))
      {
        found = false;
        break;
      }
    }
    if(found)
      return i;
  }
  return -1;
}


unittest 
{
  auto leak = LeakChecker("Find array in array unittest");
  {
    auto result = find!((dchar c1, dchar c2){ return std.uni.toLower(c1) == std.uni.toLower(c2); })
      (_T("BbrBrobRoTbrOt"),_T("broTbRot"));
    assert(result == 6);

    result = find!((dchar c1, dchar c2){ return std.uni.toLower(c1) == std.uni.toLower(c2); })
      (_T("BbrBrobRoTbrOt"),_T("broT"));
    assert(result == 6);

    result = find!((dchar c1, dchar c2){ return std.uni.toLower(c1) == std.uni.toLower(c2); })
      (_T("Hello  World"), _T("worlD"));
    assert(result == 7);
  }
}

sizediff_t find(alias pred,T,U)(T a1, U a2)
if(thBase.traits.isArray!T && thBase.traits.isArray!U
   && !is(arrayType!T == char) && !is(arrayType!T == wchar)
   && is(StripModifier!(arrayType!T) == StripModifier!(arrayType!U)))
{
  sizediff_t maxSkip = find!(pred)(a2[1..a2.length],a2[0]);
  if(maxSkip < 0)
    maxSkip = sizediff_t.max;
  else
    maxSkip++;
  auto len1 = a1.length;
  auto len2 = a2.length;
  for(size_t i = 0; i < a1.length; ++i)
  {
    size_t j = 0;
    while(j < len2 && pred(a1[i+j],a2[j]))
      j++;
    if(j == len2)
      return i;
    else if( j > 0)
      i += ( j < maxSkip) ? j - 1 : maxSkip - 1;
  }
  return -1;
}

unittest {
  auto leak = LeakChecker("find array in array unittest");
  {
    __gshared int[] haystack = [1,2,3,4];
    __gshared int[] needle = [2,3];

    auto result = find!((int i1, int i2){ return i1 == i2; })(haystack,needle);
    assert(result == 1);
  }
}

void swap(T)(ref T value1, ref T value2)
{
  static if(__traits(hasMember, T, "swap") && isSomeFunction!(typeof(__traits(getMember, T, "swap"))))
  {
    value1.swap(value2);
  }
  else static if(HasPostblit!T)
  {
    //if the value has a postblit operator it means that it most likley tracks a big block of memory internally
    //using memcpy to swap will avoid calling assignment or postblit operations
    //which is valid because value types don't have identity
    void[T.sizeof] temp = void;
    memcpy(temp.ptr, &value1, T.sizeof);
    memcpy(&value1, &value2, T.sizeof);
    memcpy(&value2, temp.ptr, T.sizeof);
  }
  else
  {
    //classical swap
    T temp = value1;
    value1 = value2;
    value2 = temp;
  }
}

void insertionSort(alias less=quicksortLess, T)(T data) if(isRCArray!T)
{
  insertionSort!less(data[]);
}

void insertionSort(alias less=quicksortLess, T)(T data) if(!isRCArray!T)
{
  for(size_t sorted = 1; sorted < data.length; sorted++)
  {
    ptrdiff_t insertPos = sorted-1;
    auto temp = data[sorted];
    while(insertPos >= 0 && less(temp, data[insertPos]))//data[insertPos] > temp)
      insertPos--;
    insertPos++;
    if(insertPos != sorted)
    {
      for(size_t i=sorted; i>insertPos; i--)
      {
        data[i] = data[i-1];
      }
      data[insertPos] = temp;
    }
  }
}

unittest
{
  auto leak = LeakChecker("thBase.algorithm.insertionSort unittest");
  {
    int[] data = [5,3,7,9,2,1,6];
    scope(exit) Delete(data);
    insertionSort(data);
    assert(data[0] == 1);
    assert(data[1] == 2);
    assert(data[2] == 3);
    assert(data[3] == 5);
    assert(data[4] == 6);
    assert(data[5] == 7);
    assert(data[6] == 9);
  }
}

bool quicksortLess(T)(auto ref T lhs, auto ref T rhs)
{
  return lhs < rhs;
}

private size_t quicksortSwap(alias less, T)(T data)
{
  size_t mediatorIndex = 0;
  static if(is(StripModifier!(arrayType!T) == class) || is(StripModifier!(arrayType!T) == interface) || isNumeric!(arrayType!T))
  {
    arrayType!T[3] med;
    med[0] = data[0];
    med[1] = data[$/2];
    med[2] = data[$-1];

    if(less(med[1], med[0]))// med[0] > med[1])
    {
      if(less(med[2], med[0]))// med[0] > med[2])
      {
        if(less(med[2], med[1]))// med[1] > med[2])
          mediatorIndex = data.length / 2;
        else
          mediatorIndex = data.length - 1;
      }
      //else med[0] already correct
    }
    else
    {
      if(less(med[0], med[2]))//med[0] < med[2])
      {
        if(less(med[1], med[2]))//med[1] < med[2])
          mediatorIndex = data.length / 2;
        else
          mediatorIndex = data.length - 1;
      }
      //else med[0] already correct
    }
  }
  else
  {
    arrayType!T*[3] med;
    med[0] = &data[0];
    med[1] = &data[$/2];
    med[2] = &data[$-1];

    if(less(*med[1], *med[0]))//*med[0] > *med[1])
    {
      if(less(*med[2], *med[0]))//*med[0] > *med[2])
      {
        if(less(*med[2], *med[1]))//*med[1] > *med[2])
          mediatorIndex = data.length / 2;
        else
          mediatorIndex = data.length - 1;
      }
      //else med[0] already correct
    }
    else
    {
      if(less(*med[0], *med[2]))//*med[0] < *med[2])
      {
        if(less(*med[1], *med[2]))//*med[1] < *med[2])
          mediatorIndex = data.length / 2;
        else
          mediatorIndex = data.length - 1;
      }
      //else med[0] already correct
    }
  }

  if(mediatorIndex != data.length -1)
  {
    swap(data[mediatorIndex], data[$-1]);
  }

  size_t smallerIndex = 0; size_t biggerIndex = data.length - 2;
  size_t end = data.length - 1;
  while(true)
  {
    while(smallerIndex < end && !less(data[end], data[smallerIndex]))//data[smallerIndex] <= data[$-1])
      smallerIndex++;
    while(biggerIndex > 0 && !less(data[biggerIndex], data[end]))//data[biggerIndex] >= data[$-1])
      biggerIndex--;
    if(biggerIndex <= smallerIndex)
      break;
    swap(data[smallerIndex], data[biggerIndex]);
  }
  if(smallerIndex < end)
    swap(data[smallerIndex], data[end]);
  return smallerIndex;
}

/**
 * sorts the array using the quicksort algorithm
 */
void quicksort(alias less = quicksortLess, T)(T data) if(!isRCArray!T)
{
  if(data.length > 1)
  {
    size_t smallerIndex = quicksortSwap!less(data);
    quicksort(data[0..smallerIndex]);
    quicksort(data[(smallerIndex+1)..$]);
  }
}

///ditto
void quicksort(T)(T data) if(isRCArray!T)
{
  sort(data[]);
}

unittest
{
  int[] data1 = [9,8,7,6,5,4,3,2,1];
  scope(exit) Delete(data1);
  int[] sorted = [1,2,3,4,5,6,7,8,9];
  scope(exit) Delete(sorted);
  quicksort(data1);
  assert(data1 == sorted);

  int[] data2 = [9,6,4,2,3,5,8,1,7];
  scope(exit) Delete(data2);
  quicksort(data2);
  assert(data2 == sorted);

  int[] data3 = [2,1];
  scope(exit) Delete(data3);
  quicksort(data3);
  assert(data3[0] == 1);
  assert(data3[1] == 2);
}

/**
 * Sorts the array using the fastest known general purpose sorting algorithm
 */
void sort(T)(T data) if(isRCArray!T)
{
  sort(data[]);
}

/// ditto
void sort(alias less=quicksortLess, T)(T data) if(!isRCArray!T)
{
  if(data.length < 16)
  {
    insertionSort!less(data);
  }
  else
  {
    size_t smallerIndex = quicksortSwap!less(data);
    sort!less(data[0..smallerIndex]);
    sort!less(data[(smallerIndex+1)..$]);
  }  
}

/**
 * does a binary search for target
 */
ptrdiff_t binarySearch(alias less, T,ET)(T data, ET target) if(isRCArray!T)
{
  return binarySearch!(less)(data[], element);
}

/// ditto
ptrdiff_t binarySearch(alias less, T, ET)(T data, ET target) if(!isRCArray!T)
{
  assert(data.length < ptrdiff_t.max, "array to big for binary search");
  ptrdiff_t lowerBound = 0;
  ptrdiff_t upperBound = data.length - 1;
  while(lowerBound < upperBound)
  {
    ptrdiff_t middle = lowerBound + (upperBound - lowerBound) / 2;
    
    if(less(data[middle], target))
      lowerBound = middle + 1;
    else if(less(target, data[middle]))
      upperBound = middle - 1;
    else
      return middle;
  }
  return -1;
}

/**
* does a binary search for target, returns the index the element should be at if it is not found
*/
size_t binarySearchInsertIndex(alias less, T,ET)(T data, ET target) if(isRCArray!T)
{
  return binarySearchInsertIndex!(less)(data[], element);
}

size_t binarySearchInsertIndex(alias less, T, ET)(T data, ET target) if(!isRCArray!T)
{
  if(data.length == 0)
    return 0;
  assert(data.length < ptrdiff_t.max, "array to big for binary search");
  ptrdiff_t lowerBound = 0;
  ptrdiff_t upperBound = data.length - 1;
  while(lowerBound < upperBound)
  {
    size_t middle = lowerBound + (upperBound - lowerBound) / 2;

    if(less(data[middle], target))
      lowerBound = middle + 1;
    else if(less(target, data[middle]))
      upperBound = middle - 1;
    else
      return middle;
  }
  if(less(data[lowerBound], target))
    return lowerBound+1;
  return lowerBound;
}

unittest {
  int[4] a;
  a[0] = 2;
  a[1] = 4;
  a[2] = 6;
  a[3] = 8;
  assert(binarySearchInsertIndex!((x,y){return x < y;})(a[0..3], 1) == 0);
  assert(binarySearchInsertIndex!((x,y){return x < y;})(a[0..3], 0) == 0);
  assert(binarySearchInsertIndex!((x,y){return x < y;})(a[0..3], 3) == 1);
  assert(binarySearchInsertIndex!((x,y){return x < y;})(a[0..3], 5) == 2);
  assert(binarySearchInsertIndex!((x,y){return x < y;})(a[0..3], 7) == 3);

  assert(binarySearchInsertIndex!((x,y){return x < y;})(a, 1) == 0);
  assert(binarySearchInsertIndex!((x,y){return x < y;})(a, 0) == 0);
  assert(binarySearchInsertIndex!((x,y){return x < y;})(a, 3) == 1);
  assert(binarySearchInsertIndex!((x,y){return x < y;})(a, 5) == 2);
  assert(binarySearchInsertIndex!((x,y){return x < y;})(a, 7) == 3);
  assert(binarySearchInsertIndex!((x,y){return x < y;})(a, 9) == 4);
}

T move(T)(ref T value)
{
  T result;
  memcpy(&result, &value, T.sizeof);

  static if(HasPostblit!T || needsDestruction!T)
  {
    T empty;
    memcpy(&value, &empty, T.sizeof);
  }

  return result;
}