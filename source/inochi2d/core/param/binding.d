/*
    Copyright © 2022, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors:
    - Luna Nielsen
    - Asahi Lina
*/
module inochi2d.core.param.binding;
import inochi2d.fmt.serialize;
import inochi2d.math.serialization;
import inochi2d.core;
import inochi2d.math;
import std.exception;
import std.array;
import std.algorithm.mutation;
import std.stdio;

/**
    A target to bind to
*/
struct BindTarget {
    /**
        The node to bind to
    */
    Node node;

    /**
        The parameter to bind
    */
    string paramName;
}

/**
    A binding to a parameter, of a given value type
*/
abstract class ParameterBinding {

    /**
        Finalize loading of parameter
    */
    abstract void finalize(Puppet puppet);

    /**
        Apply a binding to the model at the given parameter value
    */
    abstract void apply(vec2u leftKeypoint, vec2 offset);

    /**
        Clear all keypoint data
    */
    abstract void clear();

    /**
        Update keypoint interpolation
    */
    abstract void reInterpolate();

    /**
        Returns isSet
    */
    abstract ref bool[][] getIsSet();

    /**
        Gets how many breakpoints this binding is set to
    */
    abstract uint getSetCount();

    /**
        Add a keypoint
    */
    abstract void moveKeypoints(uint axis, uint oldindex, uint index);

    /**
        Add a keypoint
    */
    abstract void insertKeypoints(uint axis, uint index);

    /**
        Remove a keypoint
    */
    abstract void deleteKeypoints(uint axis, uint index);

    /**
        Gets name of binding
    */
    abstract string getName();

    /**
        Gets the node of the binding
    */
    abstract Node getNode();
    
    /**
        Serialize
    */
    void serializeSelf(ref InochiSerializerCompact serializer);

    /**
        Serialize
    */
    void serializeSelf(ref InochiSerializer serializer);

    /**
        Deserialize
    */
    SerdeException deserializeFromAsdf(Asdf data);
}

/**
    A binding to a parameter, of a given value type
*/
abstract class ParameterBindingImpl(T) : ParameterBinding {
private:
    /**
        Node reference (for deserialization)
    */
    uint nodeRef;

public:
    /**
        Parent Parameter owning this binding
    */
    Parameter parameter;

    /**
        Reference to what parameter we're binding to
    */
    BindTarget target;

    /**
        The value at each 2D keypoint
    */
    T[][] values;

    /**
        Whether the value at each 2D keypoint is user-set
    */
    bool[][] isSet;

    /**
        Gets name of binding
    */
    override
    string getName() {
        return target.paramName;
    }

    /**
        Gets the node of the binding
    */
    override
    Node getNode() {
        return target.node;
    }

    /**
        Returns isSet
    */
    override
    ref bool[][] getIsSet() {
        return isSet;
    }

    /**
        Gets how many breakpoints this binding is set to
    */
    override
    uint getSetCount() {
        uint count = 0;
        foreach(x; 0..isSet.length) {
            foreach(y; 0..isSet[x].length) {
                if (isSet[x][y]) count++;
            }
        }
        return count;
    }

    this(Parameter parameter) {
        this.parameter = parameter;
    }

    this(Parameter parameter, Node targetNode, string paramName) {
        this.parameter = parameter;
        this.target.node = targetNode;
        this.target.paramName = paramName;

        clear();
    }

    /**
        Serializes a binding
    */
    override
    void serializeSelf(ref InochiSerializer serializer) {
        auto state = serializer.objectBegin();
            serializer.putKey("node");
            serializer.putValue(target.node.uuid);
            serializer.putKey("param_name");
            serializer.putValue(target.paramName);
            serializer.putKey("values");
            serializer.serializeValue(values);
            serializer.putKey("isSet");
            serializer.serializeValue(isSet);
        serializer.objectEnd(state);
    }

    /**
        Serializes a binding
    */
    override
    void serializeSelf(ref InochiSerializerCompact serializer) {
        auto state = serializer.objectBegin();
            serializer.putKey("node");
            serializer.putValue(target.node.uuid);
            serializer.putKey("param_name");
            serializer.putValue(target.paramName);
            serializer.putKey("values");
            serializer.serializeValue(values);
            serializer.putKey("isSet");
            serializer.serializeValue(isSet);
        serializer.objectEnd(state);
    }

