module thBase.math3d.sphere;

import thBase.math3d.vecs;
import thBase.math3d.ray;

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
}