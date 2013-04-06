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
    version(none) //USE_SSE
    {
      asm {
        mov EAX, this;
        mov EBX, ray;
        movups XMM0, [EAX]; //this.pos
        movups XMM1, [EBX]; //ray.pos
        movaps XMM2, XMM1;
        subps XMM2, XMM0; // offset

      }
    }
    else
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

    float distSqrt = sqrt(disc);
    float q = 0.0f;
    if (b < 0)
      q = (-b - distSqrt)/2.0;
    else
      q = (-b + distSqrt)/2.0;

    // compute t0 and t1
    float t0 = q / a;
    float t1 = c / q;

    // make sure t0 is smaller than t1
    if (t0 > t1)
    {
      // if t0 is bigger than t1 swap them around
      swap(t0, t1);
    }

    // if t1 is less than zero, the object is in the ray's negative direction
    // and consequently the ray misses the sphere
    if (t1 < 0)
      return false;

    // if t0 is less than zero, the intersection point is at t1
    if (t0 < 0)
    {
      distanceOnRay = t1;
      return true;
    }
    // else the intersection point is at t0
    distanceOnRay = t0;
    return true;
  }
}