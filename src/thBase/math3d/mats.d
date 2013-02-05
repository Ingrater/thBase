module thBase.math3d.mats;

import thBase.math3d.vecs;
import std.math;
import thBase.math;

/**
 * 2x2 matrix
 * $(BR) layout is
 * $(BR) [0] [2]
 * $(BR) [1] [3]
 */
struct mat2 {
	float[4] f; /// data
}

/**
 * 3x3 matrix
 * $(BR) layout is 
 * $(BR) [0] [3] [6]
 * $(BR) [1] [4] [7]
 * $(BR) [2] [5] [8] 
 */
struct mat3 {
	float[9] f; /// data
	
	/**
	 * Returns:  the determinant of this matrix
	 */
	float Det() const pure
	{
		float det = f[0] * ( f[4] * f[8] - f[7] * f[5] )
		          - f[1] * ( f[3] * f[8] - f[6] * f[5] )
		          + f[2] * ( f[3] * f[7] - f[6] * f[4] );
		return det;
	}
	
	/**
	 * Returns: The transposed version of this matrix
	 */
	mat3 Transpose() const pure {
		mat3 res = this;
	    res.f[1] = f[3];
	    res.f[3] = f[1];
	    res.f[6] = f[2];
	    res.f[2] = f[6];
	    res.f[5] = f[7];
	    res.f[7] = f[5];
	    return res;
	}

  mat3 Inverse() const pure {
    float det = this.Det();
    if(det > -FloatEpsilon && det < FloatEpsilon)
      return mat3.Identity();

    mat3 res;
    res.f[0] =    this.f[4]*this.f[8] - this.f[7]*this.f[5]   / det;
    res.f[3] = -( this.f[3]*this.f[8] - this.f[5]*this.f[6] ) / det;
    res.f[6] =    this.f[3]*this.f[7] - this.f[4]*this.f[6]   / det;
    res.f[1] = -( this.f[1]*this.f[8] - this.f[7]*this.f[2] ) / det;
    res.f[4] =    this.f[0]*this.f[8] - this.f[2]*this.f[6]   / det;
    res.f[7] = -( this.f[0]*this.f[7] - this.f[1]*this.f[6] ) / det;
    res.f[2] =    this.f[1]*this.f[5] - this.f[2]*this.f[4]   / det;
    res.f[5] = -( this.f[0]*this.f[5] - this.f[2]*this.f[3] ) / det;
    res.f[8] =    this.f[0]*this.f[4] - this.f[3]*this.f[1]   / det;
    return res;
  }

  /*unittest
  {
    mat3 scale;
    scale.f[0..9] = 0.0f;
    scale.f[0] = 5.0f;
    scale.f[4] = 5.0f;
    scale.f[8] = 5.0f;

    mat3 inverseScale = scale.Inverse();
    mat3 identity = scale * inverseScale;
    assert(scale.f[0] == 1.0f);
  }*/
	
	/**
	 * constructor
	 * Params:
	 *  data = inital data for the matrix
	 */
	this(float[] data)
	in {
		assert(data.length == 9,"data has wrong size");
	}
	body {
		f[0..9] = data[0..9];
	}
	
	/**
	 * Returns: a identity mat3 matrix
	 */
	static mat3 Identity() pure {
		mat3 res;
		res.f[0] = 1.0f; res.f[1] = 0.0f; res.f[2] = 0.0f;
		res.f[3] = 0.0f; res.f[4] = 0.0f; res.f[5] = 0.0f;
		res.f[6] = 0.0f; res.f[7] = 0.0f; res.f[8] = 1.0f;
		return res;
	}
	
	/**
	 * multiplies this matrix with a vector
	 * Params:

	 *  v = the vector
	 */ 
	vec3 opMul(const vec3 v) const pure {
		vec3 temp;
		temp.x = v.x * this.f[0] + v.y * this.f[3] + v.z * this.f[6];
		temp.y = v.x * this.f[1] + v.y * this.f[4] + v.z * this.f[7];
		temp.z = v.x * this.f[2] + v.y * this.f[5] + v.z * this.f[8];
		return temp;
	}

