module thBase.math3d.triangle;

import thBase.math3d.vecs;
import std.math;
import thBase.math3d.plane;
import thBase.math3d.ray;
import thBase.math3d.mats;
import thBase.algorithm;
import thBase.math;

struct Triangle {
	vec3[3] v;
	Plane plane; //remove the plane equation from the Triangle because it has to be transformed anyway
	
	this(vec3 v1, vec3 v2, vec3 v3){
		v[0] = v1;
		v[1] = v2;
		v[2] = v3;
		plane = Plane(v1,v2,v3);
	}
	
	bool intersects(ref const(Triangle) other, ref Ray intersection) const {
		float d1 = plane.distance(other.v[0]);
		float d2 = plane.distance(other.v[1]);
		float d3 = plane.distance(other.v[2]);
		
		if((d1 < 0 && d2 < 0 && d3 < 0) || 
		   (d1 > 0 && d2 > 0 && d3 > 0) || 
		   (d1 == d2 && d2 == d3))
		{
			return false;
		}
		
		float t1 = other.plane.distance(v[0]);
		float t2 = other.plane.distance(v[1]);
		float t3 = other.plane.distance(v[2]);
		
		if((t1 < 0 && t2 < 0 && t3 < 0) ||
		   (t1 > 0 && t2 > 0 && t3 > 0))
		{
			return false;
		}
		
		//the intersecting edges will be v1v2 and v1v3
		vec3 v1,v2,v3;
		
		if(sgn(d1) + sgn(d2) + sgn(d3) > 0){
			//one negative and 2 positive
			if(d1 < 0){
				v1 = other.v[0];
				v2 = other.v[1];
				v3 = other.v[2];
			}
			else if(d2 < 0){
				swap(d1,d2);
				v1 = other.v[1];
				v2 = other.v[0];
				v3 = other.v[2];
			}
			else {
				swap(d1,d3);
				v1 = other.v[2];
				v2 = other.v[1];
				v3 = other.v[0];
			}
		}
		else {
			//one positive and 2 negative
			if(d1 >= 0){
				v1 = other.v[0];
				v2 = other.v[1];
				v3 = other.v[2];
			}
			else if(d2 >= 0){
				swap(d1,d2);
				v1 = other.v[1];
				v2 = other.v[0];
				v3 = other.v[2];
			}
			else {
				swap(d1,d3);
				v1 = other.v[2];
				v2 = other.v[1];
				v3 = other.v[0];
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
				v1 = v[0];
				v2 = v[1];
				v3 = v[2];
			}
			else if(t2 < 0){
				swap(t1,t2);
				v1 = v[1];
				v2 = v[0];
				v3 = v[2];
			}
			else {
				swap(t1,t3);
				v1 = v[2];
				v2 = v[1];
				v3 = v[0];
			}
		}
		else {
			//one positive and 2 negative
			if(t1 >= 0){
				v1 = v[0];
				v2 = v[1];
				v3 = v[2];
			}
			else if(t2 >= 0){
				swap(t1,t2);
				v1 = v[1];
				v2 = v[0];
				v3 = v[2];
			}
			else {
				swap(t1,t3);
				v1 = v[2];
				v2 = v[1];
				v3 = v[0];
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
	
	Triangle transform(mat4 transformation) const {
		vec4 v1 = transformation * vec4(v[0]);
		vec4 v2 = transformation * vec4(v[1]);
		vec4 v3 = transformation * vec4(v[2]);
		
		return Triangle(vec3(v1),vec3(v2),vec3(v3));
	}
	
	//bool RayColVertex(vertex S1, vertex S2, vertex R1, vertex R2, vertex R3, float *RayValue){
	//S1 = raypos
	//S2 = tri pos
	//R1 = ray dir
	//R2 = tri dir 1
	//R3 = tri dir 2
	bool intersects(Ray ray, ref float rayPos){
	  float t1,t2,t3,d,dt1,dt2,dt3;
	  vec3 R2 = v[1] - v[0];
	  vec3 R3 = v[2] - v[0];
	  d = R3.x*R2.y*ray.dir.z + R3.y*R2.z*ray.dir.x + R3.z*R2.x*ray.dir.y - ray.dir.x*R2.y*R3.z - ray.dir.y*R2.z*R3.x - ray.dir.z*R2.x*R3.y;
	  if(d != 0.0f){
	   dt1 = (ray.pos.x-v[0].x)*R2.y*R3.z + (ray.pos.y-v[0].y)*R2.z*R3.x + (ray.pos.z-v[0].z)*R2.x*R3.y - R3.x*R2.y*(ray.pos.z-v[0].z) - R3.y*R2.z*(ray.pos.x-v[0].x) - R3.z*R2.x*(ray.pos.y-v[0].y);
	   dt2 = R3.x*(ray.pos.y-v[0].y)*ray.dir.z + R3.y*(ray.pos.z-v[0].z)*ray.dir.x + R3.z*(ray.pos.x-v[0].x)*ray.dir.y - ray.dir.x*(ray.pos.y-v[0].y)*R3.z - ray.dir.y*(ray.pos.z-v[0].z)*R3.x - ray.dir.z*(ray.pos.x-v[0].x)*R3.y;
	   dt3 = (ray.pos.x-v[0].x)*R2.y*ray.dir.z + (ray.pos.y-v[0].y)*R2.z*ray.dir.x + (ray.pos.z-v[0].z)*R2.x*ray.dir.y - ray.dir.x*R2.y*(ray.pos.z-v[0].z) - ray.dir.y*R2.z*(ray.pos.x-v[0].x) - ray.dir.z*R2.x*(ray.pos.y-v[0].y);
	   t1 = dt1 / d;
	   t2 = dt2 / d;
	   t3 = dt3 / d;
	  }
	  else{
		rayPos=float.nan;
		return false;
	  }
	  if((t2+t3)<= 1.0f && t2 > 0.0f && t3 > 0.0f){
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
	  v2 = v[1] - v[0];
	  v3 = v[2] - v[0];
	  //normal
	  normal.x = v2.y * v3.z - v2.z * v3.y;
	  normal.y = v2.z * v3.x - v2.x * v3.z;
	  normal.z = v2.x * v3.y - v2.y * v3.x;
	  normal = normal.normalize();
	  return normal;
	}
}