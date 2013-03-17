module thBase.math3d.vecs;

import std.math;
import thBase.format;

/**
 * a 2 dimensional vector
 */
struct vec2 {
	union {
		struct {
			float x,y; // coordinates
		}
		float[2] f; // coordinates as array, same data as x,y
	}
	
	/**
	 * constructor
	 * Params:
	 *  x = x value
	 *  y = y value
	 */
	this(float x, float y){
		this.x = x;
		this.y = y;
	}
	
	/**
	 * constructor
	 * Params:
	 *  f = initial data
	 */
	this(float[2] f){
		this.f[0..1] = f[0..1];
	}
	
	/**
	 * adds this and another vector
	 */
	vec2 opAdd(T)(auto ref const(T) v) const if(is(T == vec2)) {
		return vec2(this.x + v.x,this.y + v.y);
	}
	
	/**
	 * subtracts this and another vector
	 */
	vec2 opSub(const ref vec2 v) const {
		return vec2(this.x - v.x,this.y - v.y);
	}
	
	
	/**
	 * multiplies this vector and a scalar
	 */
	vec2 opMul(const float f) const {
		return vec2(this.x * f, this.y * f);
	}
	
	/**

	 * multiplies this vector with another one
	 */
	vec2 opMul(const ref vec2 v) const {
      return vec2(this.x * v.x, this.y * v.y);
	}
	
	/**
	 * divides this vector through a scalar
	 */
	vec2 opDiv(const float f) const {
		return vec2(this.x / f, this.y / f);
	}
	
	/**
	 * does a dot product with another vector
	 */
	float dot(const ref vec2 v){
		return this.x * v.x + this.y * v.y;
	}
	
	/**
	 * Returns: the length of this vector
	 */
	float length(){
		return std.math.sqrt(this.x * this.x + this.y * this.y);
	}
	
	/**
	 * Returns: a normalized copy of this vector
	 */
	vec2 normalize() const {
    float length;
    vec2 temp, res=this;
    temp = this * this;
    length = cast(float)std.math.sqrt(cast(float)(temp.f[0]+temp.f[1]));
    if(length != 0){
      res = this / length;
    }
    return res;
  }
	
	struct XmlValue {
		float x,y;
	}
	
	void XmlSetValue(XmlValue value){
		x = value.x;
		y = value.y;
	}
	
	XmlValue XmlGetValue(){
		return XmlValue(x,y);
	}
};

/**
 * a 3 dimensional vector
 */
struct vec3_t(T) if(is(T == float) || is(T == short) || is(T == int)){	
	union {
		struct {
			T x=0,y=0,z=0; //x,y,z dimensions
		}
		T[3] f; // dimensions as array, same data as x,y,z
	}

  static if(is(T == float))
  {
    enum string XmlName = "vec3";
  }
  else static if(is(T == int))
  {
    enum string XmlName = "ivec3";
  }
	
	/**
	 * constructor
	 * Params:
	 *  x = x value
	 *  y = y value
	 *  z = z value
	 */
	this(T x, T y, T z) pure { 
		this.x = x; this.y = y; this.z = z;
	}
	
	/**
	 * constructor
	 * Params:
	 *  v4 = takes x,y,z from this argument
	 */
	this(ref const(vec4_t!(T)) v4) pure {
		this.f[0..3] = v4.f[0..3];
	}
	
	/// ditto
	this(vec4_t!(T) v4) pure {
		this.f[0..3] = v4.f[0..3];
	}
	
	/**
	 * constructor
	 * Params:
	 *  f = data
	 */
	this(const(T)[] f) pure
	in {
		assert(f.length == 3);
	}
	body
	{
		this.f[0..3] = f[0..3];
	}
	
	/**
	 * constructor
	 * Params:
	 *  f = uses this value for all dimensions
	 */
	this(T f) pure {
		this.x = f; this.y = f; this.z = f;
	}
	
	/**
	 * adds this vector and another one
	 */
	vec3_t!(T) opAdd(const(vec3_t!(T)) v) const pure {
		return vec3_t!(T)(cast(T)(this.x + v.x), cast(T)(this.y + v.y), cast(T)(this.z + v.z));
	}
	
	/*vec3!(T) opSub(ref const(vec3!(T)) v) const {
		return vec3!(T)(this.x - v.x, this.y - v.y, this.z - v.z);
	}*/
	
	
	/**
	 * substracts this vector and another one
	 */
	vec3_t!(T) opSub(vec3_t!(T) v) const pure {
		return vec3_t!(T)(cast(T)(this.x - v.x),cast(T)(this.y - v.y),cast(T)(this.z - v.z));
	}
	
	
	/**
	 * multiplies this vector with an scalar
	 */
	vec3_t!(T) opMul(in T f) const pure {
		return vec3_t!(T)(cast(T)(this.x * f),cast(T)(this.y * f),cast(T)(this.z * f));
	}
	