	mat3 opMul(mat3 m) const pure
	{
		mat3 result;
    for(int i=0;i<3;i++){
			result.f[i*3]   = m.f[0] * this.f[i*3] + m.f[3] * this.f[i*3+1] + m.f[6] * this.f[i*3+2];
      result.f[i*3+1] = m.f[1] * this.f[i*3] + m.f[4] * this.f[i*3+1] + m.f[7] * this.f[i*3+2];
      result.f[i*3+2] = m.f[2] * this.f[i*3] + m.f[5] * this.f[i*3+1] + m.f[8] * this.f[i*3+2];
    }	
		return result;	
	}
}

/**
 * a 4x4 matrix
 * $(BR) layout is:
 * $(BR) [ 0] [ 4] [ 8] [12]
 * $(BR) [ 1] [ 5] [ 9] [13]
 * $(BR) [ 2] [ 6] [10] [14]
 * $(BR) [ 3] [ 7] [11] [15]
 */
struct mat4 {
	float[16] f; /// data
	
	/**
	 * constructor
	 * Params:
	 *  data = inital data
	 */
	this(float[] data)
	in {
		assert(data.length == 16,"data has wrong size");
	}
	body {
		f[0..16] = data[0..16];
	}
	
	/**
	 * multiplies this matrix with another one
	 * Params:
	 *  m = other matrix
	 */
	mat4 opMul(mat4 m) const pure
	{
		mat4 result;
	  	for(int i=0;i<4;i++){
			result.f[i*4]   = m.f[0] * this.f[i*4] + m.f[4] * this.f[i*4+1] + m.f[ 8] * this.f[i*4+2] + m.f[12] * this.f[i*4+3];
		    result.f[i*4+1] = m.f[1] * this.f[i*4] + m.f[5] * this.f[i*4+1] + m.f[ 9] * this.f[i*4+2] + m.f[13] * this.f[i*4+3];
		    result.f[i*4+2] = m.f[2] * this.f[i*4] + m.f[6] * this.f[i*4+1] + m.f[10] * this.f[i*4+2] + m.f[14] * this.f[i*4+3];
		    result.f[i*4+3] = m.f[3] * this.f[i*4] + m.f[7] * this.f[i*4+1] + m.f[11] * this.f[i*4+2] + m.f[15] * this.f[i*4+3];
	  	}	
		return result;	
	}
	
	/**
	 * multiplies this matrix with a vector
	 * Params:
	 *  v = the vector
	 */ 
	vec4 opMul(vec4 v) const pure
	{
		vec4 temp;
		temp.x = v.x * this.f[0] + v.y * this.f[4] + v.z * this.f[8]  + v.w * this.f[12];
		temp.y = v.x * this.f[1] + v.y * this.f[5] + v.z * this.f[9]  + v.w * this.f[13];
		temp.z = v.x * this.f[2] + v.y * this.f[6] + v.z * this.f[10] + v.w * this.f[14];
		temp.w = v.x * this.f[3] + v.y * this.f[7] + v.z * this.f[11] + v.w * this.f[15];
		return temp;		
	}

  /**
   * transforms a direction
   * Params:
   *  v = the direction to transform
   */
  vec3 transformDirection(vec3 v) const pure
  {
		vec3 temp;
		temp.x = v.x * this.f[0] + v.y * this.f[4] + v.z * this.f[8];
		temp.y = v.x * this.f[1] + v.y * this.f[5] + v.z * this.f[9];
		temp.z = v.x * this.f[2] + v.y * this.f[6] + v.z * this.f[10];
		return temp;		
  }
	
