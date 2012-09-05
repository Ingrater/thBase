module thBase.serialize.wrapper;

/**
 * XmlWrapper type for a nicer xml output
 */
struct XmlValue(T){
	T value;
	
	/**
	 * constructor
	 * Params:
	 *  value = value to store
	 */
	this(T value){
		this.value = value;
	}
}