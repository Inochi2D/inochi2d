/*
    Inochi2D Lattice Deformer Node

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.core.nodes.deformer.latticedeformer;
import inochi2d.core.nodes.deformer;
import inochi2d.core;
import inmath.linalg;
import numem;

/**
    A deformer which uses a 2D lattice as the basis for
    its deformation.
*/
@TypeId("LatticeDeformer", 0x0202)
class LatticeDeformer : Deformer {
private:
    int subdivs;
    vec2 size_;

    float[][] weights_;
    vec2[] latticeInitial;
    vec2[] lattice;

    // Regenerates the lattice points.
    void regenLattice() {
        if (subdivs == 0)
            return;
        
        this.latticeInitial = latticeInitial.nu_resize(subdivs*subdivs);
        this.lattice = lattice.nu_resize(latticeInitial.length);
        latticeInitial[0..$] = vec2.zero;

        vec2 iter = vec2(size_.x / subdivs, size_.y / subdivs);
        foreach(i; 0..lattice.length) {
            float x = mod(cast(float)i, cast(float)subdivs);
            float y = cast(float)i / cast(float)subdivs;
            latticeInitial[i] = iter * vec2(x, y);
        }
    }

    // Clears lattice weights
    void clearWeights() {
        foreach(i; 0..weights_.length) {
            nu_freea(weights_[i]);
        }
        nu_freea(weights_);
    }

protected:

    override
    void onSerialize(ref JSONValue object, bool recursive=true) {
        super.onSerialize(object, recursive);
        object["subdivisions"] = subdivs.serialize();
    }

    override
    void onDeserialize(ref JSONValue object) {
        super.onDeserialize(object);
        object.tryGetRef(subdivs, "subdivisions");
        object.tryGetRef(size_, "size");
        this.regenLattice();
    }

public:

    /**
        The size of the lattice (in pixels)
    */
    @property vec2 size() => size_;
    @property void size(vec2 value) {
        this.size_ = value;
        this.regenLattice();
    }

    /**
        The amount of subdivisions in the lattice.
    */
    @property int subdivisions() => subdivs;
    @property void subdivisions(int value) {
        this.subdivs = value;
        this.regenLattice();
    }

    /**
        The base position of the deformable's points.
    */
    override @property const(vec2)[] basePoints() => latticeInitial;

    /**
        The control points of the deformer.
    */
    override @property vec2[] controlPoints() => lattice;
    override @property void controlPoints(vec2[] value) {
        import nulib.math : min;

        size_t m = min(value.length, lattice.length);
        lattice[0..m] = value[0..m];
    }

    /**
        Constructs a new MeshGroup node
    */
    this(Node parent = null) {
        super(parent);
    }

    /**
        Updates the lattice deformer.
    */
    override
    void update(float delta, DrawList drawList) {

    }

    /**
        Deforms the IDeformable.

        Params:
            deformed =  The deformation delta.
            absolute =  Whether the deformation is absolute,
                        replacing the original deformation.
    */
    override
    void deform(vec2[] deformed, bool absolute) {
        super.deform(deformed, absolute);
    }

    /**
        Resets the deformation.
    */
    override
    void resetDeform() {
        lattice[0..$] = latticeInitial[0..$];
    }

    /**
        Rescans the children of the deformer.
    */
    override
    void rescan() {
        super.rescan();

        // // Clear weights lists.
        // this.clearWeights();
        // weights_ = nu_malloca!(float[])(toDeform.length);

        // // NOTE:    Here we go through every point in the meshes to be deformed,
        // //          we'll be assigning them weights based on their position in
        // //          lattice space and their intersection with each triangle.
        // vec2[] mLatticeSpace;
        // foreach(i, IDeformable mesh; toDeform) {
        //     weights_[i] = nu_malloca!float(mesh.deformPoints.length);
        //     if (mesh.deformPoints.length > mLatticeSpace.length)
        //         mLatticeSpace = mLatticeSpace.nu_resize(mesh.deformPoints.length);
            
        //     mLatticeSpace[0..mesh.deformPoints.length] = mesh.deformPoints[0..$];
        //     foreach(j; 0..mesh.deformPoints.length) {
        //         mLatticeSpace[j] = vec2(
        //             (deformPoints[j].x - area.left) / area.width,
        //             (deformPoints[j].y - area.left) / area.height,
        //         );
        //     }
            
        //     foreach(j; 0..mesh.deformPoints.length) {


        //         // 
        //     }
        // }
        // nu_freea(mLatticeSpace);
    }
}
mixin Register!(LatticeDeformer, in_node_registry);