	/**

	 * multiplies this matrix with a vector
	 * Params:
	 *  v = the vector
	 */ 
	vec3 opMul(vec3 v) const pure
	{
    vec3 temp;
		temp.x = v.x * this.f[0] + v.y * this.f[4] + v.z * this.f[8]  + this.f[12];
		temp.y = v.x * this.f[1] + v.y * this.f[5] + v.z * this.f[9]  + this.f[13];
		temp.z = v.x * this.f[2] + v.y * this.f[6] + v.z * this.f[10] + this.f[14];
		return temp;		
	}
	
	/**
	 * sets all fields of this matrix to value
	 * Params:
	 *  value = the value to set
	 */
	void Set(float value) pure
  {
		foreach(ref e;f)
			e = value;
	}
	
	/**
	 * Returns: a 3x3 submatrix of this one
	 * Params:
	 *  i = x shift
	 *  j = y shift
	 */
	const(mat3) Submat(int i, int j) const pure
	{
		mat3 mb;
		int di, dj, si, sj;
		// loop through 3x3 submatrix
		for( di = 0; di < 3; di ++ ) {
			for( dj = 0; dj < 3; dj ++ ) {
				// map 3x3 element (destination) to 4x4 element (source)
				si = di + ( ( di >= i ) ? 1 : 0 );
				sj = dj + ( ( dj >= j ) ? 1 : 0 );
				// copy element
				mb.f[di * 3 + dj] = f[si * 4 + sj];
			}
		}
		return mb;		
	}
	
	/**
	 * Returns: the determinant of this matirx
	 */
	float Det() const pure
	{
		float det = 0.0f, result = 0, i = 1;
		mat3 msub3;
		for (int n = 0; n < 4; n++, i *= -1 )
		{
			msub3   = this.Submat(0,n);
			det     = msub3.Det();
			result += f[n] * det * i;
		}
		return result;	
	}
	
	/**
	 * Returns: The inverse of this matrix
	 */
	const(mat4) Inverse() const pure
	{
		mat4 mr;
		float mdet = this.Det();
		mat3 mtemp;
		int sign=0;
		if ( fabs( mdet ) < 0.0005 )
			return mat4.Identity();
		for (int i = 0; i < 4; i++ )
			for (int j = 0; j < 4; j++ ){
				sign = 1 - ( (i +j) % 2 ) * 2;
				mtemp = this.Submat(i, j);
				mr.f[i+j*4] = ( mtemp.Det() * sign ) / mdet;
			}
		return mr;
	}
	
	/**
	 * Returns: The transposed version of this matrix
	 */
	const(mat4) Transpose() const pure
	{
		mat4 mr;
		mr.f[0] = f[0];
		mr.f[1] = f[4];
		mr.f[2] = f[8];
		mr.f[3] = f[12];
		mr.f[4] = f[1];
		mr.f[5] = f[5];
		mr.f[6] = f[9];
		mr.f[7] = f[13];
		mr.f[8] = f[2];
		mr.f[9] = f[6];
		mr.f[10] = f[10];
		mr.f[11] = f[14];
		mr.f[12] = f[3];
		mr.f[13] = f[7];
		mr.f[14] = f[11];
		mr.f[15] = f[15];
		return mr;	
	}
	
	/**
	 * Returns: The normal matrix of this matrix
	 */
	const(mat3) NormalMatrix() const pure
	{
		mat4 mr = this;
		mr.f[3] = 0;
		mr.f[7] = 0;
		mr.f[11] = 0;
		mr.f[12] = 0;
		mr.f[13] = 0;
		mr.f[14] = 0;
		mr.f[15] = 1.0f;
		mr = mr.Inverse();
		mr = mr.Transpose();
		mat3 m3;
		for(int y=0;y<3;y++){
			for(int x=0;x<3;x++){
				m3.f[y*3+x] = mr.f[y*4+x];
			}
		}
		return m3;		
	}

  @property const(mat3) rotationPart() const pure
  {
    mat3 result;
    for(int y=0; y<3; y++)
    {
      for(int x=0; x<3; x++)
      {
        result.f[y*3+x] = this.f[y*4+x];
      }
    }
    return result;
  }
	
