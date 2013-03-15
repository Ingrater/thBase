module thBase.math3d.quaternion;

import thBase.math3d.vecs;
import thBase.math3d.mats;
import std.math;
import thBase.math : FloatEpsilon;
import core.stdc.stdio;
import rtti;

struct Quaternion {
  union
  {
    struct
    {
	    float x,y,z,angle;
    }
    float[4] f;
  }
	
	/**
	 * constructor
	 * Params:
	 *  axis = the rotation axis
	 *  angle = how much to rotate in degrees
	 */
	this(vec3 axis, float angle){
	  angle = angle / 180.0f * PI;
	  angle /= 2;
	  float temp = sin(angle);
	  
	  this.x = axis.x * temp;
	  this.y = axis.y * temp;
	  this.z = axis.z * temp;
	  this.angle = cos(angle);
	}
	
	//ditto
	this(vec4 axis, float angle){
		this(vec3(axis),angle);
	}
	
	/**
	 * constructs a quaternion from a rotation matrix
	 */
	this(mat3 rot){
		float trace = 1.0f + rot.f[0] + rot.f[4] + rot.f[8];
    if(trace > 0.00000001f)
    {
      float S = sqrt(trace) * 2.0f;
      this.x = ( rot.f[7] - rot.f[5] ) / S;
      this.y = ( rot.f[2] - rot.f[6] ) / S;
      this.z = ( rot.f[3] - rot.f[1] ) / S;
      this.angle = 0.25 * S;
    }
    else
    {
      if( rot.f[0] > rot.f[4] && rot.f[0] > rot.f[8] ) //Column 0:
      {
        float S = sqrt( 1.0f + rot.f[0] - rot.f[4] - rot.f[8] ) * 2;
        this.x = 0.25f * S;
        this.y = ( rot.f[3] + rot.f[1] ) / S;
        this.z = ( rot.f[2] + rot.f[6] ) / S;
        this.angle = ( rot.f[7] - rot.f[5] ) / S;
      }
      else if( rot.f[4] > rot.f[8] ) // Column 1:
      { 
        float S = sqrt( 1.0f + rot.f[4] - rot.f[0] - rot.f[8] ) * 2.0f;
        this.x = ( rot.f[3] + rot.f[1] ) / S;
        this.y = 0.25f * S;
        this.z = ( rot.f[7] + rot.f[5] ) / S;
        this.angle = ( rot.f[2] - rot.f[6] ) / S;
      }
      else 
      {
        float S = sqrt( 1.0f + rot.f[8] - rot.f[0] - rot.f[4] ) * 2.0f;
        this.x = ( rot.f[2] + rot.f[6] ) / S;
        this.y = ( rot.f[7] + rot.f[5] ) / S;
        this.z = 0.25f * S;
        this.angle = ( rot.f[3] - rot.f[1] ) / S;
      }
    }
	}
	
	/**
	 * Normalizes the quaternion
	 * Returns: the normalized quaternion
	 */
	Quaternion normalize() const pure {
	  Quaternion res;
	  float length = sqrt(x * x + y * y + z * z + angle * angle);
	  if(length != 0){
		  res.x = x / length;
		  res.y = y / length;
		  res.z = z / length;
		  res.angle = angle / length;
	  }
	  return res;		
	}
	
	/**
	 * Returns: the inverse of this quaternion
	 */
	Quaternion inverse() const pure {
		Quaternion res;
		res.x = x * -1;
		res.y = y * -1;
		res.z = z * -1;
		res.angle = angle;
		return res;
	}
	
	/**
	 * Converts this quaternion into a rotation matrix
	 * Returns: the matrix
	 */
	mat4 toMat4() const pure
	in {
		assert(isValid());
	}
	body {
	  mat4 mat;
	  Quaternion norm = normalize();
	  float xx  = norm.x * norm.x;
	  float xy  = norm.x * norm.y;
	  float xz  = norm.x * norm.z;
	  float xw  = norm.x * norm.angle;
	  float yy  = norm.y * norm.y;
	  float yz  = norm.y * norm.z;
	  float yw  = norm.y * norm.angle;
	  float zz  = norm.z * norm.z;
	  float zw  = norm.z * norm.angle;
	  mat.f[0]  = 1.0f - 2.0f * ( yy + zz );
	  mat.f[1]  =        2.0f * ( xy - zw );
	  mat.f[2]  =        2.0f * ( xz + yw );
	  mat.f[4]  =        2.0f * ( xy + zw );
	  mat.f[5]  = 1.0f - 2.0f * ( xx + zz );
	  mat.f[6]  =        2.0f * ( yz - xw );
	  mat.f[8]  =        2.0f * ( xz - yw );
	  mat.f[9]  =        2.0f * ( yz + xw );
	  mat.f[10] = 1.0f - 2.0f * ( xx + yy );
	  mat.f[3]  = mat.f[7] = mat.f[11] = mat.f[12] = mat.f[13] = mat.f[14] = 0.0f;
	  mat.f[15] = 1.0f;
	  return mat;
	}