    /**
        Deserializes a binding
    */
    override
    SerdeException deserializeFromAsdf(Asdf data) {
        data["node"].deserializeValue(this.nodeRef);
        data["param_name"].deserializeValue(this.target.paramName);
        data["values"].deserializeValue(this.values);
        data["isSet"].deserializeValue(this.isSet);

        uint xCount = parameter.axisPointCount(0);
        uint yCount = parameter.axisPointCount(1);

        enforce(this.values.length == xCount, "Mismatched X value count");
        foreach(i; this.values) {
            enforce(i.length == yCount, "Mismatched Y value count");
        }

        enforce(this.isSet.length == xCount, "Mismatched X isSet count");
        foreach(i; this.isSet) {
            enforce(i.length == yCount, "Mismatched Y isSet count");
        }

        return null;
    }

    /**
        Finalize loading of parameter
    */
    override
    void finalize(Puppet puppet) {
        this.target.node = puppet.find(nodeRef);
    }

    /**
        Clear all keypoint data
    */
    override
    void clear() {
        uint xCount = parameter.axisPointCount(0);
        uint yCount = parameter.axisPointCount(1);

        values.length = xCount;
        isSet.length = xCount;
        foreach(x; 0..xCount) {
            isSet[x].length = 0;
            isSet[x].length = yCount;

            values[x].length = yCount;
            foreach(y; 0..yCount) {
                clearValue(values[x][y]);
            }
        }
    }

    void clearValue(ref T i) {
        // Default: no-op
    }

    /**
        Gets the value at the specified point
    */
    ref T getValue(vec2u point) {
        return values[point.x][point.y];
    }

    /**
        Sets value at specified keypoint
    */
    void setValue(vec2u point, T value) {
        values[point.x][point.y] = value;
        isSet[point.x][point.y] = true;
        
        reInterpolate();
    }

    /**
        Sets value at specified keypoint
    */
    void unset(vec2u point) {
        clearValue(values[point.x][point.y]);
        isSet[point.x][point.y] = false;

        reInterpolate();
    }

