module inochi2d.core.nodes.defstack;
import inochi2d.core;
import inochi2d.math;
import inochi2d;

/**
    A deformation
*/
struct Deformation {

    /**
        Deformed values
    */
    vec2[] vertexOffsets;
}

/**
    A stack of local deformations to apply to the mesh
*/
struct DeformationStack {
private:
    size_t idx = 0;

    vec2[] deformData;
    float deformCount;

    Drawable parent;

    /**
        Calculate the combined deformations
    */
    void calculate(size_t size) {

        // Initial variables        
        bool hasInitialized = false;
        deformCount = 0;

        // Set size of deform data
        if (deformData.length != size) {
            deformData.length = size;
        }

        foreach(deformation; deformations) {

            // TODO: Emit a warning for mismatched deformation data
            if (deformation.vertexOffsets.length != size) continue;

            // We're adding a new deformation to the calculation
            deformCount++;

            // Initialize deformData with initial values if need be
            if (!hasInitialized) {
                deformData[] = deformation.vertexOffsets[];
                hasInitialized = true;
                continue;
            }

            // If already initialized then add the next deformation data with existing
            // TODO: Use SIMD?
            foreach(i; 0..size) deformData[i] += deformation.vertexOffsets[i];
        }
        
    }

    /**
        Applies deformation to parent
    */
    void apply() {
        MeshData mesh = parent.getMesh();
        foreach(i; 0..deformData.length) {

            // Vertex position calculated
            const(vec2) vp = *(mesh.vertices.ptr+i) + (*(deformData.ptr+i)/deformCount);

            // Tiny optimization, avoid array bounds checking
            vec2* cvp = (parent.vertices.ptr+i);
            *cvp = vp;
        }
    }

public:

    this(Drawable parent) {
        this.parent = parent;
    }

    /**
        List of deformations to apply
    */
    Deformation[] deformations;

    /**
        Push deformation on to stack
    */
    void push(ref Deformation deformation) {
        
        // Make sure there's space for deformation
        if (idx >= deformations.length) deformations.length = idx+1;

        // Does the actual pushing
        deformations[idx++] = deformation;
    }

    /**
        Updates deformation calculations
    */
    void update() {
        if (parent is null) return;
        
        this.calculate(parent.vertices.length);
        this.apply();
        idx = 0;
    }
}