	/*vec3 opMul(ref const(vec3) v) const {
      vec3 res;
      res.x = this.x * v.x;
      res.y = this.y * v.y;
      res.z = this.z * v.z;
      return res;		
	}*/
	
	/**
	 * multiplies this vector with another one
	 */
	vec3_t!(T) opMul(vec3_t!(T) v) const pure {
      vec3_t!(T) res;
      res.x = cast(T)(this.x * v.x);
      res.y = cast(T)(this.y * v.y);
      res.z = cast(T)(this.z * v.z);
      return res;
	}
	
	/**
	 * divides this vector thorugh a scalar
	 */
	vec3_t!(T) opDiv(const(T) f) const pure {
		return vec3_t!(T)(cast(T)(this.x / f),cast(T)(this.y / f),cast(T)(this.z / f));
	}
	
	/**
	 * divides this vector thorugh another one
	 */
	vec3_t!(T) opDiv(const(vec3_t!(T)) v) const pure {
		return vec3_t!(T)(cast(T)(this.x / v.x),cast(T)(this.y / v.y),cast(T)(this.z / v.z));
	}
	
	/*vec3 opDiv(ref const(vec3) v) const {
		return vec3(this.x / v.x, this.y/v.y, this.z/v.z);
	}*/

  bool allComponents(string op)(const(vec3) rh) const if(op == "<" || op == "<=" || op == ">" || op == ">=")
  {
    return mixin("this.x " ~ op ~ " rh.x && this.y " ~ op ~ " rh.y && this.z " ~ op ~ " rh.z");
  }
	
	/**
	 * Returns: the length of this vector
	 */
	@property float length() const pure {
		return sqrt(cast(double)(this.x * this.x + this.y * this.y + this.z * this.z));
	}

  /**
   * Returns: the squared length of this vector
   */
  @property float squaredLength() const pure {
    return this.x * this.x + this.y * this.y + this.z * this.z;
  }
	
	/**
	 * returns the dot product of this and another vector
	 */
	T dot(vec3_t!(T) v) const pure {
		return cast(T)(this.x * v.x + this.y * v.y + this.z * v.z);
	}
	
	/**
	 * does the cross poduct of this and another vector
	 */
  vec3_t!(T) cross(const(vec3_t!(T)) v) const pure {
    vec3_t!(T) res;
    res.x = cast(T)(this.y * v.z - this.z * v.y);
    res.y = cast(T)(this.z * v.x - this.x * v.z);
    res.z = cast(T)(this.x * v.y - this.y * v.x);
    return res;
  }
	
	/**
	 * Returns: a normalized copy of this vector
	 */
	vec3_t!(T) normalize() const pure {
      vec3_t!(T) temp,res=this;
      temp=(this) * (this);
      T length = cast(T)std.math.sqrt(cast(float)(temp.f[0]+temp.f[1]+temp.f[2]));
      if(length != 0){
        temp.set(length);
        res = (this) / temp;
      }
      return res;
    }
	
	/**
	 * Sets all dimensions of this vector to f
	 * Params:
	 *  f = the value to set to
	 */
	void set(T f) pure {
		this.x = f; this.y = f; this.z = f;
	}
	
	/**
	 * cast operator
	 */
	vec3_t!(KT) opCast(K : vec3_t!(KT), KT)() pure 
  { 
		vec3_t!(KT) res;
		res.x = cast(KT)x;
		res.y = cast(KT)y;
		res.z = cast(KT)z;
		return res;
	}

  /**
   * += and -= operator
   */
	void opOpAssign(string op)(vec3_t!(T) rh) pure if( op == "-" || op == "+")
  {
    mixin("x"~op~"=rh.x;");
    mixin("y"~op~"=rh.y;");
    mixin("z"~op~"=rh.z;");
  }

	
	/**
	 * - unary operator
	 */
	vec3_t!(T) opUnary(string op)() pure if(op == "-")
		{
			return vec3_t!(T)(-x,-y,-z);
		}
	
	struct XmlValue {
		T x,y,z;
	}
	
	void XmlSetValue(XmlValue value){
		x = value.x;
		y = value.y;
		z = value.z;
	}
	
	XmlValue XmlGetValue(){
		return XmlValue(x,y,z);
	}
  
  rcstring toString()
  {
    return format("%s", f);
  }
}
alias vec3_t!(float) vec3;

/**
 * a 4 dimensional vector
 * most operations behave like it would be a 3 dimensional one!
 */
struct vec4_t(T) if(is(T == float) || is(T == short) || is(T == int)) {
	union {
		struct {
			T x,y,z,w; ///x,y,z,w dimensions
		}
		T[4] f; ///dimensions as array, same data as x,y,z,w
	};
	
