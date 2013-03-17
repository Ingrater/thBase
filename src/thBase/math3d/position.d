module thBase.math3d.position;

import thBase.math3d.vecs;
import thBase.metatools;
import thBase.format;

struct Position {
  struct Component
  {
    int cell;
    float relPos;

    this(int cell, float relPos)
    {
      this.cell = cell;
      this.relPos = relPos;
    }

    bool opEquals(const(Component) rh)
    {
      return (this.cell == rh.cell) && (this.relPos == rh.relPos);
    }

    int opCmp(const(Component) rh)
    {
      int cellDiff = rh.cell - this.cell;
      if(cellDiff != 0)
        return cellDiff;
      return cast(int)(this.relPos > rh.relPos) - cast(int)(this.relPos < rh.relPos);
    }
  }

  version(USE_SSE){
    alias vec3_t!(int) cell_t;
  }
  else {
    alias vec3_t!(int) cell_t;
  }
  alias vec3 pos_t;
  
  version(USE_SSE){
    static if(cell_t.sizeof == 12){
      struct cell_fill_t {
        cell_t cell;
        int iPadding;
      }
    }
    else {
      static assert(cell_t.sizeof == 16,"wrong size for cell_t");
      struct cell_fill_t {
        cell_t cell;
      }
    }
    
    static if(pos_t.sizeof == 12){
      struct pos_fill_t {
        pos_t pos;
        float fPadding;
      }
    }
    else {
      static assert(pos_t.sizeof == 16,"wrong size for pos_t");
      struct pos_fill_t {
        pos_t pos;
      }
    }
  }
  
	///constant for the cell size
	enum float cellSize = 1000.0f;
  align(16) static immutable(float[4]) cellSizeVector = [cellSize,cellSize,cellSize,1];
	
	///cell position
	cell_t cell;
  version(USE_SSE){
    float fPadding = 0.0f;
  }
	
	///relativ position inside a cell
	pos_t relPos;
  pos_t oldRelPos;
  version(USE_SSE){
    int iPadding = 0;
  }

  @property Component x()
  {
    return Component(cell.x, relPos.x);
  }

  @property Component y()
  {
    return Component(cell.y, relPos.y);
  }

  @property Component z()
  {
    return Component(cell.z, relPos.z);
  }
	
	/**
	 * constructor
	 * Params:
	 *	cell = cell coordinates
	 *  relPos = relative position to the cell
	 */
	this(cell_t cell, pos_t relPos){
		this.cell = cell;
		this.relPos = relPos;
		
    version(USE_SSE){
      asm {
        mov ECX,this;
        movups XMM0,[ECX+Position.cell.offsetof];
        movups XMM2,[ECX+Position.relPos.offsetof];
        movaps XMM4,[cellSizeVector];
        //handle percision loss
        addps XMM2,XMM4;
        subps XMM2,XMM4;
        //floor(res.relPos / cellSize);
        movaps XMM3,XMM2;
        divps XMM3,XMM4;
        roundps XMM3,XMM3,0x1; //floor
        //res.cell += cast(cell_t)(diff);
		    cvtps2dq XMM5,XMM3; //convert to int
        paddd XMM0,XMM5;
        //res.relPos -= diff * cellSize;
        mulps XMM3,XMM4;
        subps XMM2,XMM3;
        //write result back
        movups [ECX+Position.cell.offsetof],XMM0;
        movups [ECX+Position.relPos.offsetof],XMM2;
      }
    }
    else {
		  //validate
		  pos_t diff  = floor(this.relPos / cellSize);
		  this.cell += cast(cell_t)(diff);
		  this.relPos -= diff * cellSize;
		  diff  = floor(this.relPos / cellSize);
		  this.cell += cast(cell_t)(diff);
		  this.relPos -= diff * cellSize;
    }
	}
	
