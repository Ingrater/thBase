module thBase.math3d.all;

import std.math;
public import thBase.math3d.vecs;
public import thBase.math3d.mats;
public import thBase.math3d.plane;
public import thBase.math3d.ray;
public import thBase.math3d.position;
public import thBase.math3d.box;
public import thBase.math3d.quaternion;
public import thBase.math3d.triangle;
public import thBase.math3d.sphere;

/**
 * Computes the normal for a given triangle
 * Params:
 *  t1 = first point of triangle
 *  t2 = second point of triangle
 *  t3 = third point of triangle
 * Returns: the computed normal
 */
const(vec4) ComputeNormal(ref const(vec4) t1, ref const(vec4) t2, ref const(vec4) t3)
{
  vec4 normal,v1,v2,v3;
  v2 = t1 - t2;
  v3 = t1 - t3;
  //normal
  normal.x = v2.y * v3.z - v2.z * v3.y;
  normal.y = v2.z * v3.x - v2.x * v3.z;
  normal.z = v2.x * v3.y - v2.y * v3.x;
  normal = normal.normalize();
  normal.w = 1.0f;
  return normal;	
}


/**
 * Creates a rotation matrix
 * $(BR) Rotation is done in order X,Y,Z
 * Params:
 *  x = rotation in degrees around x axis
 *  y = rotation in degrees around y axis
 *  z = rotation in degrees around z axis
 */
const(mat4) RotationMatrixXYZ(float x, float y, float z){
  mat4 result;
  float A,B,C,D,E,F,AD,BD;

  A       = cos(x/(-180.0f) * PI);
  B       = sin(x/(-180.0f) * PI);
  C       = cos(y/(-180.0f) * PI);
  D       = sin(y/(-180.0f) * PI);
  E       = cos(z/(-180.0f) * PI);
  F       = sin(z/(-180.0f) * PI);
  AD      =   A * D;
  BD      =   B * D;
  result.f[0]  =   C * E;
  result.f[4]  =  -C * F;
  result.f[8]  =   D;
  result.f[1]  =  BD * E + A * F;
  result.f[5]  = -BD * F + A * E;
  result.f[9]  =  -B * C;
  result.f[2]  = -AD * E + B * F;
  result.f[6]  =  AD * F + B * E;
  result.f[10] =   A * C;
  result.f[3]  =  result.f[7] = result.f[11] = result.f[12] = result.f[13] = result.f[14] = 0;
  result.f[15] =  1;
  return result;
}

/**
 * Creates a rotation matrix
 * $(BR) Rotation is done in order X,Y,Z
 * Params:
 *  v3Rotation = rotation in degrees
 */
const(mat4) RotationMatrixXYZ(ref const(vec3) v3Rotation)
{
  mat4 result;
  float A,B,C,D,E,F,AD,BD;

  A       = cos(v3Rotation.x/(-180.0f) * PI);
  B       = sin(v3Rotation.x/(-180.0f) * PI);
  C       = cos(v3Rotation.y/(-180.0f) * PI);
  D       = sin(v3Rotation.y/(-180.0f) * PI);
  E       = cos(v3Rotation.z/(-180.0f) * PI);
  F       = sin(v3Rotation.z/(-180.0f) * PI);
  AD      =   A * D;
  BD      =   B * D;
  result.f[0]  =   C * E;
  result.f[4]  =  -C * F;
  result.f[8]  =   D;
  result.f[1]  =  BD * E + A * F;
  result.f[5]  = -BD * F + A * E;
  result.f[9]  =  -B * C;
  result.f[2]  = -AD * E + B * F;
  result.f[6]  =  AD * F + B * E;
  result.f[10] =   A * C;
  result.f[3]  =  result.f[7] = result.f[11] = result.f[12] = result.f[13] = result.f[14] = 0;
  result.f[15] =  1;
  return result;		
}

/**
 * Creates a rotation matrix
 * Params:
 *  x = the x vector
 *  y = the y vector
 *  z = the z vector
 */
const(mat4) RotationMatrix(ref const(vec3) x,ref const(vec3) y,ref const(vec3) z){
  mat4 result;
  result.f[0]  = x.x;
  result.f[4]  = x.y;
  result.f[8]  = x.z;
  result.f[1]  = y.x;
  result.f[5]  = y.y;
  result.f[9]  = y.z;
  result.f[2]  = z.x;
  result.f[6]  = z.y;
  result.f[10] = z.z;
  result.f[12] = result.f[13] = result.f[14] = result.f[3] = result.f[7] = result.f[11] = 0.0f;
  result.f[15] = 1.0f;
  return result;
}

