module thBase.math3d.box;

import thBase.math3d.position;
import thBase.math3d.vecs;
import thBase.metatools;
import thBase.format;
import thBase.math3d.sphere;

struct AlignedBox_t(T) {
	T min, max;
	
	this(T min, T max){
		this.min = min;
		this.max = max;
	}

  static if(is(T == typeof(Sphere.pos)))
  {
    this(Sphere s)
    {
      float radius = s.radius;
      this.min = s.pos - vec3(radius, radius, radius);
      this.max = s.pos + vec3(radius, radius, radius);
    }
  }
	
  static if(is(T == Position))
  {
	  this(vec3 min, vec3 max){
		  this.min = Position(min);
		  this.max = Position(max);
	  }
  }
	
	@property auto size() const {
		return (max - min);
	}

  enum size_t numVertices = 2 ^^ min.f.length;
	
	@property T[numVertices] vertices() const
		{
			T[numVertices] res;
			auto s = this.size();
			res[0] = min;
      static if(is(T == vec2))
      {
        res[1] = min + vec2(s.x ,0.0f);
        res[2] = min + vec2(s.x ,s.y );
        res[3] = min + vec2(0.0f,s.y );
      }
      else
      {
        res[1] = min + vec3(s.x ,0.0f,0.0f);
        res[2] = min + vec3(s.x ,s.y ,0.0f);
        res[3] = min + vec3(0.0f,s.y ,0.0f);
        res[4] = min + vec3(0.0f,0.0f,s.z );
        res[5] = min + vec3(s.x ,0.0f,s.z );
        res[6] = min + vec3(s.x ,s.y ,s.z );
        res[7] = min + vec3(0.0f,s.y ,s.z );
      }
			return res;
		}
	
	AlignedBox_t!T opBinary(string op)(const(T) rh) const if(op == "+"){
		return AlignedBox_t!T(min+rh, max+rh);
	}
	
	///Checks if the given type is inside this AligendBox
	bool opBinaryRight(string op, T)(T rh) const if(op == "in" && is(StripConst!(T) == Position)) 
		{
			return (min.opAll!("<")(rh) && rh.opAll!("<")(max));
		}
	
	///ditto
	bool opBinaryRight(string op, U)(U rh) const if(op == "in" && is(StripConst!(U) == AlignedBox_t!T))
		{
			bool cond1 = rh.min.allComponents!("<")(max);
			bool cond2 = rh.min.allComponents!(">")(min);
			bool cond3 = rh.max.allComponents!("<")(max);
			bool cond4 = rh.max.allComponents!(">")(min);
			return ( cond1 && cond2 && cond3 && cond4 );
		}
	
	///ditto
	bool opBinaryRight(string op, U)(U rh) const if(op == "in" && is(StripConst!(U) == vec3))
		{
			auto temp = Position(rh);
			return opBinaryRight!(op)(temp);
		}	
	
	//A.lo <= B.Hi && A.Hi >= B.lo
	bool intersects(AlignedBox_t!T rh) const {
    return (min.allComponents!("<=")(rh.max) && max.allComponents!(">=")(rh.min));
	}
	
  static if(is(typeof(T.isValid)))
  {
	  bool isValid() const {
		  return (min.isValid() && max.isValid());	
	  }
  }
	
	to_string_t toString(){
		return format("<AlignedBox min: %s, max: %s>", min.toString()[], max.toString()[]);
	}
	
	debug {
		invariant() {
			assert(min.allComponents!("<=")(max));
		}
	}

  auto width()
  {
    return max.x - min.x;
  }

  auto height()
  {
    return max.y - min.y;
  }

  static if(T.f.length >= 3)
  {
    auto depth()
    {
      return max.z - min.z;
    }
  }
}

alias AlignedBox_t!Position AlignedBox;
alias AlignedBox_t!vec3 AlignedBoxLocal;
alias AlignedBox_t!vec2 Rectangle;

unittest {
	AlignedBox box1 = AlignedBox(vec3(-20,-20,-20),vec3(-10,-10,-10));
	AlignedBox box2 = AlignedBox(vec3(10,10,10),vec3(20,20,20));
	assert(box1.intersects(box2) == false);
	
	AlignedBox box3 = AlignedBox(vec3(-10,-10,-10),vec3(10,10,10));
	AlignedBox box4 = AlignedBox(vec3(-20,-5,-5),vec3(20,5,5));
	AlignedBox box5 = AlignedBox(vec3(-5,-20,-5),vec3(5,20,5));
	AlignedBox box6 = AlignedBox(vec3(-5,-5,-20),vec3(5,5,20));
	AlignedBox box7 = AlignedBox(vec3(-5,-5,-5),vec3(5,5,5));
	assert(box3.intersects(box3));
	assert(box3.intersects(box4) && box4.intersects(box3));
	assert(box3.intersects(box5) && box5.intersects(box3));
	assert(box3.intersects(box6) && box6.intersects(box3));
	assert(box3.intersects(box7) && box7.intersects(box3));
	
	assert((box7 in box3) == true);
	assert((box4 in box5) == false);
	
	AlignedBox box8 = AlignedBox(vec3(-250,-250,-250),vec3(0,0,0));
	AlignedBox box9 = AlignedBox(vec3(10.8533,12.2839,-23.83),vec3(19.1467,21.7161,-14.17));
	assert(box9.intersects(box8) == false);
	assert((box9 in box8) == false);
	
	auto frigate = AlignedBox(
		Position(Position.cell_t(-1,-1,-1), vec3(877.529,954.593,739.159)),
		Position(Position.cell_t(0,0,0), vec3(122.471,53.5403,253.732))
	);
	auto player = AlignedBox(
		Position(Position.cell_t(-1,-1,0), vec3(996.432,995.586,95.0833)),
		Position(Position.cell_t(0,0,0), vec3(3.56763,4.41388,104.917))
	);
	assert((player in frigate) == true);
}