	/**
	 * constructor (computes cell cordinates automatically)
	 * Params:
	 *	pos = position in the world
	 */
	this(pos_t pos){
    this.relPos = pos;
    
		version(USE_SSE){
      oldRelPos = relPos;
      asm {
        mov ECX,this;
        movups XMM0,[ECX+Position.cell.offsetof];
        movups XMM2,[ECX+Position.relPos.offsetof];
        movaps XMM4,[cellSizeVector];
        //handle percision loss
        addps XMM2,XMM4;
        subps XMM2,XMM4;
        //floor(res.relPos / cellSize);
        movaps XMM3,XMM2;
        divps XMM3,XMM4;
        roundps XMM3,XMM3,0x1; //floor
        //res.cell += cast(cell_t)(diff);
		    cvtps2dq XMM5,XMM3; //convert to int
        paddd XMM0,XMM5;
        //res.relPos -= diff * cellSize;
        mulps XMM3,XMM4;
        subps XMM2,XMM3;
        //write result back
        movups [ECX+Position.cell.offsetof],XMM0;
        movups [ECX+Position.relPos.offsetof],XMM2;
      }
		}
		else {	
			//validate
			pos_t diff  = floor(this.relPos / cellSize);
			this.cell += cast(cell_t)(diff);
			this.relPos -= diff * cellSize;
			diff  = floor(this.relPos / cellSize);
			this.cell += cast(cell_t)(diff);
			this.relPos -= diff * cellSize;
		}
	}
	
	/**
	 * + operator
	 */
	Position opBinary(string op,T)(auto ref T rh) const if(op == "+" && is(StripConst!(T) == pos_t))
		{
      version(USE_SSE){
        (cast(Position)this).oldRelPos = relPos;
        Position res;
        auto pRes = &res;
        pos_fill_t rhf = pos_fill_t(rh,0.0f);
        auto pRh = &rhf;
        asm {
          mov ECX,this;
          mov EDX,pRh;
          mov EAX,pRes;
          movups XMM0,[ECX+Position.cell.offsetof];
          movups XMM2,[ECX+Position.relPos.offsetof];
          movups XMM1,[EDX];
          addps XMM2,XMM1;
          //kill any possible percision loss
          movaps XMM4,[cellSizeVector];
          addps XMM2,XMM4;
          subps XMM2,XMM4;
          //floor(res.relPos / cellSize);
          movaps XMM3,XMM2;
          divps XMM3,XMM4;
          roundps XMM3,XMM3,0x1; //floor
          //res.cell += cast(cell_t)(diff);
		      cvtps2dq XMM5,XMM3; //convert to int
          paddd XMM0,XMM5;
          //res.relPos -= diff * cellSize;
          mulps XMM3,XMM4;
          subps XMM2,XMM3;
          //write result back to res
          movups [EAX+Position.cell.offsetof],XMM0;
          movups [EAX+Position.relPos.offsetof],XMM2;
        }
        return res;
      }
      else {
			  Position res = this;
			  res.relPos += rh;
  			
			  //validate
			  pos_t diff  = floor(res.relPos / cellSize);
			  res.cell += cast(cell_t)(diff);
			  res.relPos -= diff * cellSize;
			  diff  = floor(res.relPos / cellSize);
			  res.cell += cast(cell_t)(diff);
			  res.relPos -= diff * cellSize;
  			
			  return res;
      }
		}
	
	///ditto
	Position opBinaryRight(string op)(pos_t lh) const if(op == "+")
		{
			return this.opBinary("+")(lh);
		}
	