    /**
        Re-calculate interpolation
    */
    override
    void reInterpolate() {
        uint xCount = parameter.axisPointCount(0);
        uint yCount = parameter.axisPointCount(1);

        // Currently valid points
        bool[][] valid;
        uint validCount = 0;
        uint totalCount = xCount * yCount;

        // Initialize validity map to user-set points
        foreach(x; 0..xCount) {
            valid ~= isSet[x].dup;
            foreach(y; 0..yCount) {
                if (isSet[x][y]) validCount++;
            }
        }

        // If there are zero valid points, just clear ourselves
        if (validCount == 0) {
            clear();
            return;
        }

        // Whether any given point was just set
        bool[][] newlySet;
        newlySet.length = xCount;

        // List of indices to commit
        vec2u[] commitPoints;

        // Used by extendAndIntersect for x/y factor
        float[][] interpDistance;
        interpDistance.length = xCount;
        foreach(x; 0..xCount) {
            interpDistance[x].length = yCount;
        }

        // Current interpolation axis
        bool yMajor = false;

        // Helpers to handle interpolation across both axes more easily
        uint majorCnt() {
            if (yMajor) return yCount;
            else return xCount;
        }
        uint minorCnt() {
            if (yMajor) return xCount;
            else return yCount;
        }
        bool isValid(uint maj, uint min) {
            if (yMajor) return valid[min][maj];
            else return valid[maj][min];
        }
        bool isNewlySet(uint maj, uint min) {
            if (yMajor) return newlySet[min][maj];
            else return newlySet[maj][min];
        }
        T get(uint maj, uint min) {
            if (yMajor) return values[min][maj];
            else return values[maj][min];
        }
        float getDistance(uint maj, uint min) {
            if (yMajor) return interpDistance[min][maj];
            else return interpDistance[maj][min];
        }
        void reset(uint maj, uint min, T val, float distance = 0) {
            if (yMajor) {
                //debug writefln("set (%d, %d) -> %s", min, maj, val);
                assert(!valid[min][maj]);
                values[min][maj] = val;
                interpDistance[min][maj] = distance;
                newlySet[min][maj] = true;
            } else {
                //debug writefln("set (%d, %d) -> %s", maj, min, val);
                assert(!valid[maj][min]);
                values[maj][min] = val;
                interpDistance[maj][min] = distance;
                newlySet[maj][min] = true;
            }
        }
        void set(uint maj, uint min, T val, float distance = 0) {
            reset(maj, min, val, distance);
            if (yMajor) commitPoints ~= vec2u(min, maj);
            else commitPoints ~= vec2u(maj, min);
        }
        float axisPoint(uint idx) {
            if (yMajor) return parameter.axisPoints[0][idx];
            else return parameter.axisPoints[1][idx];
        }
        T interp(uint maj, uint left, uint mid, uint right) {
            float leftOff = axisPoint(left);
            float midOff = axisPoint(mid);
            float rightOff = axisPoint(right);
            float off = (midOff - leftOff) / (rightOff - leftOff);

            //writefln("interp %d %d %d %d -> %f %f %f %f", maj, left, mid, right,
            //leftOff, midOff, rightOff, off);
            return get(maj, left) * (1 - off) + get(maj, right) * off;
        }

        void interpolate1D2D(bool secondPass) {
            yMajor = secondPass;
            bool detectedIntersections = false;

            foreach(i; 0..majorCnt()) {
                uint l = 0;
                uint cnt = minorCnt();

                // Find first element set
                for(; l < cnt && !isValid(i, l); l++) {}

                // Empty row, we're done
                if (l >= cnt) continue;

                while (true) {
                    // Advance until before a missing element
                    for(; l < cnt - 1 && isValid(i, l + 1); l++) {}

                    // Reached right side, done
                    if (l >= (cnt - 1)) break;

                    // Find next set element
                    uint r = l + 1;
                    for(; r < cnt && !isValid(i, r); r++) {}

                    // If we ran off the edge, we're done
                    if (r >= cnt) break;

                    // Interpolate between the pair of valid elements
                    foreach (m; (l + 1)..r) {
                        T val = interp(i, l, m, r);

                        // If we're running the second stage of intersecting 1D interpolation
                        if (secondPass && isNewlySet(i, m)) {
                            // Found an intersection, do not commit the previous points
                            if (!detectedIntersections) {
                                //debug writefln("Intersection at %d, %d", i, m);
                                commitPoints.length = 0;
                            }
                            // Average out the point at the intersection
                            set(i, m, (val + get(i, m)) * 0.5f);
                            // From now on we're only computing intersection points
                            detectedIntersections = true;
                        }
                        // If we've found no intersections so far, continue with normal
                        // 1D interpolation.
                        if (!detectedIntersections)
                            set(i, m, val);
                    }

                    // Look for the next pair
                    l = r;
                }
            }
        }

        void extrapolateCorners() {
            if (yCount <= 1 || xCount <= 1) return;

            void extrapolateCorner(uint baseX, uint baseY, uint offX, uint offY) {
                T base = values[baseX][baseY];
                T dX = values[baseX + offX][baseY] + (base * -1f);
                T dY = values[baseX][baseY + offY] + (base * -1f);
                values[baseX + offX][baseY + offY] = base + dX + dY;
                commitPoints ~= vec2u(baseX + offX, baseY + offY);
            }

            foreach(x; 0..xCount - 1) {
                foreach(y; 0..yCount - 1) {
                    if (valid[x][y] && valid[x + 1][y] && valid[x][y + 1] && !valid[x + 1][y + 1])
                        extrapolateCorner(x, y, 1, 1);
                    else if (valid[x][y] && valid[x + 1][y] && !valid[x][y + 1] && valid[x + 1][y + 1])
                        extrapolateCorner(x + 1, y, -1, 1);
                    else if (valid[x][y] && !valid[x + 1][y] && valid[x][y + 1] && valid[x + 1][y + 1])
                        extrapolateCorner(x, y + 1, 1, -1);
                    else if (!valid[x][y] && valid[x + 1][y] && valid[x][y + 1] && valid[x + 1][y + 1])
                        extrapolateCorner(x + 1, y + 1, -1, -1);
                }
            }
        }

        void extendAndIntersect(bool secondPass) {
            yMajor = secondPass;
            bool detectedIntersections = false;

            void setOrAverage(uint maj, uint min, T val, float origin) {
                float minDist = abs(axisPoint(min) - origin);
                // Same logic as in interpolate1D2D
                if (secondPass && isNewlySet(maj, min)) {
                    // Found an intersection, do not commit the previous points
                    if (!detectedIntersections) {
                        commitPoints.length = 0;
                    }
                    float majDist = getDistance(maj, min);
                    float frac = minDist / (minDist + majDist * majDist / minDist);
                    // Interpolate the point at the intersection
                    set(maj, min, val * (1 - frac) + get(maj, min) * frac);
                    // From now on we're only computing intersection points
                    detectedIntersections = true;
                }
                // If we've found no intersections so far, continue with normal
                // 1D extension.
                if (!detectedIntersections) {
                    set(maj, min, val, minDist);
                }
            }

            foreach(i; 0..majorCnt()) {
                uint j;
                uint cnt = minorCnt();

                // Find first element set
                for(j = 0; j < cnt && !isValid(i, j); j++) {}

                // Empty row, we're done
                if (j >= cnt) continue;

                // Replicate leftwards
                T val = get(i, j);
                float origin = axisPoint(j);
                foreach(k; 0..j)
                    setOrAverage(i, k, val, origin);

                // Find last element set
                for(j = cnt - 1; j < cnt && !isValid(i, j); j--) {}

                // Replicate rightwards
                val = get(i, j);
                origin = axisPoint(j);
                foreach(k; (j + 1)..cnt)
                    setOrAverage(i, k, val, origin);
            }
        }

        while (true) {
            foreach(i; commitPoints) {
                assert(!valid[i.x][i.y], "trying to double-set a point");
                valid[i.x][i.y] = true;
                validCount++;
            }
            commitPoints.length = 0;

            // Are we done?
            if (validCount == totalCount) break;

            // Reset the newlySet array
            foreach(x; 0..xCount) {
                newlySet[x].length = 0;
                newlySet[x].length = yCount;
            }

            // Try 1D interpolation in the X-Major direction
            interpolate1D2D(false);
            // Try 1D interpolation in the Y-Major direction, with intersection detection
            // If this finds an intersection with the above, it will fall back to
            // computing *only* the intersecting points as the average of the interpolated values.
            // If that happens, the next loop will re-try normal 1D interpolation.
            interpolate1D2D(true);
            // Did we get work done? If so, commit and loop
            if (commitPoints.length > 0) continue;

            // Now try corner extrapolation
            extrapolateCorners();
            // Did we get work done? If so, commit and loop
            if (commitPoints.length > 0) continue;

            // Running out of options. Expand out points in both axes outwards, but if
            // two expansions intersect then compute the average and commit only intersections.
            // This works like interpolate1D2D, in two passes, one per axis, changing behavior
            // once an intersection is detected.
            extendAndIntersect(false);
            extendAndIntersect(true);
            // Did we get work done? If so, commit and loop
            if (commitPoints.length > 0) continue;

            // Should never happen
            break;
        }

        // The above algorithm should be guaranteed to succeed in all cases.
        enforce(validCount == totalCount, "Interpolation failed to complete");
    }

