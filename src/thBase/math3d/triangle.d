module thBase.math3d.triangle;

import thBase.math3d.vecs;
import std.math;
import thBase.math3d.plane;
import thBase.math3d.ray;
import thBase.math3d.mats;
import thBase.algorithm;
import thBase.math;

version(USE_SSE)
{
  import thBase.sse;
}

struct Triangle {
	vec3 v0; version(USE_SSE){ float w1 = 1.0f; }
  vec3 v1; version(USE_SSE){ float w2 = 1.0f; }
  vec3 v2; version(USE_SSE){ float w3 = 1.0f; }
	Plane plane; //remove the plane equation from the Triangle because it has to be transformed anyway
	
	this(vec3 v1, vec3 v2, vec3 v3){
		this.v0 = v1;
		this.v1 = v2;
		this.v2 = v3;
		plane = Plane(v1,v2,v3);
	}
	
	bool intersects(ref const(Triangle) other, ref Ray intersection) const {
    float dot = this.plane.m_Eq.dot(other.plane.m_Eq);
    if(abs(dot) >= 1.0f - FloatEpsilon)
    {
      //the two triangles are coplanar
      return false;
    }

		float d1 = plane.distance(other.v0);
		float d2 = plane.distance(other.v1);
		float d3 = plane.distance(other.v2);
		
		if((d1 < FloatEpsilon && d2 < FloatEpsilon && d3 < FloatEpsilon) || 
		   (d1 > -FloatEpsilon && d2 > -FloatEpsilon && d3 > -FloatEpsilon) || 
		   (d1.epsilonCompare(d2) && d2.epsilonCompare(d3))
      )
		{
			return false;
		}
		
		float t1 = other.plane.distance(v0);
		float t2 = other.plane.distance(v1);
		float t3 = other.plane.distance(v2);
		
		if((t1 < FloatEpsilon && t2 < FloatEpsilon && t3 < FloatEpsilon) ||
		   (t1 > -FloatEpsilon && t2 > -FloatEpsilon && t3 > -FloatEpsilon))
		{
			return false;
		}
		
		//the intersecting edges will be v1v2 and v1v3
		vec3 v1,v2,v3;
		
		if(sgn(d1) + sgn(d2) + sgn(d3) > 0){
			//one negative and 2 positive
			if(d1 < 0){
				v1 = other.v0;
				v2 = other.v1;
				v3 = other.v2;
			}
			else if(d2 < 0){
				swap(d1,d2);
				v1 = other.v1;
				v2 = other.v0;
				v3 = other.v2;
			}
			else {
				swap(d1,d3);
				v1 = other.v2;
				v2 = other.v1;
				v3 = other.v0;
			}
		}
		else {
			//one positive and 2 negative
			if(d1 >= 0){
				v1 = other.v0;
				v2 = other.v1;
				v3 = other.v2;
			}
			else if(d2 >= 0){
				swap(d1,d2);
				v1 = other.v1;
				v2 = other.v0;
				v3 = other.v2;
			}
			else {
				swap(d1,d3);
				v1 = other.v2;
				v2 = other.v1;
				v3 = other.v0;
			}
		}
		
		Ray L = plane.intersect(other.plane);
		
		float pos1 = L.dir.dot(v1 - L.pos);
		float pos2 = L.dir.dot(v2 - L.pos);
		float pos3 = L.dir.dot(v3 - L.pos);
		
		float[2] interval1;
		interval1[0] = pos1 + (pos2 - pos1) * (d1 / (d1 - d2));
		interval1[1] = pos1 + (pos3 - pos1) * (d1 / (d1 - d3));
		if(interval1[0] > interval1[1])
			swap(interval1[0],interval1[1]);
		
		if(sgn(t1) + sgn(t2) + sgn(t3) > 0){
			//one negative and 2 positive
			if(t1 < 0){
				v1 = this.v0;
				v2 = this.v1;
				v3 = this.v2;
			}
			else if(t2 < 0){
				swap(t1,t2);
				v1 = this.v1;
				v2 = this.v0;
				v3 = this.v2;
			}
			else {
				swap(t1,t3);
				v1 = this.v2;
				v2 = this.v1;
				v3 = this.v0;
			}
		}
		else {
			//one positive and 2 negative
			if(t1 >= 0){
				v1 = this.v0;
				v2 = this.v1;
				v3 = this.v2;
			}
			else if(t2 >= 0){
				swap(t1,t2);
				v1 = this.v1;
				v2 = this.v0;
				v3 = this.v2;
			}
			else {
				swap(t1,t3);
				v1 = this.v2;
				v2 = this.v1;
				v3 = this.v0;
			}
		}
		
		pos1 = L.dir.dot(v1 - L.pos);
		pos2 = L.dir.dot(v2 - L.pos);
		pos3 = L.dir.dot(v3 - L.pos);
		
		float[2] interval2;
		interval2[0] = pos1 + (pos2 - pos1) * (t1 / (t1 - t2));
		interval2[1] = pos1 + (pos3 - pos1) * (t1 / (t1 - t3));
		if(interval2[0] > interval2[1])
			swap(interval2[0],interval2[1]);
		
		if(interval1[0] >= interval2[0] && interval1[0] <= interval2[1])
    {
      intersection = Ray.CreateFromPoints(L.get(interval1[0]), L.get(min(interval1[1], interval2[1])));
      return true;
    }
		else if(interval1[1] >= interval2[0] && interval1[1] <= interval2[1])
    {
      intersection = Ray.CreateFromPoints(L.get(max(interval1[0], interval2[0])), L.get(interval1[1]));
      return true;
    }
    else if(interval1[0] <= interval2[0] && interval1[1] >= interval2[1])
    {
      intersection = Ray.CreateFromPoints(L.get(interval2[0]), L.get(interval2[1]));
      return true;
    }
		
		return false;
	}
	
