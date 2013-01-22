module thBase.math3d.plane;

import thBase.math3d.vecs;
import thBase.math3d.ray;
import std.math;
import thBase.math : FloatEpsilon;

/**
 * A plane in 3d space
 */
struct Plane {
	vec4 m_Eq; // the plane equation (a * x + b * y + c * z + d = 0)
	
	/**
	 * constructor
	 * Params:
	 *  pEq = the plane euqation
	 */
	this(vec4 pEq){
		m_Eq = pEq;
	}
	
	/**
	 * Constructor
	 * Params: 
	 *  pPos = one point on the plane
	 *  pDir = normal of the plane
	 */
	this(vec3 pPos, vec3 pDir){
		pDir = pDir.normalize();
		m_Eq = vec4(pDir,pPos.dot(pDir));
	}
	
	/**
	 * Constructor
	 * Params:
	 *  v1 = first point on the plane
	 *	v2 = second point on the plane
	 *  v3 = third point on the plane
	 */
	this(vec3 v1, vec3 v2, vec3 v3){
		vec3 dir1 = v2 - v1;
		vec3 dir2 = v3 - v1;
		vec3 normal = dir1.cross(dir2).normalize();
		m_Eq = vec4(normal,v1.dot(normal));
	}
	
	/**
	 * Constructor
	 * Params:
	 *  x = x part
	 *  y = y part
	 *  z = z part
	 *  w = distance from origin
	 */
	this(float x, float y, float z, float w){
		m_Eq = vec4(x,y,z,w);
	}
	
	/**
	 * computes the distance of a point to this plane
	 * Params:
	 *  pPoint = the point to compute the distance for
	 * Returns: the computed distance 
	 */
	float distance(vec3 pPoint) const {
		return m_Eq.x * pPoint.x + m_Eq.y * pPoint.y + m_Eq.z * pPoint.z - m_Eq.w;
	}
	
	///ditto
	float distance(vec4 pPoint) const {
		return distance(vec3(pPoint));
	}
	
	/**
	 * computes the intersection point of this and 3 other planes
	 * Params:
	 *  p2 = first other plane
	 *  p3 = second other plane
	 * Returns: the intersection point (float.nan in all 3 components if there is more then 1 intersection point)
	 */
	const(vec3) intersect(const(Plane) p2, const(Plane) p3) const {
		float d;
		vec3 result=vec3(float.nan,float.nan,float.nan);
		d = m_Eq.x*p2.m_Eq.y*p3.m_Eq.z + m_Eq.y*p2.m_Eq.z*p3.m_Eq.x + m_Eq.z*p2.m_Eq.x*p3.m_Eq.y - p3.m_Eq.x*p2.m_Eq.y*m_Eq.z - p3.m_Eq.y*p2.m_Eq.z*m_Eq.x - p3.m_Eq.z*p2.m_Eq.x*m_Eq.y;
		if(d!=0){
			result.x = m_Eq.w*p2.m_Eq.y*p3.m_Eq.z + m_Eq.y*p2.m_Eq.z*p3.m_Eq.w + m_Eq.z*p2.m_Eq.w*p3.m_Eq.y - p3.m_Eq.w*p2.m_Eq.y*m_Eq.z - p3.m_Eq.y*p2.m_Eq.z*m_Eq.w - p3.m_Eq.z*p2.m_Eq.w*m_Eq.y;
			result.y = m_Eq.x*p2.m_Eq.w*p3.m_Eq.z + m_Eq.w*p2.m_Eq.z*p3.m_Eq.x + m_Eq.z*p2.m_Eq.x*p3.m_Eq.w - p3.m_Eq.x*p2.m_Eq.w*m_Eq.z - p3.m_Eq.w*p2.m_Eq.z*m_Eq.x - p3.m_Eq.z*p2.m_Eq.x*m_Eq.w;
			result.z = m_Eq.x*p2.m_Eq.y*p3.m_Eq.w + m_Eq.y*p2.m_Eq.w*p3.m_Eq.x + m_Eq.w*p2.m_Eq.x*p3.m_Eq.y - p3.m_Eq.x*p2.m_Eq.y*m_Eq.w - p3.m_Eq.y*p2.m_Eq.w*m_Eq.x - p3.m_Eq.w*p2.m_Eq.x*m_Eq.y;

			result.x /= d;
			result.y /= d;
			result.z /= d;
		}

		return result;
	}
	