	/**
	 * constructor
	 * Params:
	 *  x = x value
	 *  y = y value
	 *  z = z value
	 *  w = w value
	 */
	this(T x, T y, T z, T w) pure {
		this.x = x; this.y = y; this.z = z; this.w = w;
	}
	
	/**
	 * constructor
	 * Params:
	 *  f = initial data
	 */
	this(const(T)[] f) pure
	in {
		assert(f.length == 3 || f.length == 4);
	}
	body
	{
		if(f.length == 4){
			this.f[0..4] = f[0..4];
		}
		else {
			this.f[0..3] = f[0..3];
			this.f[3] = 1;
		}
	}
	
	/** 
	 * constructor
	 * Params:
	 *  v3 = used for x,y,z
	 *  w = used for w
	 */
	this(vec3_t!(T) v3, T w = cast(T)1) pure
  {
		this.f[0..3] = v3.f[0..3];
		this.w = w;
	}
	
	/**
	 * constructor
	 * Params:
	 *  all = used for x,y,z and w
	 */
	this(T all) pure
  {
		this.x = all; this.y = all; this.z = all; this.w = all; 
	}
	
	/**
	 * adds this and another vector
	 */
	vec4_t!(T) opAdd(const(vec4_t!(T)) v) const pure {
		return vec4_t!(T)(cast(T)(this.x + v.x),cast(T)(this.y + v.y),cast(T)(this.z + v.z),cast(T)(this.w + v.w));
	}
	
	/**
	 * subtracts this and another vector
	 */
	vec4_t!(T) opSub(P)(auto ref const(vec4_t!(P)) v) const pure if(is(T == P)) {
		return vec4_t!(T)(cast(T)(this.x - v.x),cast(T)(this.y - v.y),cast(T)(this.z - v.z),cast(T)(this.w - v.w));
	}
	
	/**
	 * subtracts this and another vector
	 */
	/*vec4_t!(T) opSub(vec4_t!(T) v) const {
		return vec4_t!(T)(cast(T)(this.x - v.x),cast(T)(this.y - v.y),cast(T)(this.z - v.z),cast(T)(this.w - v.w));
	}*/
	
	/**
	 * multiplies this and a scalar
	 */
	vec4_t!(T) opMul(in T f) const pure {
		return vec4_t!(T)(cast(T)(this.x * f),cast(T)(this.y * f),cast(T)(this.z * f),cast(T)(this.w * f));
	}
	
	/*vec4 opMul(ref const(vec4) v) const {
      vec4 res;
      res.x = this.x * v.x;
      res.y = this.y * v.y;
      res.z = this.z * v.z;
      res.w = this.w * v.w;
      return res;		
	}*/
	
	/**
	 * multiplies this and another vector
	 */
	vec4_t!(T) opMul(vec4_t!(T) v) const pure {
      vec4_t!(T) res;
      res.x = cast(T)(this.x * v.x);
      res.y = cast(T)(this.y * v.y);
      res.z = cast(T)(this.z * v.z);
      res.w = cast(T)(this.w * v.w);
      return res;		
	}
	
	/**
	 * divides this by a scalar
	 */
	vec4_t!(T) opDiv(const(float) f) const pure {
		return vec4_t!(T)(cast(T)(this.x / f),cast(T)(this.y / f),cast(T)(this.z / f),cast(T)(this.w / f));
	}
	
	/**
	 * divides this by another vector
	 */
	vec4_t!(T) opDiv(ref const(vec4_t!(T)) v) const pure {
		return vec4_t!(T)(cast(T)(this.x / v.x),cast(T)(this.y/v.y),cast(T)(this.z/v.z),cast(T)(this.w/v.w));
	}
	
	/**
	 * Returns: x,y,z
	 */
	vec3_t!(T) xyz() const pure {
		return vec3_t!(T)(this.x, this.y, this.z);
	}
	
	/**
	 * Returns: a normalized copy of this vector
	 */
	vec4_t!(T) normalize() const pure {
      T length;
      vec4_t!(T) temp,res=this;
      temp=(this) * (this);
      length=cast(T)std.math.sqrt(cast(float)(temp.f[0]+temp.f[1]+temp.f[2]));
      if(length != 0){
        temp.set(length);
        res = (this) / temp;
      }
      return res;
    }

	/**
	 * does the cross poduct of this and another vector
	 * $(BR) does only operate on x,y,z
	 */
    vec4_t!(T) cross(ref const(vec4_t!(T)) v) const pure {
      vec4_t!(T) res;
      res.x = cast(T)(this.y * v.z - this.z * v.y);
      res.y = cast(T)(this.z * v.x - this.x * v.z);
      res.z = cast(T)(this.x * v.y - this.y * v.x);
      res.w = cast(T)1;
      return res;
    }