	///ditto
	Position opBinary(string op,T)(auto ref T rh) const if(op == "+" && is(StripConst!(T) == Position))
		{
      version(USE_SSE){
        (cast(Position)this).oldRelPos = relPos;
        Position res;
        Position* pRes = &res;
        T* pRh = &rh;

        asm {
          //auto res = Position(this.cell + rh.cell, this.relPos + rh.relPos);
          mov ECX,this;
          mov EDX,pRh;
          movups XMM0,[ECX+Position.cell.offsetof];
          movups XMM1,[EDX+Position.cell.offsetof];
          movups XMM2,[ECX+Position.relPos.offsetof];
          movups XMM3,[EDX+Position.relPos.offsetof];
          paddd XMM0,XMM1;
          addps XMM2,XMM3;
          //handle percision loss
          movaps XMM1,[cellSizeVector];
          addps XMM2,XMM1;
          subps XMM2,XMM1;
          //floor(res.relPos / cellSize);
          movaps XMM3,XMM2;
          divps XMM3,XMM1; // XMM1 = XMM2 / XMM1;
          roundps XMM3,XMM3,0x1; //floor
          //res.cell += cast(cell_t)(diff);
		      cvtps2dq XMM5,XMM3; //cast to int
          paddd XMM0,XMM5;
          //res.relPos -= diff * cellSize;
          mulps XMM3,XMM1;
          subps XMM2,XMM3;
          //write result back to res
          mov ECX,pRes;
          movups [ECX+Position.cell.offsetof],XMM0;
          movups [ECX+Position.relPos.offsetof],XMM2;
        }
        
        return res;
      }
      else {
        auto res = Position(this.cell + rh.cell, this.relPos + rh.relPos);
      
			  //validate
        //float[] temp = res.relPos.f;
			  pos_t diff  = floor(res.relPos / cellSize);
			  res.cell += cast(cell_t)(diff);
			  res.relPos -= diff * cellSize;
			  /*diff  = floor(res.relPos / cellSize);
			  res.cell += cast(vec3_t!(short))(diff);
			  res.relPos -= diff * cellSize;*/
  			
			  return res;
      }
		}
	
	/**
	 * - operator
	 */
	vec3 opBinary(string op, T)(auto ref T rh) const if(op == "-" && is(StripConst!(T) == Position))
		{
      version(USE_SSE){
        (cast(Position)this).oldRelPos = relPos;
        pos_fill_t res;
        auto pRh = &rh;
        auto pRes = &res;
        float fCellSize = 1000.0f;
        asm {
          mov ECX,this;
          mov EDX,pRh;
          mov EAX,pRes;
          movups XMM0,[ECX+Position.cell.offsetof];
          movups XMM1,[EDX+Position.cell.offsetof];
          movups XMM2,[ECX+Position.relPos.offsetof];
          movups XMM3,[EDX+Position.relPos.offsetof];
          psubd XMM0,XMM1;
          cvtdq2ps XMM0,XMM0;
          movaps XMM1,[cellSizeVector];
          mulps XMM0,XMM1;
          subps XMM2,XMM3;
          addps XMM0,XMM2;
          movups [EAX],XMM0;
        }
        return res.pos;
      }
      else {
			  pos_t res = cast(pos_t)(this.cell - rh.cell) * cellSize;
			  res += this.relPos - rh.relPos;
  			
			  return res;
      }
		}
	
	///ditto
	Position opBinary(string op, T)(T rh) const if(op == "-" && is(StripConst!(T) == pos_t)) 
		{
			return this.opBinary!("+")(-rh);
		}
	
  /**
   * == operator
   */
  bool opEquals(ref const(Position) rh)
  {
    return this.cell == rh.cell && this.relPos == rh.relPos;
  }

	/**
	 * operations which are done on all components
	 */
	bool allComponents(string op)(Position rh) const if(op == "<")
		{
			for(int i=0;i<cell.f.length;i++){
				if(cell.f[i] == rh.cell.f[i]){
					if(!(relPos.f[i] < rh.relPos.f[i]))
						return false;
				}
				else if(!(cell.f[i] < rh.cell.f[i]))
					return false;
			}
			return true;
		}
	
	///ditto
	bool allComponents(string op)(Position rh) const if(op == "<=")
		{
			for(int i=0;i<cell.f.length;i++){
				if(cell.f[i] == rh.cell.f[i]){
					if(!(relPos.f[i] <= rh.relPos.f[i]))
						return false;
				}
				else if(!(cell.f[i] < rh.cell.f[i]))
					return false;
			}
			return true;
		}
	
	///ditto
	bool allComponents(string op)(Position rh) const if(op == ">")
		{
			for(int i=0;i<cell.f.length;i++){
				if(cell.f[i] == rh.cell.f[i]){
					if(!(relPos.f[i] > rh.relPos.f[i]))
						return false;
				}
				else if(!(cell.f[i] > rh.cell.f[i]))
					return false;
			}
			return true;
		}
	
