module thBase.math3d.sh;

import core.stdc.math;
import thBase.math : max;
import thBase.math3d.vecs;
// Implementation based on "physically based rendering" by Matt Pharr Page 932ff

enum float INV_FOURPI = 0.07957746833562851f;
enum float SQRT2 = 1.41421356237f;

uint SHIndex(uint l, int m)
{
  return l*l + l + m;
}

uint SHNumCoefficients(uint lmax)
{
  return (lmax + 1) * (lmax + 1);
}

float absf(float x)
{
  if(x < 0.0f)
    return -x;
  return x;
}

void LegendrePolynomials(float x, uint lmax, float[] result)
{
  assert(result.length == SHNumCoefficients(lmax), "wrong number of coefficients");
  result[SHIndex(0, 0)] = 1.0f;
  result[SHIndex(1, 0)] = x;
  // m = 0
  for(uint l = 2; l <= lmax; ++l)
  {
    result[SHIndex(l, 0)] = ((2*l-1)*x*result[SHIndex(l-1,0)] - (l-1)*result[SHIndex(l-2,0)]) / cast(float)l;
  }

  // m = l
  float neg = -1.0f;
  float dfact = 1.0f;
  float xroot = sqrtf(max(0.0f, 1.0f - x * x));
  float xpow = xroot;
  for(uint l = 1; l <= lmax; ++l)
  {
    result[SHIndex(l, l)] = neg * dfact * xpow;
    neg *= -1.0f;
    dfact *= 2*l + 1;
    xpow *= xroot;
  }

  // m = l - 1
  for(uint l = 2; l <= lmax; ++l)
  {
    result[SHIndex(l, l-1)] = x * (2*l-1) * result[SHIndex(l-1, l-1)];
  }

  // remaining values
  for(uint l = 3; l <= lmax; ++l)
  {
    for(int m = 1; m <= l-2; ++m)
    {
      result[SHIndex(l, m)] = ((2 * (l-1) + 1) * x * result[SHIndex(l-1, m)] - (l-1+m) * result[SHIndex(l-2,m)]) / cast(float)(l - m);
    }
  }
}

float divfact(int a, int b)
{
  if(b == 0) return 1.0f;
  float fa = a;
  float fb = absf(b);
  float v = 1.0f;
  for(float x = fa-fb+1.0f; x <= fa+fb; x += 1.0f)
  {
    v *= x;
  }
  return 1.0f / v;
}

float K(int l, int m)
{
  return sqrtf((2.0f * l + 1.0f) * INV_FOURPI * divfact(l, m));
}

void sinCosIndexed(float s, float c, uint n, float[] sout, float[] cout)
{
  float si = 0.0f;
  float ci = 1.0f;
  for(uint i=0; i < n; i++)
  {
    sout[i] = si;
    cout[i] = ci;
    float oldsi = si;
    si = si * c + ci * s;
    ci = ci * c - oldsi * s;
  }
}

struct SH(uint lmax)
{
private:
  static float Klm[SHNumCoefficients(lmax)];

  shared static this()
  {
    for(int l=0; l <= lmax; l++)
    {
      for(int m = -l; m <= l; m++)
      {
        Klm[SHIndex(l, m)] = K(l, m);
      }
    }
  }

public:
  float clm[SHNumCoefficients(lmax)];

  ref inout(float) c(uint l, int m) inout
  {
    assert(l < lmax, "l out of range");
    assert(m >= -cast(int)l && m <= cast(int)l, "m out of range");
    return clm[SHIndex(l, m)];
  }

  static SH!lmax evaluate(vec3 dir)
  {
    SH!lmax result;
    LegendrePolynomials(dir.z, lmax, result.clm);
    float sins[lmax+1];
    float coss[lmax+1];
    float xyLen = sqrtf(max(0.0f, 1.0f - dir.z * dir.z));
    if(xyLen == 0.0f)
    {
      sins[] = 0.0f;
      coss[] = 1.0f;
    }
    else
    {
      sinCosIndexed(dir.y / xyLen, dir.x / xyLen, lmax+1, sins, coss);
    }

    for(int l=0; l <= lmax; l++)
    {
      for(int m = -l; m < 0; m++)
      {
        result.clm[SHIndex(l,m)] = SQRT2 * Klm[SHIndex(l, m)] * result.clm[SHIndex(l, -m)] * sins[-m];
      }
      result.clm[SHIndex(l, 0)] *= Klm[SHIndex(l, 0)];
      for(int m = 1; m <= l; ++m)
      {
        result.clm[SHIndex(l, m)] *= SQRT2 * Klm[SHIndex(l, m)] * coss[m];
      }
    }
    return result;
  }
}

unittest
{
  auto x = SH!2.evaluate(vec3(1,0,0));
  auto y = SH!2.evaluate(vec3(0,1,0));
  auto z = SH!2.evaluate(vec3(0,0,1));
}