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
        Restructure object before finalization
    */
    abstract void reconstruct(Puppet puppet);

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
        Sets value at specified keypoint to the current value
    */
    abstract void setCurrent(vec2u point);

    /**
        Unsets value at specified keypoint
    */
    abstract void unset(vec2u point);

    /**
        Resets value at specified keypoint to default
    */
    abstract  void reset(vec2u point);

    /**
        Returns whether the specified keypoint is set
    */
    abstract bool isSet(vec2u index);

    /**
        Scales the value, optionally with axis awareness
    */
    abstract void scaleValueAt(vec2u index, int axis, float scale);

    /**
        Extrapolates the value across an axis
    */
    abstract void extrapolateValueAt(vec2u index, int axis);

    /**
        Copies the value to a point on another compatible binding
    */
    abstract void copyKeypointToBinding(vec2u src, ParameterBinding other, vec2u dest);

    /**
        Swaps the value to a point on another compatible binding
    */
    abstract void swapKeypointWithBinding(vec2u src, ParameterBinding other, vec2u dest);

    /**
        Flip the keypoints on an axis
    */
    abstract void reverseAxis(uint axis);

    /**
        Update keypoint interpolation
    */
    abstract void reInterpolate();

    /**
        Returns isSet_
    */
    abstract ref bool[][] getIsSet();

    /**
        Gets how many breakpoints this binding is set to
    */
    abstract uint getSetCount();

    /**
        Move keypoints to a new axis point
    */
    abstract void moveKeypoints(uint axis, uint oldindex, uint index);

    /**
        Add keypoints along a new axis point
    */
    abstract void insertKeypoints(uint axis, uint index);

    /**
        Remove keypoints along an axis point
    */
    abstract void deleteKeypoints(uint axis, uint index);

    /**
        Gets target of binding
    */
    BindTarget getTarget();

    /**
        Gets name of binding
    */
    abstract string getName();

    /**
        Gets the node of the binding
    */
    abstract Node getNode();

    /**
        Gets the uid of the node of the binding
    */
    abstract uint getNodeUID();

    /**
        Checks whether a binding is compatible with another node
    */
    abstract bool isCompatibleWithNode(Node other);

    /**
        Gets the interpolation mode
    */
    abstract InterpolateMode interpolateMode();

    /**
        Sets the interpolation mode
    */
    abstract void interpolateMode(InterpolateMode mode);

    /**
        Serialize
    */
    void serializeSelf(ref InochiSerializer serializer);

    /**
        Deserialize
    */
    SerdeException deserializeFromFghj(Fghj data);
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

    InterpolateMode interpolateMode_ = InterpolateMode.Linear;

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
    bool[][] isSet_;

    /**
        Gets target of binding
    */
    override
    BindTarget getTarget() {
        return target;
    }

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
        Gets the uid of the node of the binding
    */
    override
    uint getNodeUID() {
        return nodeRef;
    }

    /**
        Returns isSet_
    */
    override
    ref bool[][] getIsSet() {
        return isSet_;
    }

    /**
        Gets how many breakpoints this binding is set to
    */
    override
    uint getSetCount() {
        uint count = 0;
        foreach(x; 0..isSet_.length) {
            foreach(y; 0..isSet_[x].length) {
                if (isSet_[x][y]) count++;
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
            serializer.putValue(target.node.uid);
            serializer.putKey("param_name");
            serializer.putValue(target.paramName);
            serializer.putKey("values");
            serializer.serializeValue(values);
            serializer.putKey("isSet");
            serializer.serializeValue(isSet_);
            serializer.putKey("interpolate_mode");
            serializer.serializeValue(interpolateMode_);
        serializer.objectEnd(state);
    }

    /**
        Deserializes a binding
    */
    override
    SerdeException deserializeFromFghj(Fghj data) {
        data["node"].deserializeValue(this.nodeRef);
        data["param_name"].deserializeValue(this.target.paramName);
        data["values"].deserializeValue(this.values);
        data["isSet"].deserializeValue(this.isSet_);
        auto mode = data["interpolate_mode"];
        if (mode != Fghj.init) {
            mode.deserializeValue(this.interpolateMode_);
        } else {
            this.interpolateMode_ = InterpolateMode.Linear;
        }

        uint xCount = parameter.axisPointCount(0);
        uint yCount = parameter.axisPointCount(1);

        enforce(this.values.length == xCount, "Mismatched X value count");
        foreach(i; this.values) {
            enforce(i.length == yCount, "Mismatched Y value count");
        }

        enforce(this.isSet_.length == xCount, "Mismatched X isSet_ count");
        foreach(i; this.isSet_) {
            enforce(i.length == yCount, "Mismatched Y isSet_ count");
        }

        return null;
    }

    override
    void reconstruct(Puppet puppet) { }

    /**
        Finalize loading of parameter
    */
    override
    void finalize(Puppet puppet) {
//        writefln("finalize binding %s", this.getName());

        this.target.node = puppet.find(nodeRef);
//        writefln("node for %d = %x", nodeRef, &(target.node));
    }

    /**
        Clear all keypoint data
    */
    override
    void clear() {
        uint xCount = parameter.axisPointCount(0);
        uint yCount = parameter.axisPointCount(1);

        values.length = xCount;
        isSet_.length = xCount;
        foreach(x; 0..xCount) {
            isSet_[x].length = 0;
            isSet_[x].length = yCount;

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
        isSet_[point.x][point.y] = true;
        
        reInterpolate();
    }

    /**
        Sets value at specified keypoint to the current value
    */
    override
    void setCurrent(vec2u point) {
        isSet_[point.x][point.y] = true;

        reInterpolate();
    }

    /**
        Unsets value at specified keypoint
    */
    override
    void unset(vec2u point) {
        clearValue(values[point.x][point.y]);
        isSet_[point.x][point.y] = false;

        reInterpolate();
    }

    /**
        Resets value at specified keypoint to default
    */
    override
    void reset(vec2u point) {
        clearValue(values[point.x][point.y]);
        isSet_[point.x][point.y] = true;

        reInterpolate();
    }

    /**
        Returns whether the specified keypoint is set
    */
    override
    bool isSet(vec2u index) {
        return isSet_[index.x][index.y];
    }

    /**
        Flip the keypoints on an axis
    */
    override void reverseAxis(uint axis) {
        if (axis == 0) {
            values.reverse();
            isSet_.reverse();
        } else {
            foreach(ref i; values) i.reverse();
            foreach(ref i; isSet_) i.reverse();
        }
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
            valid ~= isSet_[x].dup;
            foreach(y; 0..yCount) {
                if (isSet_[x][y]) validCount++;
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

    T interpolate(vec2u leftKeypoint, vec2 offset) {
        switch (interpolateMode_) {
            case InterpolateMode.Nearest:
                return interpolateNearest(leftKeypoint, offset);
            case InterpolateMode.Linear:
                return interpolateLinear(leftKeypoint, offset);
            case InterpolateMode.Cubic:
                return interpolateCubic(leftKeypoint, offset);
            default: assert(0);
        }
    }

    T interpolateNearest(vec2u leftKeypoint, vec2 offset) {
        ulong px = leftKeypoint.x + ((offset.x >= 0.5) ? 1 : 0);
        if (parameter.isVec2) {
            ulong py = leftKeypoint.y + ((offset.y >= 0.5) ? 1 : 0);
            return values[px][py];
        } else {
            return values[px][0];
        }
    }

    T interpolateLinear(vec2u leftKeypoint, vec2 offset) {
        T p0, p1;

        if (parameter.isVec2) {
            T p00 = values[leftKeypoint.x][leftKeypoint.y];
            T p01 = values[leftKeypoint.x][leftKeypoint.y + 1];
            T p10 = values[leftKeypoint.x + 1][leftKeypoint.y];
            T p11 = values[leftKeypoint.x + 1][leftKeypoint.y + 1];
            p0 = p00.lerp(p01, offset.y);
            p1 = p10.lerp(p11, offset.y);
        } else {
            p0 = values[leftKeypoint.x][0];
            p1 = values[leftKeypoint.x + 1][0];
        }

        return p0.lerp(p1, offset.x);
    }

    T interpolateCubic(vec2u leftKeypoint, vec2 offset) {
        T p0, p1, p2, p3;

        T bicubicInterp(vec2u left, float xt, float yt) {
            T p01, p02, p03, p04;
            T[4] pOut;

            size_t xlen = values.length-1;
            size_t ylen = values[0].length-1;
            ptrdiff_t xkp = cast(ptrdiff_t)leftKeypoint.x;
            ptrdiff_t ykp = cast(ptrdiff_t)leftKeypoint.y;

            foreach(y; 0..4) {
                size_t yp = clamp(ykp+y-1, 0, ylen);

                p01 = values[max(xkp-1, 0)][yp];
                p02 = values[xkp][yp];
                p03 = values[xkp+1][yp];  
                p04 = values[min(xkp+2, xlen)][yp];
                pOut[y] = cubic(p01, p02, p03, p04, xt);
            }

            return cubic(pOut[0], pOut[1], pOut[2], pOut[3], yt);
        }

        if (parameter.isVec2) {
            return bicubicInterp(leftKeypoint, offset.x, offset.y);
        } else {
            ptrdiff_t xkp = cast(ptrdiff_t)leftKeypoint.x;
            size_t xlen = values.length-1;

            p0 = values[max(xkp - 1, 0)][0];
            p1 = values[xkp][0];
            p2 = values[xkp + 1][0];     
            p3 = values[min(xkp + 2, xlen)][0];
            return cubic(p0, p1, p2, p3, offset.x);
        }
    }

    override
    void apply(vec2u leftKeypoint, vec2 offset) {
        applyToTarget(interpolate(leftKeypoint, offset));
    }

    override
    void insertKeypoints(uint axis, uint index) {
        assert(axis == 0 || axis == 1);

        if (axis == 0) {
            uint yCount = parameter.axisPointCount(1);

            values.insertInPlace(index, cast(T[])[]);
            values[index].length = yCount;
            isSet_.insertInPlace(index, cast(bool[])[]);
            isSet_[index].length = yCount;
        } else if (axis == 1) {
            foreach(ref i; this.values) {
                i.insertInPlace(index, T.init);
            }
            foreach(ref i; this.isSet_) {
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
                auto swap = isSet_[oldindex];
                isSet_ = isSet_.remove(oldindex);
                isSet_.insertInPlace(newindex, swap);
            }
        } else if (axis == 1) {
            foreach(ref i; this.values) {
                {
                    auto swap = i[oldindex];
                    i = i.remove(oldindex);
                    i.insertInPlace(newindex, swap);
                }
            }
            foreach(i; this.isSet_) {
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
            isSet_ = isSet_.remove(index);
        } else if (axis == 1) {
            foreach(i; 0..this.values.length) {
                values[i] = values[i].remove(index);
            }
            foreach(i; 0..this.isSet_.length) {
                isSet_[i] = isSet_[i].remove(index);
            }
        }

        reInterpolate();
    }

    override void scaleValueAt(vec2u index, int axis, float scale)
    {
        /* Default to just scalar scale */
        setValue(index, getValue(index) * scale);
    }

    override void extrapolateValueAt(vec2u index, int axis)
    {
        vec2 offset = parameter.getKeypointOffset(index);

        switch (axis) {
            case -1: offset = vec2(1, 1) - offset; break;
            case 0: offset.x = 1 - offset.x; break;
            case 1: offset.y = 1 - offset.y; break;
            default: assert(false, "bad axis");
        }

        vec2u srcIndex;
        vec2 subOffset;
        parameter.findOffset(offset, srcIndex, subOffset);

        T srcVal = interpolate(srcIndex, subOffset);

        setValue(index, srcVal);
        scaleValueAt(index, axis, -1);
    }

    override void copyKeypointToBinding(vec2u src, ParameterBinding other, vec2u dest)
    {
        if (!isSet(src)) {
            other.unset(dest);
        } else if (auto o = cast(ParameterBindingImpl!T)(other)) {
            o.setValue(dest, getValue(src));
        } else {
            assert(false, "ParameterBinding class mismatch");
        }
    }

    override void swapKeypointWithBinding(vec2u src, ParameterBinding other, vec2u dest)
    {
        if (auto o = cast(ParameterBindingImpl!T)(other)) {
            bool thisSet = isSet(src);
            bool otherSet = other.isSet(dest);
            T thisVal = getValue(src);
            T otherVal = o.getValue(dest);

            // Swap directly, to avoid clobbering by update
            o.values[dest.x][dest.y] = thisVal;
            o.isSet_[dest.x][dest.y] = thisSet;
            values[src.x][src.y] = otherVal;
            isSet_[src.x][src.y] = otherSet;

            reInterpolate();
            o.reInterpolate();
        } else {
            assert(false, "ParameterBinding class mismatch");
        }
    }

    /**
        Get the interpolation mode
    */
    override InterpolateMode interpolateMode() {
        return interpolateMode_;
    }

    /**
        Set the interpolation mode
    */
    override void interpolateMode(InterpolateMode mode) {
        interpolateMode_ = mode;
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
        val = target.node.getDefaultValue(target.paramName);
    }

    override void scaleValueAt(vec2u index, int axis, float scale)
    {
        /* Nodes know how to do axis-aware scaling */
        setValue(index, target.node.scaleValue(target.paramName, getValue(index), axis, scale));
    }

    override bool isCompatibleWithNode(Node other)
    {
        return other.hasParam(this.target.paramName);
    }
}

class DeformationParameterBinding : ParameterBindingImpl!Deformation {
    this(Parameter parameter) {
        super(parameter);
    }

    this(Parameter parameter, Node targetNode, string paramName) {
        super(parameter, targetNode, paramName);
    }

    void update(vec2u point, vec2[] offsets) {
        this.isSet_[point.x][point.y] = true;
        this.values[point.x][point.y].vertexOffsets = offsets.dup;
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

    override
    void scaleValueAt(vec2u index, int axis, float scale)
    {
        vec2 vecScale;

        switch (axis) {
            case -1: vecScale = vec2(scale, scale); break;
            case 0: vecScale = vec2(scale, 1); break;
            case 1: vecScale = vec2(1, scale); break;
            default: assert(false, "Bad axis");
        }

        /* Default to just scalar scale */
        setValue(index, getValue(index) * vecScale);
    }

    override bool isCompatibleWithNode(Node other)
    {
        if (Drawable d = cast(Drawable)target.node) {
            if (Drawable o = cast(Drawable)other) {
                return d.vertices.length == o.vertices.length;
            } else {
                return false;
            }
        } else {
            return false;
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

        // Assign values to ValueParameterBinding and consider NaN as !isSet_
        bind.values = input;
        bind.isSet_.length = input.length;
        foreach(x; 0..input.length) {
            bind.isSet_[x].length = input[0].length;
            foreach(y; 0..input[0].length) {
                bind.isSet_[x][y] = !isNaN(input[x][y]);
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
                    debug writefln("Output mismatch at %d, %d", x, y);
                    debug writeln("Expected:");
                    printArray(expect);
                    debug writeln("Output:");
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
