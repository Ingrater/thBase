module thBase.math3d.frustrum;

import thBase.math3d.plane;
import thBase.math3d.mats;
import thBase.math3d.vecs;

struct Frustrum {
private:
	Plane[6] m_planes;

public:
	/**
  * constructor
  * Params:
  *  m = clipping matrix to construct the frustrum from
  */
	this(mat4 m)
  {
    //m = m.Inverse();
    mat4 t = mat4.Identity();
    t.f[10] = -1.0f;
    t.f[0] = -1.0f;
    m = t * m;
    // right clipping plane

	  m_planes[0] = Plane( m.f[ 3] - m.f[ 0],
                         m.f[ 7] - m.f[ 4],
                        m.f[11] - m.f[ 8],
                        m.f[15] - m.f[12] );

    // left clipping plane
	  m_planes[1] = Plane( m.f[ 3] + m.f[ 0],
                         m.f[ 7] + m.f[ 4],
                         m.f[11] + m.f[ 8],
                         m.f[15] + m.f[12] );

    // bottom clipping plane
	  m_planes[2] = Plane( m.f[ 3] + m.f[ 1],
                         m.f[ 7] + m.f[ 5],
                         m.f[11] + m.f[ 9],
                         m.f[15] + m.f[13] );

    // top clipping plane
	  m_planes[3] = Plane( m.f[ 3] - m.f[ 1],
                         m.f[ 7] - m.f[ 5],
                         m.f[11] - m.f[ 9],
                         m.f[15] - m.f[13] );

    // far clipping plane

    m_planes[4] = Plane( m.f[ 3] - m.f[ 2],
                         m.f[ 7] - m.f[ 6],
                        m.f[11] - m.f[10],
                        m.f[15] - m.f[14] );

    // near clipping plane
	  m_planes[5] = Plane( m.f[ 3] + m.f[ 2],
                         m.f[ 7] + m.f[ 6],
                         m.f[11] + m.f[10],
                         m.f[15] + m.f[14] );

    /*m_planes[5] = Plane( m.f[ 2],
                         m.f[ 6],
                         m.f[10],
                         m.f[14] );*/

	  //Normalize Planes
	  for(int i=0;i<6;i++)
      m_planes[i] = m_planes[i].normalize();
	}

	/**
  * Returns: all 8 corners of the frustrum
  */
	vec3[8] corners()
  {		
		vec3[8] points;
		points[0] = m_planes[0].intersect(m_planes[2], m_planes[4]);
		points[1] = m_planes[0].intersect(m_planes[3], m_planes[4]);
		points[2] = m_planes[0].intersect(m_planes[2], m_planes[5]);
		points[3] = m_planes[0].intersect(m_planes[3], m_planes[5]);

		points[4] = m_planes[1].intersect(m_planes[2], m_planes[4]);
		points[5] = m_planes[1].intersect(m_planes[3], m_planes[4]);
		points[6] = m_planes[1].intersect(m_planes[2], m_planes[5]);
		points[7] = m_planes[1].intersect(m_planes[3], m_planes[5]);

		return points;
	}
}