	Triangle transform(ref const(mat4) transformation) const {
    version(USE_SSE)
    {
      mat4 t = transformation.Transpose();
      mat4* tPtr = &t;
      Triangle result;
      Triangle* resultPtr = &result;
      asm 
      {
        mov ECX,this;
        mov EDX,tPtr;
        mov EAX,resultPtr;
        movups XMM0,[EDX]; //t.f[0..4] -> XMM0
        movups XMM1,[EDX+16]; //t.f[4..8] -> XMM1
        movups XMM2,[EDX+32]; //t.f[8..12] -> XMM2
        // v0
        movups XMM3,[ECX];
        movaps XMM4,XMM3;
        movaps XMM5,XMM3;
        dpps XMM3,XMM0, 0b1111_0001; // x = dot(XMM3, XMM0)
        dpps XMM4,XMM1, 0b1111_0010; // y = dot(XMM4, XMM1)
        dpps XMM5,XMM2, 0b1111_0100; // z = dot(XMM5, XMM1)
        addps XMM3,XMM4;
        addps XMM3,XMM5;
        // v1
        movups XMM6, [ECX+16];
        movaps XMM4,XMM6;
        movaps XMM5,XMM6;
        dpps XMM6,XMM0, 0b1111_0001; // x = dot(XMM3, XMM0)
        dpps XMM4,XMM1, 0b1111_0010; // y = dot(XMM4, XMM1)
        dpps XMM5,XMM2, 0b1111_0100; // z = dot(XMM5, XMM1)
        addps XMM6,XMM4;
        addps XMM6,XMM5;
        // v2
        movups XMM7, [ECX+32];
        movaps XMM4,XMM7;
        movaps XMM5,XMM7;
        dpps XMM7,XMM0, 0b1111_0001; // x = dot(XMM3, XMM0)
        dpps XMM4,XMM1, 0b1111_0010; // y = dot(XMM4, XMM1)
        dpps XMM5,XMM2, 0b1111_0100; // z = dot(XMM5, XMM1)
        addps XMM7,XMM4;
        addps XMM7,XMM5;
        // transformed v0 in XMM3
        // transformed v1 in XMM6
        // transformed v2 in XMM7
        movups [EAX],XMM3;
        movups [EAX+16],XMM6;
        movups [EAX+32],XMM7;
        // compute plane equation
        movaps XMM0,XMM6; //v1
        movaps XMM1,XMM7; //v2
        subps XMM0,XMM3; //v1 - v0 -> dir1
        subps XMM1,XMM3; //v2 - v0 -> dir2
        //cross(XMM0,XMM1)
        pshufd XMM2,XMM0, 0b11_00_10_01; //dir1 shuffle yzxw
        pshufd XMM0,XMM0, 0b11_01_00_10; //dir1 shuffle zxyw
        pshufd XMM3,XMM1, 0b11_01_00_10; //dir2 shuffle zxyw
        pshufd XMM1,XMM1, 0b11_00_10_01; //dir2 shuffle yzxw
        mulps XMM2,XMM3;
        mulps XMM0,XMM1;
        subps XMM2,XMM0; //unnormalized plane normal in XMM2
        movaps XMM0,XMM2;
        dpps XMM0,XMM2, 0b0111_0001; //dot(normal,normal)
        sqrtss XMM0, XMM0;
        pshufd XMM0, XMM0, 0b00_00_00_00; //shuffle xxxx
        divps XMM2,XMM0; //normalized normal in XMM2
        movaps XMM3,XMM2;
        dpps XMM3,XMM7, 0b0111_1000; //dot(normal,v2) -> w (distance)
        addps XMM2,XMM3;
        movups [EAX+48],XMM2;
      }
      result.w1 = result.w2 = result.w3 = 1.0f;
      return result;
    }
    else
    {
		  vec3 v1 = transformation * this.v0;
		  vec3 v2 = transformation * this.v1;
		  vec3 v3 = transformation * this.v2;
		
		  return Triangle(v1,v2,v3);
    }
	}
	
