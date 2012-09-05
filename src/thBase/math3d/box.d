module thBase.math3d.box;

import thBase.math3d.position;
import thBase.math3d.vecs;
import thBase.metatools;
import thBase.format;

struct AlignedBox {
	Position min,max;
	
	this(Position min, Position max){
		this.min = min;
		this.max = max;
	}
	
	this(vec3 min, vec3 max){
		this.min = Position(min);
		this.max = Position(max);
	}
	
	@property vec3 size() const {
		return (max - min);
	}
	
	@property Position[8] vertices() const
		{
			Position[8] res;
			vec3 s = this.size;
			res[0] = min;
			res[1] = min + vec3(s.x ,0.0f,0.0f);
			res[2] = min + vec3(s.x ,s.y ,0.0f);
			res[3] = min + vec3(0.0f,s.y ,0.0f);
			res[4] = min + vec3(0.0f,0.0f,s.z );
			res[5] = min + vec3(s.x ,0.0f,s.z );
			res[6] = min + vec3(s.x ,s.y ,s.z );
			res[7] = min + vec3(0.0f,s.y ,s.z );
			return res;
		}
	
	AlignedBox opBinary(string op)(const(Position) rh) const if(op == "+"){
		return AlignedBox(min+rh,max+rh);
	}
	
	///Checks if the given type is inside this AligendBox
	bool opBinaryRight(string op, T)(T rh) const if(op == "in" && is(StripConst!(T) == Position)) 
		{
			return (min.opAll!("<")(rh) && rh.opAll!("<")(max));
		}
	
	///ditto
	bool opBinaryRight(string op, T)(T rh) const if(op == "in" && is(StripConst!(T) == AlignedBox))
		{
			bool cond1 = rh.min.opAll!("<")(max);
			bool cond2 = rh.min.opAll!(">")(min);
			bool cond3 = rh.max.opAll!("<")(max);
			bool cond4 = rh.max.opAll!(">")(min);
			return ( cond1 && cond2 && cond3 && cond4 );
		}
	
	///ditto
	bool opBinaryRight(string op, T)(T rh) const if(op == "in" && is(StripConst!(T) == vec3))
		{
			auto temp = Position(rh);
			return opBinaryRight!(op)(temp);
		}	
	
	//A.lo <= B.Hi && A.Hi >= B.lo
	bool intersects(AlignedBox rh) const {
		/*return !(max.opSingle!("<","x")(rh.min) || rh.max.opSingle!("<","x")(min) ||
				 max.opSingle!("<","y")(rh.min) || rh.max.opSingle!("<","y")(min) ||
				 max.opSingle!("<","z")(rh.min) || rh.max.opSingle!("<","z")(min));*/
		return (min.opSingle!("<=","x")(rh.max) && max.opSingle!(">=","x")(rh.min) &&
				min.opSingle!("<=","y")(rh.max) && max.opSingle!(">=","y")(rh.min) &&
				min.opSingle!("<=","z")(rh.max) && max.opSingle!(">=","z")(rh.min));
	}
	
	bool isValid() const {
		return (min.isValid() && max.isValid());	
	}
	
	to_string_t toString(){
		return format("<AlignedBox min: %s, max: %s>", min.toString()[], max.toString()[]);
	}
	
	debug {
		invariant() {
			assert(min.opAll!("<=")(max));
		}
	}
}

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