/**
 * Creates a translation matrix
 * Params:
 *  Translation = the translation
 */
mat4 TranslationMatrix(const(vec3) Translation){
  mat4 result;
  result.f[12] = Translation.x;
  result.f[13] = Translation.y;
  result.f[14] = Translation.z;
  result.f[15] = 1.0f;
  result.f[0] = result.f[5] = result.f[10] = 1.0f;
  result.f[4] = result.f[8] = result.f[1] = result.f[9] = result.f[2] = result.f[6] = result.f[3] = result.f[7] = result.f[11] = 0.0f;
  return result;
}

/**
 * creates a translation matrix
 * Params:
 *  Translation = the translation
 */
mat4 TranslationMatrix(ref const(vec4) Translation){
  mat4 result;
  result.f[12] = Translation.x;
  result.f[13] = Translation.y;
  result.f[14] = Translation.z;
  result.f[15] = Translation.w;
  result.f[0] = result.f[5] = result.f[10] = 1.0f;
  result.f[4] = result.f[8] = result.f[1] = result.f[9] = result.f[2] = result.f[6] = result.f[3] = result.f[7] = result.f[11] = 0.0f;
  return result;
}

/**
 * Creates a translation matrix
 * Params:
 *  x = x translation
 *  y = y translation
 *  z = z translation
 */
mat4 TranslationMatrix(float x, float y, float z){
  mat4 result;
  result.f[12] = x;
  result.f[13] = y;
  result.f[14] = z;
  result.f[0] = result.f[5] = result.f[10] = result.f[15] = 1.0f;
  result.f[4] = result.f[8] = result.f[1] = result.f[9] = result.f[2] = result.f[6] = result.f[3] = result.f[7] = result.f[11] = 0.0f;
  return result;
}


/**
 * Creates a scale matrix 
 * Params:
 *  v3Scale = the scaling
 */
const(mat4) ScaleMatrix(const(vec3) v3Scale){
  mat4 result;
  result.f[0] = v3Scale.x;
  result.f[5] = v3Scale.y;
  result.f[10] = v3Scale.z;
  result.f[15] = 1.0f;
  result.f[1] = result.f[2] = result.f[3] = result.f[4] = result.f[6] = result.f[7] = result.f[8] = result.f[9] = result.f[11] = result.f[12] = result.f[13] = result.f[14] = 0.0f;
  return result;
}

/**
 * Creates a scale matrix
 * Params:
 *  x = x scale
 *  y = y scale
 *  z = z scale
 */
const(mat4) ScaleMatrix(float x, float y, float z){
  mat4 result;
  result.f[0] = x;
  result.f[5] = y;
  result.f[10] = z;
  result.f[15] = 1.0f;
  result.f[1] = result.f[2] = result.f[3] = result.f[4] = result.f[6] = result.f[7] = result.f[8] = result.f[9] = result.f[11] = result.f[12] = result.f[13] = result.f[14] = 0.0f;
  return result;
}

const(vec4) UpVektor(float X,float Y,float Z,float Radians){
  float RotY,RotZ,Distance;
  vec4 Up;
  //Z Rotation Berechnen
  Distance = sqrt(X * X + Y * Y);
  if(Distance != 0){
    if(Y >= 0)
      RotZ = acos( X / Distance);
    else
      RotZ = 2 * PI - acos( X / Distance);
    X = Distance;
    Y = 0;
  }
  else {
    RotZ=0;
  }
  //Y Rotation Berechnen
  Distance = sqrt( X * X + Z * Z);
  if(Distance != 0)
    RotY = acos( X / Distance);
  else
    RotY = 0;
  //Up Point berechnen
  X = 0;
  Y = sin(Radians);
  Z = cos(Radians);
  //Um Y Achse drehen
  if(RotY != 0){
    X = sin(RotY) * Z;
    Z = cos(RotY) * Z;
  }
  //Um Z Achse drehen
  if(RotZ != 0){
    Distance = sqrt(X * X + Y * Y);
    if(Distance != 0){
      if(Y >= 0)
        RotZ += acos(X / Distance);
      else
        RotZ +=  2 * PI - acos(X / Distance);
      X = cos(RotZ) * Distance;
      Y = sin(RotZ) * Distance;
    }
  }
  Up.x = X;
  Up.y = Y;
  Up.z = Z;
  Up = Up.normalize();
  Up.w = 1.0f;
  return Up;
}