	bool intersects(Ray ray, ref float rayPos) const {
    float u,v;
    return intersects(ray, rayPos, u, v);
	}

	bool intersects(Ray ray, ref float rayPos, ref float u, ref float v) const {
	  float[4] t;
    float[4] dt;
    version(USE_SSE)
    {
      float minusOne = -1.0f;
      float d;
      asm {
        mov EDX, this;
        movups XMM0, [EDX]; //load v0
        movups XMM1, [EDX+16]; //load v1
        movups XMM2, [EDX+32]; //load v2
        // vec3 R2 = v1 - v0;
        subps XMM1, XMM0; // v1 - v0 -> R2
        // vec3 R3 = v2 - v0;
        subps XMM2, XMM0; // v2 - v0 -> R3
        //d = (R3.xyz * R2.yzx).dot(ray.dir.zxy) - ((R3.xyz * R2.zxy).dot(ray.dir.yzx))
        lea EAX, ray;
        lea EBX, minusOne;
        movups XMM5, [EAX+12]; //load ray.dir 
        pshufd XMM3, XMM1, 0b11_00_10_01; //shuffle yzxw -> R2.yzx
        pshufd XMM4, XMM1, 0b11_01_00_10; //shulfle zxyw -> R2.zxy
        movaps XMM6, XMM5; // -> copy ray.dir 
        pshufd XMM6, XMM6, 0b11_00_10_01; // shuffle yzxw -> ray.dir.yzx
        pshufd XMM5, XMM5, 0b11_01_00_10; // shuffle zxyw -> ray.dir.zxy
        mulps XMM3, XMM2; // -> (R3.xyz * R2.yzx)
        mulps XMM4, XMM2; // -> (R3.xyz * R2.zxy)
        dpps XMM3, XMM5, 0b0111_0001; // -> (R3.xyz * R2.yzx).dot(ray.dir.zxy)
        dpps XMM4, XMM6, 0b0111_0001; // -> (R3.xyz * R2.zxy).dot(ray.dir.yzx)
        subss XMM3, XMM4; // -> d
        lea EAX, d;
        movss [EAX], XMM3;
      }
    }
    else
    {
	    vec3 R2 = v1 - v0;
	    vec3 R3 = v2 - v0;
	    float d = R3.x * R2.y * ray.dir.z + 
        R3.y * R2.z * ray.dir.x + 
        R3.z * R2.x * ray.dir.y - 
        ray.dir.x * R2.y * R3.z - 
        ray.dir.y * R2.z * R3.x - 
        ray.dir.z * R2.x * R3.y;
    }
	  if(d != 0.0f){
      version(USE_SSE)
      {
        asm {
          // XMM1 = R2.yzx
          // XMM2 = R3.zxy
          // XMM3 = diff
          pshufd XMM1, XMM1, 0b11_00_10_01; //shuffle yzxw -> R2.yzx
          pshufd XMM2, XMM2, 0b11_01_00_10; //shuffle zxyw -> R3.zxy

          //diff = ray.pos - v0;
          lea EAX, ray;
          movups XMM3, [EAX]; //load ray.pos
          subps XMM3, XMM0; // ray.pos - v0 -> diff
          movups XMM4, [EAX+12]; //load ray.dir
          pshufd XMM4, XMM4, 0b11_00_10_01; // shuffle yzxw -> ray.dir.yzx

          //dt1 = (diff.xyz * R2.yzx).dot(R3.zxy) - ((R3.yzx * R2.zxy).dot(diff.xyz))
          // needs
          //  R2.yzx, R2.zxy
          //  R3.zxy, R3.yzx <- keep
          movaps XMM5, XMM1;
          mulps XMM5, XMM3; // -> diff.xyz * R2.yzx
          pshufd XMM0, XMM1, 0b11_00_10_01; //shuffle yzxw -> R2.zxy
          pshufd XMM7, XMM2, 0b11_01_00_10; //shuffle zxyw -> R3.yzx
          mulps XMM0, XMM7; // -> R3.yzx * R2.zxy
          dpps XMM5, XMM2, 0b0111_0001; // -> (diff.xyz * R2.yzx).dot(R3.zxy)
          dpps XMM0, XMM3, 0b0111_0001; // -> ((R3.yzx * R2.zxy).dot(diff.xyz))
          subss XMM5, XMM0; // -> dt1
          lea EAX, dt;
          movss [EAX], XMM5;
        

          // ray.dir.yzx -> ray.dir.zxy
          pshufd XMM0, XMM4, 0b11_00_10_01; //shuffle yzxw -> ray.dir.zxy 

          //dt2 = (R3.zxy * diff.xyz).dot(ray.dir.yzx) - ((ray.dir.zxy).dot(diff.xyz * R3.yzx))
          // needs
          //  R3.zxy, R3.yzx
          //  ray.dir.yzx, ray.dir.zxy <- keep
          
          mulps XMM2, XMM3; // -> R3.zxy * diff.xyz
          mulps XMM7, XMM3; // -> diff.xyz * R3.yzx
          dpps XMM2, XMM4, 0b0111_0001; // -> (R3.zxy * diff.xyz).dot(ray.dir.yzx)
          dpps XMM7, XMM0, 0b0111_0001; // -> (ray.dir.zxy).dot(diff.xyz * R3.yzx)
          subss XMM2, XMM7; // -> dt2
          lea EAX, dt;
          movss [EAX+4], XMM2;

          //dt3 = (R2.yzx).dot(ray.dir.zxy * diff.xyz) - ((R2.zxy).dot(ray.dir.yzx * diff.xyz))
          // needs
          //  R2.yzx, R2.zxy
          //  ray.dir.zxy, ray.dir.yzx

          pshufd XMM2, XMM1, 0b11_00_10_01; //shuffle yzxw -> R2.zxy
          mulps XMM0, XMM3; // -> ray.dir.zxy * diff.xyz
          mulps XMM4, XMM3; // -> ray.dir.yzx * diff.xyz
          dpps XMM0, XMM1, 0b0111_0001; // -> (R2.yzx).dot(ray.dir.zxy * diff.xyz)
          dpps XMM4, XMM2, 0b0111_0001; // -> (R2.zxy).dot(ray.dir.yzx * diff.xyz)
          subss XMM0, XMM4; // -> dt3
          lea EAX, dt;
          movss [EAX+8], XMM0;

          lea EBX, t;
          lea EDX, d;
          movups XMM0, [EAX];
          movss XMM1, [EDX];
          pshufd XMM1, XMM1, 0b00_00_00_00;
          divps XMM0, XMM1;
          movups [EBX], XMM0; // -> t[0..3] / d
        }
      }
      else
      {
	      dt[0] =  (ray.pos.x-v0.x)*R2.y*R3.z 
             + (ray.pos.y-v0.y)*R2.z*R3.x 
             + (ray.pos.z-v0.z)*R2.x*R3.y 
             - R3.y*R2.z*(ray.pos.x-v0.x) 
             - R3.z*R2.x*(ray.pos.y-v0.y)
             - R3.x*R2.y*(ray.pos.z-v0.z);
	    
        dt[1] = R3.z*(ray.pos.x-v0.x)*ray.dir.y 
            + R3.x*(ray.pos.y-v0.y)*ray.dir.z 
            + R3.y*(ray.pos.z-v0.z)*ray.dir.x 
            - ray.dir.z*(ray.pos.x-v0.x)*R3.y
            - ray.dir.x*(ray.pos.y-v0.y)*R3.z 
            - ray.dir.y*(ray.pos.z-v0.z)*R3.x ;

	      dt[2] = (ray.pos.x-v0.x)*R2.y*ray.dir.z 
            + (ray.pos.y-v0.y)*R2.z*ray.dir.x 
            + (ray.pos.z-v0.z)*R2.x*ray.dir.y 
            - ray.dir.y*R2.z*(ray.pos.x-v0.x) 
            - ray.dir.z*R2.x*(ray.pos.y-v0.y)
            - ray.dir.x*R2.y*(ray.pos.z-v0.z) ;
	      t[0] = dt[0] / d;
	      t[1] = dt[1] / d;
	      t[2] = dt[2] / d;
      }
	  }
	  else
    {
		  rayPos=float.nan;
      u = float.nan;
      v = float.nan;
		  return false;
	  }
	  if((t[1]+t[2])<= 1.0f && t[1] >= 0.0f && t[2] >= 0.0f){
		  rayPos = t[0];
      u = t[2];
      v = t[1];
		  return true;
	  }
		rayPos=float.nan;
    u = float.nan;
    v = float.nan;
		return false;
	}

