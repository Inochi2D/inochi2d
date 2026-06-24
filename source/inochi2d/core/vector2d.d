/**
    Multi-dimensional vector.

    Copyright © 2026, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors:
        Luna Nielsen
        Mireille Arseneault
*/
module inochi2d.core.vector2d;
import numem;

public import inochi2d.core.slice2d;

/**
    A contiguous 2D vector.

    The data is stored row-major.
*/
struct vector2d(T) {
private:
@nogc:
    T[] _data = null;
    size_t _rows = 0;
    size_t _columns = 0;

public:
    /**
        Pointer to the start of the data.
    */
    @property inout(T)* ptr() inout => _data.ptr;

    /**
        Total length of this vector's memory block.
    */
    @property size_t length() const => _data.length;

    /**
        Slice to the underlying memory block.
    */
    @property inout(T)[] data() inout => _data[];

    /**
        The number of rows in this vector.
    */
    @property size_t rows() const => _rows;

    /**
        The number of columns in this vector.
    */
    @property size_t columns() const => _columns;

    /**
        Construct a new vector of the given size.

        Params:
            rows =      The number of rows in the vector.
            columns =   The number of columns in the vector.
    */
    this(size_t rows, size_t columns) {
        resize(rows, columns);
    }

    /**
        Copy-construct a new vector.
        
        Params:
            other =     The vector to copy during construction.
    */
    this(ref return scope inout vector2d other) {
        _data = cast(T[])other._data.nu_dup;
        _rows = other._rows;
        _columns = other._columns;
    }

    /**
        Move-construct a new vector.
        
        Params:
            other =     The vector to move during construction.
    */
    this(return scope vector2d other) {
        _data = other._data;
        _rows = other._rows;
        _columns = other._columns;

        other._data = null;
        other._rows = 0;
        other._columns = 0;
    }

    ~this() {
        nu_freea(_data);
    }

    /**
        Resize this 2D vector.

        Params:
            rows =  The new row size of this vector.
            cols =  The new column size of this vector.
    */
    void resize(size_t rows, size_t cols) {

        // NOTE:    When resizing from empty to non-empty, we can skip the
        //          other steps.
        if ((_rows == 0 || _columns == 0) && (rows > 0 && cols > 0)) {
            this._rows = rows;
            this._columns = cols;
            this._data = nu_malloca!T(_rows*_columns);
            return;
        }

        // Get which row/column pair is the smallest, then use that
        // for copying data over to the new array.
        size_t mRows = nu_min(cast(size_t)_rows, cast(size_t)rows);
        size_t mCols = nu_min(cast(size_t)_columns, cast(size_t)cols);

        auto oldData = _data;
        auto newData = nu_malloca!T(rows*cols);
        foreach(x; 0..mRows) {
            foreach(y; 0..mCols) {
                newData[(rows*y)+x] = oldData[(_rows*y)+x];
            }
        }

        this._rows = rows;
        this._columns = cols;
        this._data = newData;
        nu_freea(oldData);
    }

    /**
        Clear the contents of the vector.
    */
    void clear() {
        _rows = 0;
        _columns = 0;
        nu_freea(_data);
        _data = null;
    }

    /**
        Index this vector.

        Params:
            row =       The row to index.
            column =    The column to index.

        Returns:
            The item at the given row and column index.
    */
    ref inout(T) opIndex(size_t row, size_t column) inout {
        assert(row <= _rows, "Row index outside bounds of vector.");
        assert(column <= _columns, "Column index outside bounds of vector.");
        return _data[(_columns * row) + column];
    }

    /**
        Index this vector.

        Params:
            row =       The row to index.
            columns =   The columns to index.

        Returns:
            The slice of items at the given row/column span.
    */
    slice2d!T opIndex(size_t row, size_t[2] columns) {
        const a = (_columns * row) + columns[0];
        const b = (_columns * (row + 1)) + columns[1];
        return slice2d!T(_data[a .. b], _columns, 1, columns[1] - columns[0]);
    }

    /**
        Index this vector.

        Params:
            rows =      The rows to index.
            column =    The column to index.

        Returns:
            The slice of items at the given row/column span.
    */
    slice2d!T opIndex(size_t[2] rows, size_t column) {
        const a = (_columns * rows[0]) + column;
        const b = (_columns * rows[1]) + column + 1;
        return slice2d!T(_data[a .. b], _columns, rows[1] - rows[0], 1);
    }

    /**
        Index this vector.

        Params:
            rows =      The rows to index.
            columns =   The columns to index.

        Returns:
            The slice of items at the given row/column span.
    */
    slice2d!T opIndex(size_t[2] rows, size_t[2] columns) {
        const a = (_columns * rows[0]) + columns[0];
        const b = (_columns * rows[1]) + columns[1];
        return slice2d!T(_data[a .. b], _columns, rows[1] - rows[0], columns[1] - columns[0]);
    }

    /**
        Slices this vector.

        Returns:
            The slice of the entire contents of this vector.
    */
    slice2d!T opIndex() {
        return slice2d!T(_data, _columns, _rows, _columns);
    }

    /**
        Assign to the value at the given index.
    */
    auto opIndexAssign(T value, size_t row, size_t column) {
        assert(row <= _rows, "Row index outside bounds of array.");
        assert(column <= _columns, "Column index outside bounds of array.");
        return _data[(_columns * row) + column] = value;
    }

    /**
        Mass-assign to the values at the given span.
    */
    auto opIndexAssign(T value, size_t row, size_t[2] columns) {
        auto slice = this[row, columns];
        return slice[] = value;
    }

    /**
        Mass-assign to the values at the given span.
    */
    auto opIndexAssign(T value, size_t[2] rows, size_t column) {
        auto slice = this[rows, column];
        return slice[] = value;
    }

    /**
        Mass-assign to the values at the given span.
    */
    auto opIndexAssign(T value, size_t[2] rows, size_t[2] columns) {
        auto slice = this[rows, columns];
        return slice[] = value;
    }

    /**
        Mass-assign to all values in this vector.
    */
    auto opIndexAssign(T value) {
        _data[] = value;
        return value;
    }

    /**
        Mass-assign a slice to all values of this vector
    */
    auto opIndexAssign(slice2d!T value) {
        auto slice = this[];
        return slice[] = value;
    }

    /**
        Mass-assign a slice to a region of this vector.
    */
    auto opIndexAssign(slice2d!T value, size_t row, size_t[2] columns) {
        auto slice = this[row, columns];
        return slice[] = value;
    }

    /**
        Mass-assign a slice to a region of this vector.
    */
    auto opIndexAssign(slice2d!T value, size_t[2] rows, size_t column) {
        auto slice = this[rows, column];
        return slice[] = value;
    }

    /**
        Mass-assign a slice to a region of this vector.
    */
    auto opIndexAssign(slice2d!T value, size_t[2] rows, size_t[2] columns) {
        auto slice = this[rows, columns];
        return slice[] = value;
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
        assert(a <= b, "Slice bounds given in the wrong order");
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
        assert(a <= b, "Slice bounds given in the wrong order");
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

@("vector2d")
unittest {
    vector2d!int ints;
    ints.resize(4, 4);
    ints[2, 2] = 24;

    ints.resize(8, 8);
    assert(ints[2, 2] == 24);
}