	mat3 toMat3() const pure
    in {
      assert(isValid());
    }
	body {
	  mat3 mat;
	  Quaternion norm = normalize();
	  float xx  = norm.x * norm.x;
	  float xy  = norm.x * norm.y;
	  float xz  = norm.x * norm.z;
	  float xw  = norm.x * norm.angle;
	  float yy  = norm.y * norm.y;
	  float yz  = norm.y * norm.z;
	  float yw  = norm.y * norm.angle;
	  float zz  = norm.z * norm.z;
	  float zw  = norm.z * norm.angle;
	  mat.f[0] = 1.0f - 2.0f * ( yy + zz );
	  mat.f[1] =        2.0f * ( xy - zw );
	  mat.f[2] =        2.0f * ( xz + yw );
	  mat.f[3] =        2.0f * ( xy + zw );
	  mat.f[4] = 1.0f - 2.0f * ( xx + zz );
	  mat.f[5] =        2.0f * ( yz - xw );
	  mat.f[6] =        2.0f * ( xz - yw );
	  mat.f[7] =        2.0f * ( yz + xw );
	  mat.f[8] = 1.0f - 2.0f * ( xx + yy );
	  return mat;
	}
	
	/// * operator
	Quaternion opBinary(string op)(in Quaternion rh) const pure if(op == "*"){
	  Quaternion res;
	  res.x     = this.angle * rh.x     + this.x * rh.angle + this.y * rh.z - this.z * rh.y;
	  res.y     = this.angle * rh.y     + this.y * rh.angle + this.z * rh.x - this.x * rh.z;
	  res.z     = this.angle * rh.z     + this.z * rh.angle + this.x * rh.y - this.y * rh.x;
	  res.angle = this.angle * rh.angle - this.x * rh.x     - this.y * rh.y - this.z * rh.z;
	  return res;		
	}

  Quaternion opBinary(string op)(in float rh) const pure if(op == "*")
  {
    Quaternion res;
    res.x = this.x * rh;
    res.y = this.y * rh;
    res.z = this.z * rh;
    res.angle = this.angle * rh;
    return res;
  }
	
	bool isValid() const pure {
		return (!(x != x) && !(y != y) && !(z != z) && !(angle != angle) &&
				x != float.infinity && y != float.infinity && z != float.infinity && angle != float.infinity);
	}
	
	
	struct XmlValue {
		float x, y, z, angle;
	}
	
	void XmlSetValue(XmlValue value){
		x = value.x;
		y = value.y;
		z = value.z;
		angle = value.angle;
	}
	
	XmlValue XmlGetValue() const pure {
		return XmlValue(x, y, z, angle);
	}

  Quaternion Integrate(in vec3 angularVelocity, float deltaTime) const pure
  {
    Quaternion deltaQ;
    vec3 scaledAngularVelocity = angularVelocity * (deltaTime * 0.5f);
    float squaredVelocityLength = scaledAngularVelocity.squaredLength;

    float s = 1.0f;

    if(squaredVelocityLength * squaredVelocityLength / 24.0f < FloatEpsilon)
    {
      deltaQ.angle = 1.0f - squaredVelocityLength / 2.0f;
      s = 1.0f - squaredVelocityLength / 6.0f;
    }
    else
    {
      float velocityLength = sqrt(squaredVelocityLength);

      deltaQ.angle = cos(velocityLength);
      s = sin(velocityLength) / velocityLength;
    }

    deltaQ.x = scaledAngularVelocity.x * s;
    deltaQ.y = scaledAngularVelocity.y * s;
    deltaQ.z = scaledAngularVelocity.z * s;

    return deltaQ * this;
  }
}