  /// the area of the triangle
  @property float area() const
  {
    vec3 e1 = v1 - v0;
    vec3 e2 = v2 - v0;
    vec3 heightBase = e1.dot(e2);
    return (e1 - e2 * heightBase).length * e2.length * 0.5f;
  }
}

unittest //for triangle ray intersection
{
  {
    auto tri = Triangle(vec3(-10, -10.000000, 19.984970),
                      vec3(-10, 10, 0),
                      vec3(-10, 10, 19.984970));

    auto ray = Ray(vec3(-1, 26.5, 10), vec3(-0.43670523, -0.84072918, 0.32009855));
    float t,u,v;
    assert(tri.intersects(ray, t, u, v));
    assert(t.epsilonCompare(20.608866f, 0.1f));
    assert(u.epsilonCompare(0.78914368f, 0.1f));
    assert(v.epsilonCompare(0.16953248f, 0.1f));
  }

  {
    auto tri = Triangle(vec3(-1.0213749f, -0.19982199f, 15.151754f), 
                        vec3(1.6758910f, 5.3727779f, 15.151754f),
                        vec3(1.6758910f, 5.3727779f, 0.0f));
    auto ray = Ray(vec3(2.9275560f, -10.000000f, 13.528505f), 
                   vec3(-0.12780648f, 0.97445291f, -0.18468098f));
    float t,u,v;
    assert(tri.intersects(ray, t, u, v));
    assert(t.epsilonCompare(14.500357f, 0.1f));
    assert(u.epsilonCompare(0.28387401f, 0.1f));
    assert(v.epsilonCompare(0.49309477f, 0.1f));
  }
}