/**
 * Computes the tangent of a triangle
 * Params:
 *  v1 = frist point of the triangle
 *  v2 = second point of the triangle
 *  v3 = thrid point of the triangle
 *  t1 = texture coordinates of first point
 *  t2 = texture coordinates of second point
 *  t3 = texture coordinates of third point
 */
const(vec4) Tangent(ref const(vec4) v1, ref const(vec4) v2, ref const(vec4) v3, ref const(vec2) t1, ref const(vec2) t2, ref const(vec2) t3){
  vec4 t;
  float div;
  //T
  div = (t2.x - t1.x) * (t3.y - t1.y) - (t3.x - t1.x) * (t2.y - t1.y);
  div = fabs(div);
  t = ((t3.y - t1.y) * (v2 - v1) - (t2.y - t1.y) * (v3 - v1)) / div;
  t.w = 1.0f;
  return t;
}

/**
 * Computes the binormal of a triangle
 * Params:
 *  v1 = frist point of the triangle
 *  v2 = second point of the triangle
 *  v3 = thrid point of the triangle
 *  t1 = texture coordinates of first point
 *  t2 = texture coordinates of second point
 *  t3 = texture coordinates of third point
 */
const(vec4) Binormal(ref const(vec4) v1, ref const(vec4) v2, ref const(vec4) v3, ref const(vec2) t1, ref const(vec2) t2, ref const(vec2) t3){
  vec4 b;
  float div;
  div = (t2.x - t1.x) * (t3.y - t1.y) - (t3.x - t1.x) * (t2.y - t1.y);
  div = fabs(div);
  b = ((t2.x - t1.x)* (v3 - v1)  - (t3.x - t1.x) * (v2 - v1)) / div;
  b.w = 1.0f;
  return b;
}

/**
 * computes the intersection point of 3 planes
 * Params:
 *  p1 = first plane
 *  p2 = second plane
 *  p3 = thrid plane
 * Returns: the intersection point
 */
const(vec4) PlanePoint(ref const(vec4) p1, ref const(vec4) p2, ref const(vec4) p3){
  float d;
  vec4 result;
  d = p1.x*p2.y*p3.z + p1.y*p2.z*p3.x + p1.z*p2.x*p3.y - p3.x*p2.y*p1.z - p3.y*p2.z*p1.x - p3.z*p2.x*p1.y;
  if(d!=0){
    result.x = p1.w*p2.y*p3.z + p1.y*p2.z*p3.w + p1.z*p2.w*p3.y - p3.w*p2.y*p1.z - p3.y*p2.z*p1.w - p3.z*p2.w*p1.y;
    result.y = p1.x*p2.w*p3.z + p1.w*p2.z*p3.x + p1.z*p2.x*p3.w - p3.x*p2.w*p1.z - p3.w*p2.z*p1.x - p3.z*p2.x*p1.w;
    result.z = p1.x*p2.y*p3.w + p1.y*p2.w*p3.x + p1.w*p2.x*p3.y - p3.x*p2.y*p1.w - p3.y*p2.w*p1.x - p3.w*p2.x*p1.y;
    result.w = 1.0f;

    result.x /= d;
    result.y /= d;
    result.z /= d;
  }

  return result;
}

/**
 * does min on all 3 dimensions individually
 */
const(vec3) min(ref const(vec3) a, ref const(vec3) b){
  vec3 res;
  res.x = (a.x < b.x) ? a.x : b.x;
  res.y = (a.y < b.y) ? a.y : b.y;
  res.z = (a.z < b.z) ? a.z : b.z;
  return res;
}

/**
 * does max on all 3 dimensions individually
 */
const(vec3) max(ref const(vec3) a,ref  const(vec3) b){
  vec3 res;
  res.x = (a.x > b.x) ? a.x : b.x;
  res.y = (a.y > b.y) ? a.y : b.y;
  res.z = (a.z > b.z) ? a.z : b.z;
  return res;
}

/**
 * reflects a vector on a normal
 */
vec3 reflect(vec3 vec, vec3 normal){
     vec3 result;
     float product = 2*((-1)*vec.x*normal.x +(-1)*vec.y*normal.y+(-1)*vec.z*normal.z);
     result.x = product * normal.x + vec.x;
     result.y = product * normal.y + vec.y;
     result.z = product * normal.z + vec.z;
     return result;
}