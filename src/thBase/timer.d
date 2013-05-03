module thBase.timer;

version(Windows){
	import std.c.windows.windows;
}
version(linux){
	import core.sys.posix.time;
}

/**
 * a very percicse hardware timer
 */
shared class Timer {
private:
	ulong m_Start;
	version(Windows){
		double m_Resolution;
		ulong m_Frequency;	
	}
	
public:
	/**
	 * constructor
	 */
	this()
	{
		version(Windows){
			if(!QueryPerformanceFrequency(cast(long*)&m_Frequency)){
				throw new Exception("No performance timer available");
			}
			QueryPerformanceCounter(cast(long*)&m_Start);
			m_Resolution = 1.0 / cast(double)m_Frequency;	
		}
		version(linux){
			m_Start = getCurrentTime();
		}
	}
	
	/**
	 * Get elapsed time as float,
	 * might lose percision over time
	 */
	float GetTimeFloat()
	{
		version(Windows){
			ulong Time;
			QueryPerformanceCounter(cast(long*)&Time);
			return cast(float)(Time - m_Start) * cast(float)m_Resolution * 1000.0f;
		}
		version(linux){
			ulong TimeDiff = getCurrentTime();
			return cast(float)((TimeDiff - m_Start) / 1_000.0);
		}
	}
	
	/** 
	 * Get elapsed time as double
	 * might lose percision over time
	 */
	double GetTimeDouble(){
		version(Windows){
			ulong Time;
			QueryPerformanceCounter(cast(long*)&Time);
			return cast(double)(Time - m_Start) * m_Resolution * 1000.0;
		}
		version(linux){
			ulong TimeDiff = getCurrentTime();
			return cast(double)((TimeDiff - m_Start) / 1_000.0);
		}	
	}
	
	/**
	 * Gets time as 64 bit int, does not loose percision
	 */
	ulong GetTime()
	{
		ulong TimeDiff;
		version(Windows){
			QueryPerformanceCounter(cast(long*)&TimeDiff);
		}
		version(linux){
			TimeDiff = getCurrentTime();
		}
		return TimeDiff - m_Start;
	}
	
	version(Windows){
		double GetResolution(){ return m_Resolution; }
	}
	
	version(linux){
		/**
		 * Returns the current real time in micro seconds.
		 */
		ulong getCurrentTime(){
			timespec Time;
			clock_gettime(CLOCK_REALTIME, &Time);
			return cast(ulong)(Time.tv_nsec / 1_000L) + cast(ulong)(Time.tv_sec * 1_000_000L);
		}
	}
	
	/**
	 * Returns the start time of the timer in milliseconds. Doesn't make much sens
	 * in itself but is useful for a best effort synchronization between different
	 * networked clocks. Effectively the start time of all clients is set to the
	 * same value.
	 */
	ulong getStartTime()
	{
		version(Windows)
			return m_Start * 1000 / m_Frequency;
		version(linux)
			return m_Start / 1_000;
	}
	
	/**
	 * Sets the start time of this clock to the specified time. Expects the time
	 * in milliseconds and converts it to a internal representation if necessary.
	 */
	void setStartTime(ulong start){
		version(Windows)
			m_Start = start / 1000 * m_Frequency;
		version(linux)
			m_Start = start * 1_000;
	}
};

/**
 * Represents a point in time, usually the time of its creation
 */
struct Zeitpunkt {
private:
	shared(Timer) m_Timer;
	ulong m_Time;
public:
	/**
	 * constructor
	 * Params:
	 *  timer = the timer to be used for getting the current time
	 */
	this(shared(Timer) timer){
		assert(timer !is null);
		m_Timer = timer;
		m_Time = timer.GetTime();
	}

  /**
   * Returns if this zeitpunkt instance is valid or not
   */
  bool isValid()
  {
    return m_Timer !is null;
  }
	
	/**
     * Returns: the difference in milliseconds between to points in time
     * Params:
     *  z = other point in time (has to use same timer)
     */
	double opSub(const ref Zeitpunkt z){
		version(Windows){
			double Resolution = m_Timer.GetResolution();
			return cast(double)(m_Time - z.m_Time) * Resolution * 1000.0;
		}
		version(linux){
			return cast(double)((m_Time - z.m_Time) / 1_000.0);
		}
	}
	
	int opCmp(ref const(Zeitpunkt) z) const {
		return cast(int)(m_Time - z.m_Time);
	}
	
	bool opEquals(ref const(Zeitpunkt) z) const {
		return m_Time == z.m_Time;
	}
	
	/**
	 * Returns the numer of milliseconds elapsed since the start of the timer.
	 */
	ulong getMilliseconds(){
		version(Windows){
			return m_Time * 1000 / m_Timer.m_Frequency;
		}
		version(linux){
			return m_Time / 1_000;
		}
	}
	
	/**
	 * Returns the number of milliseconds elapsed since the start of the timer but
	 * checks that this Zeitpunkt uses the specified timer. Otherwise an exception
	 * is thrown.
	 * 
	 * Used by the netcode to get a timer independent time representation.
	 */
	ulong getMilliseconds(shared(Timer) usedTimer){
		assert(m_Timer is usedTimer, "Tried to get milliseconds of a Zeitpunkt with another timer");
		return getMilliseconds();
	}
	
	/**
	 * Sets the milliseconds elapsed since timer start and checks that the
	 * specified timer is used.
	 * 
	 * Used by the netcode to update the value in a timer independent way.
	 */
	void setMilliseconds(ulong time, shared(Timer) usedTimer){
		assert(m_Timer is usedTimer, "Tried to set milliseconds of a Zeitpunkt with another timer");
		version(Windows){
			m_Time = time * m_Timer.m_Frequency / 1000;
		}
		version(linux){
			m_Time = time * 1_000;
		}
	}
};