unittest //for triangle triangle intersection
{
  auto t1 = Triangle(vec3(-25,-1,-25),
                     vec3(-25,-1, 25),
                     vec3( 25,-1,-25));
  auto t2 = Triangle(vec3( 1, 1, 1),
                     vec3(-1,-1, 1),
                     vec3( 1,-1, 1));
  Ray intersectionRay;
  assert(!t1.intersects(t2, intersectionRay));

  t1 = Triangle(vec3(4.0100098,-0.40002441,1.0100098),
                         vec3(2.0100098,-0.40002441,1.0100098),
                         vec3(4.0100098,-0.40002441,-0.98999023));
  t2 = Triangle(vec3(1.0000000,1.0000000,1.0000000),
                         vec3(-1.0000000,1.0000000,1.0000000),
                         vec3(-1.0000000,-1.0000000,1.0000000));

  assert(!t1.intersects(t2, intersectionRay));
}

version(unittest)
{
  import thBase.math3d.quaternion;
  import thBase.math3d.all;
  import thBase.io;
}

version = SPEED_TEST;

version(unittest)
{
  import std.random;
  import thBase.timer;
}

unittest
{
  mat4 transformation = TranslationMatrix(1,2,3) * Quaternion(vec3(1,5,2), -15).toMat4() * ScaleMatrix(0.1,0.1,0.1);
  auto t1 = Triangle(vec3(1,1,0), vec3(-1,1,0), vec3(-1,-1,0));
  auto t2 = t1.transform(transformation);
  assert(t2.v0.epsilonCompare(vec3(0.27152431f, 0.37433851f, 0.078391626f)));
  assert(t2.v1.epsilonCompare(vec3(0.20380020f, 0.28224021f, 0.24249937f)));
  assert(t2.v2.epsilonCompare(vec3(0.25028610f, 0.10504641f, 0.16224094f)));
  assert(t2.plane.m_Eq.epsilonCompare(vec4(0.91176343f, 0.054831631f, 0.40703908f, 0.29999998f)));
  version(SPEED_TEST)
  {
    auto ts = NewArray!Triangle(10000);
    scope(exit) Delete(ts);
    Random gen;
    foreach(ref t; ts)
    {
      t = Triangle(vec3(uniform(-100.0f, 100.0f, gen), uniform(-100.0f, 100.0f, gen), uniform(-100.0f, 100.0f, gen)),
                   vec3(uniform(-100.0f, 100.0f, gen), uniform(-100.0f, 100.0f, gen), uniform(-100.0f, 100.0f, gen)),
                   vec3(uniform(-100.0f, 100.0f, gen), uniform(-100.0f, 100.0f, gen), uniform(-100.0f, 100.0f, gen)));
    }
    shared(Timer) timer = New!(shared(Timer))();
    scope(exit) Delete(timer);
    auto start = Zeitpunkt(timer);
    foreach(ref t; ts)
    {
      t = t.transform(transformation);
    }
    auto time = Zeitpunkt(timer) - start;
    writefln("Triangle.transform for %d entries took %f ms", ts.length, time);
  }
}

// unittest for the area property
unittest
{
  auto t1 = Triangle(vec3(1,0,0), vec3(0,1,0), vec3(1,1,0));
  assert(t1.area.epsilonCompare(0.5f));
}