	/**
	 * Returns: A conversion from Left to Right handed coordinate system and vise versa
	 */
	const(mat4) Right2Left() const pure
	{
		mat4 mr = this;
		for(int i=0;i<4;i++){
			mr.f[4+i] = f[8+i];// * -1.0f;
			mr.f[8+i] = f[4+i] * -1.0f;
		}
		return mr;		
	}
	
	/**
	 * Returns: a mat4 identity matrix
	 */
	static const(mat4) Identity() pure
	{
		mat4 mat;
		mat.f[ 0]=1.0f; mat.f[ 1]=0.0f; mat.f[ 2]=0.0f; mat.f[ 3]=0.0f;
		mat.f[ 4]=0.0f; mat.f[ 5]=1.0f; mat.f[ 6]=0.0f; mat.f[ 7]=0.0f;
		mat.f[ 8]=0.0f; mat.f[ 9]=0.0f; mat.f[10]=1.0f; mat.f[11]=0.0f;
		mat.f[12]=0.0f; mat.f[13]=0.0f; mat.f[14]=0.0f; mat.f[15]=1.0f;
		return mat;	
	}
	
	/**
	 * Creates a perspective projection matrix
	 * Params:
	 *  pViewAngle = the view angle in degrees
	 *  pAspectRatio = the screen aspect ratio
	 *  pNear = near clipping plane distance
	 *  pFar = far clipping plane distance
	 */
	static const(mat4) ProjectionMatrix(float pViewAngle, float pAspectRatio, float pNear, float pFar) pure {
	  mat4 res;
	  res.Set(0.0f);
	  pViewAngle = pViewAngle / 180.0f * PI;
	  // X-Achse
	  res.f[0] = 1 / tan( pViewAngle/2) * pAspectRatio;
	  res.f[1] = 0.0f; res.f[2] = 0.0f; res.f[3] = 0.0f;

	  // Y-Achse
	  res.f[5] = 1 / tan( pViewAngle/2);
	  res.f[4] = 0.0f; res.f[6] = 0.0f; res.f[7] = 0.0f;

	  // Z-Achse
	  //res.f[10] = pFar/ (pNear - pFar);
	  res.f[10] = (pFar + pNear) / (pNear - pFar);
	  res.f[11] = -1.0f;
	  res.f[8] = 0.0f; res.f[9] = 0.0f;

	  // W-Achse
	  res.f[14] = (2.0f * pFar * pNear) / (pNear - pFar);
	  res.f[12] = 0.0f; res.f[13] = 0.0f; res.f[15] = 0.0f;
	  return res;
	}

	/**
	 * Creates a perspective projection matrix
	 * Params:
	 *  pLeft = left bound
	 *  pRight = right bound
	 *  pBottom = bottom bound
	 *  pTop = top bound
	 *  pNear = near clipping plane distance
	 *  pFar = far clipping plane distance
	 */
	static const(mat4) Frustrum(float pLeft, float pRight, float pBottom, float pTop, float pNear, float pFar) pure {
	  mat4 res;
	  res.f[0] = (2.0f*pNear) / (pRight - pLeft);
	  res.f[1] = 0.0f;
	  res.f[2] = 0.0f;
	  res.f[3] = 0.0f;

	  res.f[4] = 0.0f;
	  res.f[5] = (2.0f*pNear) / (pTop - pBottom);
	  res.f[6] = 0.0f;
	  res.f[7] = 0.0f;

	  res.f[8] = (pRight + pLeft) / (pRight - pLeft);
	  res.f[9] = (pTop + pBottom) / (pTop - pBottom);
	  res.f[10] = -(pFar + pNear) / (pFar - pNear);
	  res.f[11] = -1.0f;

	  res.f[12] = 0.0f;
	  res.f[13] = 0.0f;
	  res.f[14] = (-2.0f * pFar * pNear) / (pFar - pNear);
	  res.f[15] = 0.0f;
	  return res;
	}

