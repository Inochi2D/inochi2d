/**
    Memory Pools

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.core.memory.pool;
import inochi2d;
import numem.core.hooks;
import numem.core.math;
import numem;

/**
	A frame pool.

	Frame pools allow reuse of memory that changes frequently, eg. every frame.

	Frame pools are grown by a given "page" size if additions to the pool go beyond
	the current allocation of the pool.
*/
struct FramePool {
private:
@nogc:
	void[] memory_;
	size_t pageSize_ = 4096;
	size_t generation_ = 0;
	size_t i = 0;

public:

	/**
		The current generation of the frame pool.
	*/
	@property size_t generation() => generation_;

	/// Destructor
	~this() {
		this.free();
	}

	/**
		Initializes a new memory pool.

		Params:
			pageSize = The amount of bytes the pool grows by. (minimum 4096)
	*/
	this(size_t pageSize) @trusted nothrow {
		this.pageSize_ = nu_min(4096, pageSize);
		this.memory_ = nu_malloc(pageSize)[0..pageSize];
	}

	/**
		Begins the next frame/generation.

		Note:
			This will render all current pool tokens invalid.
	*/
	void next() {
		this.i = 0;
		this.generation_++;
	}

	/**
		Frees the pool.

		Note:
			This makes the pool invalid, if you desire a fresh 
			pool instantiate a new one with the constructor.
	*/
	void free() {
		nu_free(memory_.ptr);
		this.memory_ = null;
		this.generation_ = size_t.max;
	}

	/**
		Allocates memory from the pool for the given amount of elements.

		Params:
			count = How many elements to allocate from the pool.

		Returns:
			A slice of the allocated memory.
	*/
	PoolToken!T allocate(T)(size_t count) @trusted nothrow {
		if (count == 0)
			return typeof(return).init;

		size_t si = i;
		size_t toalloc = (T.sizeof*count);

		// Grow memory if needed.
		if (i + toalloc > memory_.length) {
			size_t newsz = nu_alignup(memory_.length+toalloc, pageSize_);
			this.memory_ = nu_realloc(memory_.ptr, newsz)[0..newsz];
		}

		i += toalloc;
		return PoolToken!T(
			pool: &this,
			generation_: generation_,
			offset: si,
			length: toalloc
		);
	}
}

/**
	A token that represents an allocation within a frame pool.
*/
struct PoolToken(T) {
private:
@nogc:
	FramePool* pool;
	size_t generation_;
	size_t offset;
	size_t length;

public:
	alias value this;

	/**
		Whether the token is still valid.
	*/
	@property bool isValid() @trusted nothrow pure => (pool !is null) && (this.generation_ == pool.generation_);

	/**
		The value of the token.
	*/
	@property T[] value() @trusted nothrow {
		return isValid ?
			cast(T[])pool.memory_[offset..offset+length] :
			null;
	}
}

@("FramePool: allocate")
unittest {
	FramePool pool = FramePool(4096);
	auto token = pool.allocate!float(32);

	token[0..32] = 100f;
	foreach(i; 0..32)
		assert(token[i] == 100f);
}

@("FramePool: generations")
unittest {
	FramePool pool = FramePool(4096);
	auto token = pool.allocate!float(32);
	pool.next();
	assert(!token.isValid);
}