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
    Drawable parent;

    /**
        Calculate the combined deformations
    */
    void calculate() {

        // Initial variables        
        bool hasInitialized = false;

        foreach(defId, deformation; deformations) {

            // TODO: Emit a warning for mismatched deformation data
            if (deformation.vertexOffsets.length != parent.vertices.length) continue;

            // Initialize deformData with initial values if need be
            if (!hasInitialized) {
                deformData[] = deformation.vertexOffsets[];
                hasInitialized = true;
                continue;
            }

            // If already initialized then add the next deformation data with existing
            // TODO: Use SIMD?
            foreach(i; 0..deformData.length) {
                
                // Set to 0 first if we're doing a new calculation
                if (defId == 0) deformData[i] = vec2(0);

                // Add deformation
                deformData[i] += deformation.vertexOffsets[i];
            }
        }
        
    }

    /**
        Applies deformation to parent
    */
    void apply() {
        MeshData mesh = parent.getMesh();
        foreach(i; 0..deformData.length) {

            // Vertex position calculated
            const(vec2) vp = *(mesh.vertices.ptr+i) + *(deformData.ptr+i);

            // Tiny optimization, avoid array bounds checking
            vec2* cvp = (parent.vertices.ptr+i);
            *cvp = vp;
        }
    }

public:

    this(Drawable parent) {
        this.parent = parent;
        this.resize();
    }

    /**
        List of deformations to apply
    */
    Deformation[] deformations;

    /**
        Resizes the deformation stack's internal buffer
    */
    void resize() {
        if (parent is null) return;
        
        deformData.length = parent.vertices.length;

        // Zero it out so that we don't have problems
        foreach(i; 0..deformData.length) {
            deformData[i] = vec2(0);
        }
    }

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
        
        this.calculate();
        this.apply();
        idx = 0;
    }
}