	/**
	 * does a dot product of this and another vector
	 * $(BR) does only operate on x,y,z
	 */
    T dot(ref const(vec4_t!(T)) v) const pure {
      vec4_t!(T) res = this * v;
      return cast(T)(res.x + res.y + res.z);
    }

	/**
	 * Returns: a vector pointing from this vector to the other vector
	 */
	vec4_t!(T) direction(ref const(vec4_t!(T)) v) pure {
      return (v - this).normalize();
    }
	
	/**
	 * Returns: the length of this vector
	 */
	float length() const pure {
		return std.math.sqrt(cast(float)this.dot(this));
	}
	
	/**
	 * sets x,y,z,w to value
	 * Params:
	 *  value = the value to set
	 */
	void set(T value) pure
  {
		foreach(ref e;f)
			e = value;
	}
	
	/**
	 * - unary operator
	 */
	vec4_t!(T) opUnary(string op)() const pure if(op == "-")
		{
			return vec4_t!(T)(-x,-y,-z,-w);
		}
	
	struct XmlValue {
		T x,y,z,w;
	}
	
	void XmlSetValue(XmlValue value){
		x = value.x;
		y = value.y;
		z = value.z;
		w = value.w;
	}
	
	XmlValue XmlGetValue(){
		return XmlValue(x,y,z,w);
	}
};
alias vec4_t!(float) vec4;

version(unittest)
{
  import thBase.traits;
}

unittest {
  static assert(IsPOD!vec4, "vec4 is not a POD");
  static assert(IsPOD!vec3, "vec3 is not a POD");
  static assert(IsPOD!vec2, "vec2 is not a POD");

	const(vec4) v1 = vec4(1,1,1,1);
	const(vec4) v2 = vec4(2,2,2,2);
	const(vec4) v3 = vec4(3,3,3,3);
	
	vec4 res = (v1.normalize() + v2) / v3;
}

/**
 * does floor on all 4 dimensions
 * Returns: the resulting vector
 */
vec4_t!(T) floor(V : vec4_t!(T), T)(V v) if(is(T == float) || is(T == double)){
	return vec4_t!(T)(cast(T)std.math.floor(v.x),
				cast(T)std.math.floor(v.y),
				cast(T)std.math.floor(v.z),
				cast(T)std.math.floor(v.w));
}

vec3_t!(T) floor(V : vec3_t!(T), T)(V v) if(is(T == float) || is(T == double)) {
	return vec3_t!(T)(cast(T)std.math.floor(v.x),
					  cast(T)std.math.floor(v.y),
					  cast(T)std.math.floor(v.z));
}

/**
 * does ceil on all 4 dimensions
 * Returns: the resulting vector
 */
vec4 ceil(vec4 v)
{
	return vec4(std.math.ceil(v.x),std.math.ceil(v.y),std.math.ceil(v.z),std.math.ceil(v.w));
}

/// ditto
vec4 ceil(ref const(vec4) v)
{
	return vec4(std.math.ceil(v.x),std.math.ceil(v.y),std.math.ceil(v.z),std.math.ceil(v.w));
}

inout(T) minimum(T)(ref inout(T) v1,ref inout(T) v2) pure
{
  T result;
  result.x = (v1.x < v2.x) ? v1.x : v2.x;
  result.y = (v1.y < v2.y) ? v1.y : v2.y;
  static if(is(typeof(v1.z)))
    result.z = (v1.z < v2.z) ? v1.z : v2.z;
  static if(is(typeof(v1.w)))
    result.w = (v1.w < v2.w) ? v1.w : v2.w;
  return result;
}

inout(T) maximum(T)(ref inout(T) v1,ref inout(T) v2) pure
{
  T result;
  result.x = (v1.x > v2.x) ? v1.x : v2.x;
  result.y = (v1.y > v2.y) ? v1.y : v2.y;
  static if(is(typeof(v1.z)))
    result.z = (v1.z > v2.z) ? v1.z : v2.z;
  static if(is(typeof(v1.w)))
    result.w = (v1.w > v2.w) ? v1.w : v2.w;
  return result;
}

unittest {
	vec4 v1 = vec4(-0.1f,-0.1f,-0.1f,-0.1f);
	vec4 res1 = floor(v1);
	assert(res1.x == -1.0f && res1.y == -1.0f && res1.z == -1.0f && res1.w == -1.0f);
	
	vec3 v2 = vec3(-0.1f,-0.1f,-0.1f);
	vec3 res2 = floor(v2);
	assert(res2.x == -1.0f && res2.y == -1.0f && res2.z == -1.0f);

  vec3 v3 = vec3(0.1f, 0.1f, 0.1f);
  vec3 res3 = floor(v3);
  assert(res3.x == 0.0f && res3.y == 0.0f && res3.z == 0.0f);
}