    override
    void apply(vec2u leftKeypoint, vec2 offset) {
        T p0, p1;

        if (parameter.isVec2) {
            T p00 = values[leftKeypoint.x][leftKeypoint.y];
            T p01 = values[leftKeypoint.x][leftKeypoint.y + 1];
            T p10 = values[leftKeypoint.x + 1][leftKeypoint.y];
            T p11 = values[leftKeypoint.x + 1][leftKeypoint.y + 1];
            p0 = p00.interp(p01, offset.y);
            p1 = p10.interp(p11, offset.y);
        } else {
            p0 = values[leftKeypoint.x][0];
            p1 = values[leftKeypoint.x + 1][0];
        }

        applyToTarget(p0.interp(p1, offset.x));
    }

    override
    void insertKeypoints(uint axis, uint index) {
        assert(axis == 0 || axis == 1);

        if (axis == 0) {
            uint yCount = parameter.axisPointCount(1);

            values.insertInPlace(index, cast(T[])[]);
            values[index].length = yCount;
            isSet.insertInPlace(index, cast(bool[])[]);
            isSet[index].length = yCount;
        } else if (axis == 1) {
            foreach(ref i; this.values) {
                i.insertInPlace(index, T.init);
            }
            foreach(ref i; this.isSet) {
                i.insertInPlace(index, false);
            }
        }

        reInterpolate();
    }

