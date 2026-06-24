/**
    Multi-dimensional slices.

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors:
        Luna Nielsen
        Mireille Arseneault
*/
module inochi2d.core.slice2d;
import numem;

/**
    A contiguous 2D slice.

    The data is stored row-major.
*/
struct slice2d(T) {
private:
@nogc:
    T[] data = null;
    size_t stride = 0;
    size_t _rows = 0;
    size_t _columns = 0;

public:
    /**
        The number of rows in this slice.
    */
    @property size_t rows() const => _rows;

    /**
        The number of columns in this slice.
    */
    @property size_t columns() const => _columns;

    /**
        Construct a new slice of the given data with the given size.

        Params:
            data    = The data of this slice.
            stride  = The data stride of this slice.
            rows    = The number of rows in the slice.
            columns = The number of columns in the slice.
    */
    this(T[] data, size_t stride, size_t rows, size_t columns) {
        this.data = data;
        this.stride = stride;
        _rows = rows;
        _columns = columns;
    }

    /**
        Index this slice.

        Params:
            row =       The row to index.
            column =    The column to index.

        Returns:
            The item at the given row and column index.
    */
    ref T opIndex(size_t row, size_t column) {
        assert(row <= _rows, "Row index outside bounds of array.");
        assert(column <= _columns, "Column index outside bounds of array.");
        return data[(stride * row) + column];
    }

    slice2d!T opIndex(size_t row, size_t[2] columns) {
        const a = (stride * row) + columns[0];
        const b = (stride * (row + 1)) + columns[1];
        return slice2d!T(data[a .. b], stride, 1, columns[1] - columns[0]);
    }

    slice2d!T opIndex(size_t[2] rows, size_t column) {
        const a = (stride * rows[0]) + column;
        const b = (stride * rows[1]) + column + 1;
        return slice2d!T(data[a .. b], stride, rows[1] - rows[0], 1);
    }

    slice2d!T opIndex(size_t[2] rows, size_t[2] columns) {
        const a = (stride * rows[0]) + columns[0];
        const b = (stride * rows[1]) + columns[1];
        return slice2d!T(data[a .. b], stride, rows[1] - rows[0], columns[1] - columns[0]);
    }

    slice2d!T opIndex() {
        return slice2d!T(data, stride, _rows, _columns);
    }

    auto opIndexAssign(T value) {
        foreach (row; 0 .. _rows) {
            auto dest = &data.ptr[row * stride];
            dest[0 .. _columns] = value;
        }
        return value;
    }

    auto opIndexAssign(T value, size_t row, size_t column) {
        assert(row <= _rows, "Row index outside bounds of array.");
        assert(column <= _columns, "Column index outside bounds of array.");
        return data[(stride * row) + column] = value;
    }

    auto opIndexAssign(slice2d!T value) {
        assert(_rows == value._rows);
        assert(_columns == value._columns);
        foreach (row; 0 .. _rows) {
            auto dest = &data.ptr[row * stride];
            auto src = &value.data.ptr[row * value.stride];
            dest[0 .. _columns] = src[0 .. _columns];
        }
        return value;
    }

    auto opIndexAssign(slice2d!T value, size_t[2] rows, size_t[2] columns) {
        auto slice = this[rows, columns];
        return slice = value;
    }

    /**
        Obtain a pair of indices describing a span of rows.

        Params:
            a = The lower bound.
            b = The upper bound.

        Returns:
            A "tuple" of our bounds.
    */
    size_t[2] opSlice(size_t dim: 0)(size_t a, size_t b) const {
        return [a, b];
    }

    /**
        Obtain a pair of indices describing a span of columns.

        Params:
            a = The lower bound.
            b = The upper bound.

        Returns:
            A "tuple" of our bounds.
    */
    size_t[2] opSlice(size_t dim: 1)(size_t a, size_t b) const {
        return [a, b];
    }

    /**
        Obtain the number of rows in this vector using the dollar operator.

        Returns:
            The number of rows in this vector.
    */
    size_t opDollar(size_t dim : 0)() const {
        return _rows;
    }

    /**
        Obtain the number of columns in this vector using the dollar operator.

        Returns:
            The number of columns in this vector.
    */
    size_t opDollar(size_t dim : 1)() const {
        return _columns;
    }
}