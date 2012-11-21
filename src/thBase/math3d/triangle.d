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
		float d1 = plane.distance(other.v0);
		float d2 = plane.distance(other.v1);
		float d3 = plane.distance(other.v2);
		
		if((d1 < FloatEpsilon && d2 < FloatEpsilon && d3 < FloatEpsilon) || 
		   (d1 > -FloatEpsilon && d2 > -FloatEpsilon && d3 > -FloatEpsilon) || 
		   (d1 == d2 && d2 == d3))
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
				v1 = v0;
				v2 = v1;
				v3 = v2;
			}
			else if(t2 < 0){
				swap(t1,t2);
				v1 = v1;
				v2 = v0;
				v3 = v2;
			}
			else {
				swap(t1,t3);
				v1 = v2;
				v2 = v1;
				v3 = v0;
			}
		}
		else {
			//one positive and 2 negative
			if(t1 >= 0){
				v1 = v0;
				v2 = v1;
				v3 = v2;
			}
			else if(t2 >= 0){
				swap(t1,t2);
				v1 = v1;
				v2 = v0;
				v3 = v2;
			}
			else {
				swap(t1,t3);
				v1 = v2;
				v2 = v1;
				v3 = v0;
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
	
	//bool RayColVertex(vertex S1, vertex S2, vertex R1, vertex R2, vertex R3, float *RayValue){
	//S1 = raypos
	//S2 = tri pos
	//R1 = ray dir
	//R2 = tri dir 1
	//R3 = tri dir 2
	bool intersects(Ray ray, ref float rayPos){
	  float t1 = 0.0f,t2 = 0.0f,t3 = 0.0f,dt1 = 0.0f,dt2 = 0.0f,dt3 = 0.0f;
	  vec3 R2 = v1 - v0;
	  vec3 R3 = v2 - v0;
	  float d = R3.x*R2.y*ray.dir.z + R3.y*R2.z*ray.dir.x + R3.z*R2.x*ray.dir.y - ray.dir.x*R2.y*R3.z - ray.dir.y*R2.z*R3.x - ray.dir.z*R2.x*R3.y;
	  if(d != 0.0f){
	    dt1 = (ray.pos.x-v0.x)*R2.y*R3.z + (ray.pos.y-v0.y)*R2.z*R3.x + (ray.pos.z-v0.z)*R2.x*R3.y - R3.x*R2.y*(ray.pos.z-v0.z) - R3.y*R2.z*(ray.pos.x-v0.x) - R3.z*R2.x*(ray.pos.y-v0.y);
	    dt2 = R3.x*(ray.pos.y-v0.y)*ray.dir.z + R3.y*(ray.pos.z-v0.z)*ray.dir.x + R3.z*(ray.pos.x-v0.x)*ray.dir.y - ray.dir.x*(ray.pos.y-v0.y)*R3.z - ray.dir.y*(ray.pos.z-v0.z)*R3.x - ray.dir.z*(ray.pos.x-v0.x)*R3.y;
	    dt3 = (ray.pos.x-v0.x)*R2.y*ray.dir.z + (ray.pos.y-v0.y)*R2.z*ray.dir.x + (ray.pos.z-v0.z)*R2.x*ray.dir.y - ray.dir.x*R2.y*(ray.pos.z-v0.z) - ray.dir.y*R2.z*(ray.pos.x-v0.x) - ray.dir.z*R2.x*(ray.pos.y-v0.y);
	    t1 = dt1 / d;
	    t2 = dt2 / d;
	    t3 = dt3 / d;
	  }
	  else{
		  rayPos=float.nan;
		  return false;
	  }
	  if((t2+t3)<= 1.0f && t2 >= 0.0f && t3 >= 0.0f){
		  rayPos = t1;
		  return true;
	  }
	  else{
		  rayPos=float.nan;
		  return false;
	  }
	  assert(0,"not reachable");
	}
	
	vec3 normal(){
	  vec3 normal,v1,v2,v3;
	  v2 = v1 - v0;
	  v3 = v2 - v0;
	  //normal
	  normal.x = v2.y * v3.z - v2.z * v3.y;
	  normal.y = v2.z * v3.x - v2.x * v3.z;
	  normal.z = v2.x * v3.y - v2.y * v3.x;
	  normal = normal.normalize();
	  return normal;
	}
}

unittest
{
  auto t1 = Triangle(vec3(-25,-1,-25),
                     vec3(-25,-1, 25),
                     vec3( 25,-1,-25));
  auto t2 = Triangle(vec3( 1, 1, 1),
                     vec3(-1,-1, 1),
                     vec3( 1,-1, 1));
  Ray intersectionRay;
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