    override
    void moveKeypoints(uint axis, uint oldindex, uint newindex) {
        assert(axis == 0 || axis == 1);

        if (axis == 0) {
            {
                auto swap = values[oldindex];
                values = values.remove(oldindex);
                values.insertInPlace(newindex, swap);
            }

            {
                auto swap = isSet[oldindex];
                isSet = isSet.remove(oldindex);
                isSet.insertInPlace(newindex, swap);
            }
        } else if (axis == 1) {
            foreach(ref i; this.values) {
                {
                    auto swap = i[oldindex];
                    i = i.remove(oldindex);
                    i.insertInPlace(newindex, swap);
                }
            }
            foreach(i; this.isSet) {
                {
                    auto swap = i[oldindex];
                    i = i.remove(oldindex);
                    i.insertInPlace(newindex, swap);
                }
            }
        }

        reInterpolate();
    }

    override
    void deleteKeypoints(uint axis, uint index) {
        assert(axis == 0 || axis == 1);

        if (axis == 0) {
            values = values.remove(index);
            isSet = isSet.remove(index);
        } else if (axis == 1) {
            foreach(i; 0..this.values.length) {
                values[i] = values[i].remove(index);
            }
            foreach(i; 0..this.isSet.length) {
                isSet[i] = isSet[i].remove(index);
            }
        }

        reInterpolate();
    }

    void setKeypoint(vec2u index, T value)
    {
        values[index.x][index.y] = value;
        isSet[index.x][index.y] = true;
        reInterpolate();
    }

    void clearKeypoint(vec2u index)
    {
        isSet[index.x][index.y] = false;
        reInterpolate();
    }

    /**
        Apply parameter to target node
    */
    abstract void applyToTarget(T value);
}

class ValueParameterBinding : ParameterBindingImpl!float {
    this(Parameter parameter) {
        super(parameter);
    }

    this(Parameter parameter, Node targetNode, string paramName) {
        super(parameter, targetNode, paramName);
    }

    override
    void applyToTarget(float value) {
        target.node.setValue(target.paramName, value);
    }

    override
    void clearValue(ref float val) {
        val = 0f;
    }
}

class DeformationParameterBinding : ParameterBindingImpl!Deformation {
    this(Parameter parameter) {
        super(parameter);
    }

    this(Parameter parameter, Node targetNode, string paramName) {
        super(parameter, targetNode, paramName);
    }

    void update(vec2[] offsets) {
        this.isSet[offsets.x][offsets.y] = true;
        this.values[offsets.x][offsets.y].vertexOffsets = offsets.dup;
        this.reInterpolate();
    }

    override
    void applyToTarget(Deformation value) {
        enforce(this.target.paramName == "deform");

        if (Drawable d = cast(Drawable)target.node) {
            d.deformStack.push(value);
        }
    }

    override
    void clearValue(ref Deformation val) {
        // Reset deformation to identity, with the right vertex count
        if (Drawable d = cast(Drawable)target.node) {
            val.vertexOffsets.length = d.vertices.length;
            foreach(i; 0..d.vertices.length) {
                val.vertexOffsets[i] = vec2(0);
            }
        }
    }
}

