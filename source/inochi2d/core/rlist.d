/**
    Range based lists

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inochi2d.core.rlist;
import inochi2d.core.mrange;
import inochi2d.core.math.range;
import numem.core.traits;
import numem.core.meta;
import nulib;

/**
    A range based list.
*/
struct RList(T, uint N) {
private:
@nogc:
    RangeMap!N map_;
    ndarray!(T, N) data_;

public:

    /**
        Type sequence consisting of N amounts of indices.
    */
    alias IndexArgs = AliasSeq!(typeof(size_t[N].init.tupleof));

    /**
        Type sequence consisting of N amounts of indices.
    */
    alias FloatArgs = AliasSeq!(typeof((float[N]).init.tupleof));

    /**
        Gets the minimum values for each axis.
    */
    @property float[] minimums() @trusted pure nothrow => map_.minimums;

    /**
        Gets the maximum values for each axis.
    */
    @property float[] maximums() @trusted pure nothrow => map_.maximums;

    /**
        Underlying linear data of the list.
    */
    @property ref auto data() => data_;

    /// Destructor
    ~this() {
        data_.clear();
    }

    /**
        Sets up the RList with the given stops.

        Params:
            stops = The stops for each axis.
    */
    void setup(float[][N] stops) {
        Range!float[N] ranges;
        float[][N] rstops;
        IndexArgs lengths;
        static foreach(d; 0..N) {
            ranges[d] = Range!float(stops[d][0], stops[d][$-1]);
            rstops[d] = stops[d][1..$-1];
            lengths[d] = stops[d].length;
        }
        map_ = RangeMap!N(ranges, rstops);
        data_.resize(lengths);
    }

    /**
        Gets whether a stop is defined for 
        the given location.

        Params:
            dim =   The dimension to look for the stop.
            t =     The location to look for.

        Returns:
            $(D true) if the stop was found,
            $(D false) otherwise.
    */
    bool hasStop(uint dim, float t) {
        return map_.findBreakpoint(dim, t) != -1;
    }

    /**
        Adds a new stop to the list.

        Params:
            dim =   The dimension to at the stop at.
            t =     The location to add the stop.
    */
    void addStop(uint dim, float t) {
        ptrdiff_t idx = map_.insertBreakpoint(dim, t);
        if (idx >= 0) {
            auto lengths = data_.length;
            lengths[dim]++;
            data_.resize(lengths.tupleof);

            // TODO: Shuffle data around to create the empty spaces in the area.
        }
    }

    /**
        Sets the value range for a given dimension.

        Params:
            dim =   The dimension to set the range for.
            range = The range to set.
    */
    void setRange(uint dim, Range!float range) nothrow {
        map_.setRange(dim, range);
    }

    /**
        Gets the range for a given dimension

        Params:
            dim =   The dimension to get the range for.

        Returns:
            The range for the given dimension.
    */
    Range!float getRange(uint dim) nothrow {
        return map_.getRange(dim);
    }

    /**
        Gets the value at the given coordinates.

        Params:
            args = The coordinates to get.
    */
    T get(FloatArgs args) {
        IndexArgs indices;
        static foreach(d; 0..N)
            indices[d] = map_.getBreakpoints(d, args[d]).closest.index;
        return data_[indices];
    }

    /**
        Gets the breakpoints at the given dimension and coordinate.

        Params:
            dim =   The dimension to get the breakpoints for.
            t =     The coordinate.
    */
    Breakpoints getBreakpoints(uint dim, float t) {
        return map_.getBreakpoints(dim, t);
    }

    /**
        Sets the value at the given coordinates.

        Params:
            args = The coordinates to get.
            value = The value to set.
    */
    void set(FloatArgs args, T value) {
        IndexArgs indices;
        static foreach(d; 0..N)
            indices[d] = map_.getBreakpoints(d, args[d]).closest.index;
        data_[indices] = value;
    }
}
alias RList1D(T) = RList!(T, 1);
alias RList2D(T) = RList!(T, 2);