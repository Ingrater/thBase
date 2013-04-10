module thBase.math3d.sphere;

import thBase.math3d.vecs;
import thBase.math3d.ray;
import thBase.algorithm;

import std.math;

struct Sphere
{
  vec3 pos;
  float radiusSquared;

  this(vec3 pos, float radius)
  {
    this.pos = pos;
    this.radiusSquared = radius * radius;
  }

  @property float radius() const
  {
    return sqrt(radiusSquared);
  }

  bool intersects(ref const(Ray) ray) const
  {
    version(USE_SSE) //USE_SSE
    {
      immutable(float) two = 2.0f;
      immutable(float) four = 4.0f;
      float disc;
      asm {
        mov EAX, this;
        mov EBX, ray;
        movups XMM0, [EAX]; //this.pos
        movups XMM1, [EBX]; //ray.pos
        movaps XMM2, XMM1;
        subps XMM2, XMM0; // offset
        movups XMM3, [EBX+12]; //ray.dir
        movaps XMM4, XMM3;
        dpps XMM4, XMM4, 0b0111_0001; //ray.dir.dot(ray.dir) => a
        dpps XMM3, XMM2, 0b0111_0001; //ray.dir.dot(offset) => b
        dpps XMM2, XMM2, 0b0111_0001; //offset.dot(offset)
        movss XMM5, [EAX+12]; // load radiusSquared
        subss XMM2, XMM5; // *= radiusSquared => c
        mulss XMM3, XMM3; // => b*b
        mulss XMM2, XMM4; // => a * c
        subss XMM3, XMM2; // => b * b - a * c
        lea EAX, disc;
        movss [EAX], XMM3;
      }
      return (disc >= 0.0f);
    }
    else
    {
      //Compute A, B and C coefficients
      vec3 offset = ray.pos - pos;
      float a = ray.dir.dot(ray.dir);
      float b = ray.dir.dot(offset);
      float c = offset.dot(offset) - radiusSquared;

      //Find discriminant
      float disc = b * b - a * c;

      // if discriminant is negative there are no real roots, so return 
      // false as ray misses sphere
      return (disc >= 0.0f);
    }
  }

  bool computeNearestIntersection(ref const(Ray) ray, ref float distanceOnRay) const
  {
    //Compute A, B and C coefficients
    vec3 offset = ray.pos - pos;
    float a = ray.dir.dot(ray.dir);
    float b = 2.0f * ray.dir.dot(offset);
    float c = offset.dot(offset) - radiusSquared;

    //Find discriminant
    float disc = b * b - 4.0f * a * c;

    // if discriminant is negative there are no real roots, so return 
    // false as ray misses sphere
    if (disc < 0)
      return false;

    float discSqrt = sqrt(disc);

    float t0 = (-b - discSqrt) / (2.0f * a);
    float t1 = (-b + discSqrt) / (2.0f * a);

    // make sure t0 is smaller than t1
    if (t0 > t1)
    {
      // if t0 is bigger than t1 swap them around
      swap(t0, t1);
    }

    // if t1 is less than zero, the object is in the ray's negative direction
    // and consequently the ray misses the sphere
    if (t1 < 0.0f)
      return false;

    // if t0 is less than zero, the intersection point is at t1
    if (t0 < 0.0f)
    {
      distanceOnRay = t1;
      return true;
    }
    // else the intersection point is at t0
    distanceOnRay = t0;
    return true;
  }
}

unittest
{
  auto r = Ray(vec3(0,0,0), vec3(2.9f,3.1f,3.2f).normalize());
  auto s = Sphere(vec3(3,3,3), 1.0f);
  assert(s.intersects(r) == true);
}