@("TestInterpolation")
unittest {
    void printArray(float[][] arr) {
        foreach(row; arr) {
            writefln(" %s", row);
        }
    }

    void runTest(float[][] input, float[][] expect, float[][2] axisPoints, string description) {
        Parameter param = new Parameter();
        param.axisPoints = axisPoints;

        ValueParameterBinding bind = new ValueParameterBinding(param);

        // Assign values to ValueParameterBinding and consider NaN as !isSet
        bind.values = input;
        bind.isSet.length = input.length;
        foreach(x; 0..input.length) {
            bind.isSet[x].length = input[0].length;
            foreach(y; 0..input[0].length) {
                bind.isSet[x][y] = !isNaN(input[x][y]);
            }
        }

        // Run the interpolation
        bind.reInterpolate();

        // Check results with a fudge factor for rounding error
        const float epsilon = 0.0001;
        foreach(x; 0..bind.values.length) {
            foreach(y; 0..bind.values[0].length) {
                float delta = abs(expect[x][y] - bind.values[x][y]);
                if (isNaN(delta) || delta > epsilon) {
                    writefln("Output mismatch at %d, %d", x, y);
                    writeln("Expected:");
                    printArray(expect);
                    writeln("Output:");
                    printArray(bind.values);
                    assert(false, description);
                }
            }
        }
    }

    void runTestUniform(float[][] input, float[][] expect, string description) {
        float[][2] axisPoints = [[0], [0]];

        // Initialize axisPoints as uniformly spaced
        axisPoints[0].length = input.length;
        axisPoints[1].length = input[0].length;
        if (input.length > 1) {
            foreach(x; 0..input.length) {
                axisPoints[0][x] = x / cast(float)(input.length - 1);
            }
        }
        if (input[0].length > 1) {
            foreach(y; 0..input[0].length) {

                axisPoints[1][y] = y / cast(float)(input[0].length - 1);
            }
        }

        runTest(input, expect, axisPoints, description);
    }

    float x = float.init;

    runTestUniform(
        [[1f], [ x], [ x], [4f]],
        [[1f], [2f], [3f], [4f]],
        "1d-uniform-interpolation"
    );

    runTest(
        [[0f], [ x], [ x], [4f]],
        [[0f], [1f], [3f], [4f]],
        [[0f, 0.25f, 0.75f, 1f], [0f]],
        "1d-nonuniform-interpolation"
    );

    runTestUniform(
        [
            [ 4,  x,  x, 10],
            [ x,  x,  x,  x],
            [ x,  x,  x,  x],
            [ 1,  x,  x,  7]
        ],
        [
            [ 4,  6,  8, 10],
            [ 3,  5,  7,  9],
            [ 2,  4,  6,  8],
            [ 1,  3,  5,  7]
        ],
        "square-interpolation"
    );

    runTestUniform(
        [
            [ 4,  x,  x,  x],
            [ x,  x,  x,  x],
            [ x,  x,  x,  x],
            [ 1,  x,  x,  7]
        ],
        [
            [ 4,  6,  8, 10],
            [ 3,  5,  7,  9],
            [ 2,  4,  6,  8],
            [ 1,  3,  5,  7]
        ],
        "corner-extrapolation"
    );

    runTestUniform(
        [
            [ 9,  x,  x,  0],
            [ x,  x,  x,  x],
            [ x,  x,  x,  x],
            [ 0,  x,  x,  9]
        ],
        [
            [ 9,  6,  3,  0],
            [ 6,  5,  4,  3],
            [ 3,  4,  5,  6],
            [ 0,  3,  6,  9]
        ],
        "cross-interpolation"
    );

    runTestUniform(
        [
            [ x,  x,  2,  x,  x],
            [ x,  x,  x,  x,  x],
            [ 0,  x,  x,  x,  4],
            [ x,  x,  x,  x,  x],
            [ x,  x, 10,  x,  x]
        ],
        [
            [-2,  0,  2,  2,  2],
            [-1,  1,  3,  3,  3],
            [ 0,  2,  4,  4,  4],
            [ 3,  5,  7,  7,  7],
            [ 6,  8, 10, 10, 10]
        ],
        "diamond-interpolation"
    );

    runTestUniform(
        [
            [ x,  x,  x,  x],
            [ x,  3,  4,  x],
            [ x,  1,  2,  x],
            [ x,  x,  x,  x]
        ],
        [
            [ 3,  3,  4,  4],
            [ 3,  3,  4,  4],
            [ 1,  1,  2,  2],
            [ 1,  1,  2,  2]
        ],
        "edge-expansion"
    );

    runTestUniform(
        [
            [ x,  x,  x,  x],
            [ x,  x,  4,  x],
            [ x,  x,  x,  x],
            [ 0,  x,  x,  x]
        ],
        [
            [ 2,  3,  4,  4],
            [ 2,  3,  4,  4],
            [ 1,  2,  3,  3],
            [ 0,  1,  2,  2]
        ],
        "intersecting-expansion"
    );

    runTestUniform(
        [
            [ x,  5,  x],
            [ x,  x,  x],
            [ 0,  x,  x]
        ],
        [
            [ 4,  5,  5],
            [ 2,  3,  3],
            [ 0,  1,  1]
        ],
        "nondiagonal-gradient"
    );
}
