/**
    Inochi2D Range Primitives

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
        Hoshino Lina
*/
module inochi2d.core.math.range;
import nulib.math;
import numem;

/**
    A range of values.
*/
struct Range(T) {
public:
@nogc:
    union {
        struct {
            T min;
            T max;
        }
        T[2] values;
    }

    /**
        Pair-wise distance between the minimum and maximum values.
    */
    @property T distance() => max - min;
}