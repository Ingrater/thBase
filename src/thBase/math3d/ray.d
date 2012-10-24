module thBase.math3d.ray;

import thBase.math3d.vecs;
import thBase.math3d.plane;

/**
 * a Ray in 3d
 */
struct Ray {
	vec3 pos; /// point on the ray
	vec3 dir; /// direction of the ray
	
	/**
	 * constructor
	 * Params:
	 *  pPos = one position on the ray
	 *  pDir = direction of the ray
	 */
	this(vec3 pPos, vec3 pDir)
  {
		dir = pDir;
		pos = pPos;
	}
	
	
	/**
	 * Creates a ray using two points
	 * Params:
	 *  p1 = first point on the ray
	 *  p2 = second point on the ray
	 */
	static Ray CreateFromPoints(vec3 p1, vec3 p2)
  {
		return Ray(p1,p2-p1);
	}
	
	/**
	 * Intersects this ray with a plane
	 * Params:
	 *  p = the plane to intersect with
	 * Returns: the intersection distance on the ray
	 */
	float Intersect(ref const(Plane) p) const
  {
		float d = p.m_Eq.x * dir.x + p.m_Eq.y * dir.y + p.m_Eq.z * dir.z;
		if(d == 0.0f){
			return float.nan;
		}
		return (p.m_Eq.w - p.m_Eq.x * pos.x - p.m_Eq.y * pos.y - p.m_Eq.z * pos.z) / d;
	}
	
	/**
	 * gets a point on the ray
	 * Params:
	 *  f = the distance on the ray to get the point for
	 * Returns: the computed position
	 */
	vec3 get(float f) const {
		return pos + dir * f;
	}

  /**
   * gets the end of the ray
   */
  @property vec3 end() const {
    return pos + dir;
  }
}