	///ditto
	bool allComponents(string op)(Position rh) const if(op == ">=")
		{
			for(int i=0;i<cell.f.length;i++){
				if(cell.f[i] == rh.cell.f[i]){
					if(!(relPos.f[i] >= rh.relPos.f[i]))
						return false;
				}
				else if(!(cell.f[i] > rh.cell.f[i]))
					return false;
			}
			return true;
		}
	
	/**
	 * this function makes shure that the relative position is correct
	 */
	void validate(){
    version(USE_SSE){
      oldRelPos = relPos;
      asm {
        mov ECX,this;
        movups XMM0,[ECX+Position.cell.offsetof];
        movups XMM2,[ECX+Position.relPos.offsetof];
        movaps XMM4,[cellSizeVector];
        movaps XMM3,XMM2;
        divps XMM3,XMM4;
        roundps XMM3,XMM3,0x1; //floor
        //res.cell += cast(cell_t)(diff);
		    cvtps2dq XMM5,XMM3; //convert to int
        paddd XMM0,XMM5;
        //res.relPos -= diff * cellSize;
        mulps XMM3,XMM4;
        subps XMM2,XMM3;
        //write result back
        movups [ECX+Position.cell.offsetof],XMM0;
        movups [ECX+Position.relPos.offsetof],XMM2;
      }
    }
    else {
		  pos_t diff  = floor(this.relPos / cellSize);
		  this.cell += cast(cell_t)(diff);
		  this.relPos -= diff * cellSize;
		  diff  = floor(this.relPos / cellSize);
		  this.cell += cast(cell_t)(diff);
		  this.relPos -= diff * cellSize;
    }
	}
	
	debug {
		invariant()
		{
			assert(0.0f <= relPos.x && relPos.x < cellSize);
			assert(0.0f <= relPos.y && relPos.y < cellSize);
			assert(0.0f <= relPos.z && relPos.z < cellSize);
		}
	}
	
	bool isValid() const {
		return ((0.0f <= relPos.x && relPos.x < cellSize) &&
			    (0.0f <= relPos.y && relPos.y < cellSize) &&
			    (0.0f <= relPos.z && relPos.z < cellSize));
	}
	
	vec3 toVec3() const {
		return vec3(cell.x*cellSize,cell.y*cellSize,cell.z*cellSize) + relPos;
	}
	
	to_string_t toString(){
		return format("<Position %s (cell: %s, relPos: %s)>", toVec3().f, cell.f, relPos.f);
	}
}

unittest {
	Position p1 = Position(Position.pos_t(250.0f,250.0f,250.0f));
	Position res1 = Position(Position.cell_t(-1,-1,-1),Position.pos_t(750.0f,750.0f,750.0f));
	Position temp1 = p1 - Position.pos_t(500.0f,500.0f,500.0f);
	assert(temp1 == res1);
	
	Position p2 = Position(Position.cell_t(1,1,1),Position.pos_t(0,0,0));
	Position.pos_t temp2 = p1 - p2;
	assert(temp2 == Position.pos_t(-750.0f,-750.0f,-750.0f));
	
	Position p3 = Position(Position.cell_t(-1,-1,-1),Position.pos_t(0,0,0));
	Position.pos_t temp3 = p3 - p2;
	assert(temp3 == Position.pos_t(-2000.0f,-2000.0f,-2000.0f));
	
	Position res4 = Position(Position.pos_t(0,0,0));
	Position temp4 = p2 - Position.pos_t(1000.0f,1000.0f,1000.0f);
	assert(res4 == temp4);

  Position p4 = Position(Position.pos_t(3250.0f,-3250.0f,1000.0f));
  assert(p4.cell.x == 3);
  assert(p4.cell.y == -4);
  assert(p4.cell.z == 1);
  assert(p4.relPos.x == 250.0f);
  assert(p4.relPos.y == 750.0f);
  assert(p4.relPos.z == 0.0f);

  //float accuracy tests
  Position p5 = Position(Position.pos_t(0,0,0));
  p5 = p5 - Position.pos_t(float.epsilon, float.epsilon, float.epsilon);
  assert(p5.isValid());

  Position minDelta = Position(Position.pos_t(-float.epsilon, -float.epsilon, -float.epsilon));

  Position p6 = Position(Position.pos_t(0,0,0));
  p6 = p6 + minDelta;
  assert(p6.isValid());
}