	/**
	 * Creates a paralell projection matrix
	 * Params:
	 *  pLeft = left bound
	 *  pRight = right bound
	 *  pBottom = bottom bound
	 *  pTop = top bound
	 *  pNear = near clipping plane distance
	 *  pFar = far clipping plane distance
	 */
	static mat4 Ortho(float pLeft, float pRight, float pBottom, float pTop, float pNear, float pFar) pure
  {
		mat4 res;
		res.f[0] = 2.0f / (pRight - pLeft);
		res.f[1] = 0.0f;
		res.f[2] = 0.0f;
		res.f[3] = 0.0f;
		
		res.f[4] = 0.0f;
		res.f[5] = 2.0f / (pTop - pBottom);
		res.f[6] = 0.0f;
		res.f[7] = 0.0f;
		
		res.f[8] = 0.0f;
		res.f[9] = 0.0f;
		res.f[10] = -2.0f / (pFar - pNear);
		res.f[11] = 0.0f;
		
		res.f[12] = -(pRight + pLeft) / (pRight - pLeft);
		res.f[13] = -(pTop + pBottom) / (pTop - pBottom);
		res.f[14] = -(pFar + pNear) / (pFar - pNear);
		res.f[15] = 1.0f;
		return res;
	}

	/**
	 * Creats a look at matrix for camera usage
	 * Params:
	 *  pFrom = position of the viewer
	 *  pTo = position to look at
	 *  pUp = up vector
	 */
	static mat4 LookAtMatrix(ref const(vec4) pFrom,ref  const(vec4) pTo, ref const(vec4) pUp) pure
  {
	  vec4 x,y,z;
	  mat4 res;
	  z = (pTo - pFrom).normalize();
	  //TODO: replace temporary variable
	  vec4 pUpNormalized = pUp.normalize();
	  x = z.cross(pUpNormalized).normalize();
	  y = x.cross(z);
	  z = z * -1.0f;

	  //X
	  res.f[0] = x.x;
	  res.f[4] = x.y;
	  res.f[8] = x.z;
	  res.f[12] = -x.dot(pFrom);

	  //Y
	  res.f[1] = y.x;
	  res.f[5] = y.y;
	  res.f[9] = y.z;
	  res.f[13] = -y.dot(pFrom);

	  //Z
	  res.f[2] = z.x;
	  res.f[6] = z.y;
	  res.f[10] = z.z;
	  res.f[14] = -z.dot(pFrom);

	  //W
	  res.f[3] = res.f[7] = res.f[11] = 0.0f;
	  res.f[15] = 1.0f;

	  return res;
	}
	
	/**
	 * Creats a look at matrix for camera usage
	 * Params:
	 *  pFrom = position of the viewer
	 *  pTo = position to look at
	 *  pUp = up vector
	 */
	static mat4 LookDirMatrix(ref const(vec4) dir, ref const(vec4) pUp) pure
  {
	  vec4 x,y,z;
	  mat4 res;
	  z = dir.normalize();
	  //TODO: replace temporary variable
	  vec4 pUpNormalized = pUp.normalize();
	  x = z.cross(pUpNormalized).normalize();
	  y = x.cross(z);
	  z = z * -1.0f;

	  //X
	  res.f[0] = x.x;
	  res.f[4] = x.y;
	  res.f[8] = x.z;
	  res.f[12] = 0.0f;

	  //Y
	  res.f[1] = y.x;
	  res.f[5] = y.y;
	  res.f[9] = y.z;
	  res.f[13] = 0.0f;

	  //Z
	  res.f[2] = z.x;
	  res.f[6] = z.y;
	  res.f[10] = z.z;
	  res.f[14] = 0.0f;

	  //W
	  res.f[3] = res.f[7] = res.f[11] = 0.0f;
	  res.f[15] = 1.0f;

	  return res;
	}
}