	/**
	 * computes the intersection of this plane and a other one
	 * Params:
	 *  other = the other plane to intersect with
	 * Returns: the intersection ray
	 */
	const(Ray) intersect(const(Plane) other) const {
    float dot = this.m_Eq.dot(other.m_Eq);
    if(abs(dot) >= 1.0f - FloatEpsilon)
    {
      //the planes are paralell
      return Ray(vec3(float.nan),vec3(float.nan));
    }

    float invDet = 1.0f / (1.0f - dot * dot);
    float cThis = (this.m_Eq.w - other.m_Eq.w) * invDet;
    float cOther = (other.m_Eq.w - this.m_Eq.w) * invDet;
    return Ray(cThis * this.m_Eq.xyz + cOther * other.m_Eq.xyz, this.m_Eq.xyz.cross(other.m_Eq.xyz).normalize());

		/*vec3 dir,pos;
		float d = (other.m_Eq.x * m_Eq.y) - (m_Eq.x * other.m_Eq.y);
		
		//if divisor is to small, try a different axis
		if(d < 0.0001f && d > -0.0001f){
			d = (other.m_Eq.x * m_Eq.z) - (m_Eq.x * other.m_Eq.z);
			
			//if the divisor is to small again, try yet another different axis
			if(d < 0.0001f && d > -0.0001f)
      {
        d = (other.m_Eq.y*m_Eq.z) - (m_Eq.y * other.m_Eq.z);

        //if the divisor is still to small, we have coplanar planes
        if(d < 0.0001f && d > -0.0001f)
				  return Ray(vec3(float.nan),vec3(float.nan));

        dir.x = 1.0f;
        dir.y = (other.m_Eq.x*m_Eq.z - m_Eq.x*other.m_Eq.z) / d;
        dir.z = (other.m_Eq.x*m_Eq.y - m_Eq.x*other.m_Eq.y) / d;

        pos.x = 0.0f;
        pos.y = (m_Eq.z * other.m_Eq.w - m_Eq.w * other.m_Eq.z) / d;
        pos.z = (m_Eq.w * other.m_Eq.y - m_Eq.y * other.m_Eq.w) / d;

        return Ray(pos, dir);
      }
			
			dir.x = (other.m_Eq.y*m_Eq.z - m_Eq.y*other.m_Eq.z) / d;
			dir.y = 1.0f;
			dir.z = (other.m_Eq.x*m_Eq.y - m_Eq.x*other.m_Eq.y) / d;
			
			pos.x = (m_Eq.z*other.m_Eq.w - other.m_Eq.z*m_Eq.w) / d;
			pos.y = 0.0f;
			pos.z = (m_Eq.w*other.m_Eq.x - other.m_Eq.w*m_Eq.x) / d;
			
			return Ray(pos, dir);
		}
		
		
		dir.x = (other.m_Eq.y*m_Eq.z - m_Eq.y*other.m_Eq.z) / d;
		dir.y = (other.m_Eq.x*m_Eq.z - m_Eq.x*other.m_Eq.z) / d;
		dir.z = 1.0f;
		
		pos.x = (m_Eq.y*other.m_Eq.w - other.m_Eq.y*m_Eq.w) / d;
		pos.y = (m_Eq.w*other.m_Eq.x - other.m_Eq.w*m_Eq.x) / d;
		pos.z = 0.0f;
		
		return Ray(pos, dir);*/
	}
	
	/**
	 * normalizes the plane
	 */
	Plane normalize() const {
		vec4 res = m_Eq;
		float length = sqrt(res.dot(res));
		if(length != 0){
			res = res / length;
		}
		return Plane(res);
	}

  @property vec3 normal() const
  {
    return m_Eq.xyz;
  }
	
}

version(unittest)
{
  import core.stdc.stdio;
  import thBase.math : epsilonCompare;
}

unittest {
	Plane p1 = Plane(vec3(0,0,0),vec3(1,0,0));
	Plane p2 = Plane(vec3(0,0,0),vec3(0,1,0));
	
	Ray result = p1.intersect(p2);
  assert(result.pos.epsilonCompare(vec3(0.0f, 0.0f, 0.0f)));
  assert(result.dir.epsilonCompare(vec3(0.0f, 0.0f, 1.0f)));

  Plane p3 = Plane(vec4(0.0f, 1.0f, 0.0f, 0.5f));
  Plane p4 = Plane(vec4(0.0f, 0.0f, 1.0f, 1.0f));
  Ray result2 = p3.intersect(p4);
  assert(result2.pos.epsilonCompare(vec3(0.0f, 0.5f, 1.0f)));
  assert(result2.dir.epsilonCompare(vec3(1.0f, 0.0f, 0.0f)));

  p1 = Plane(vec4(0,1,0,-1));
  p2 = Plane(vec4(1,0,0,1));
  result = p1.intersect(p2);
  assert(result.pos.epsilonCompare(vec3(1,-1,0)));
  assert(result.dir.epsilonCompare(vec3(0,0,1)));

  p1 = Plane(vec4(0,0,1,-1));
  p2 = Plane(vec4(0,1,0,1));
  result = p1.intersect(p2);
  assert(result.pos.epsilonCompare(vec3(0,1,-1)));
  assert(result.dir.epsilonCompare(vec3(1,0,0)));

  p1 = Plane(vec4(0,0,1,-1));
  p2 = Plane(vec4(1,0,0,1));
  result = p1.intersect(p2);
  assert(result.pos.epsilonCompare(vec3(1,0,-1)));
  assert(result.dir.epsilonCompare(vec3(0,1,0)));
}