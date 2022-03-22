module inochi2d.core.param;
import inochi2d.fmt.serialize;
import inochi2d.math.serialization;
import inochi2d.core;
import inochi2d.math;

/**
    A binding to a parameter
*/
struct ParameterBinding {
public:
    /**
        UUID of the node
    */
    uint nodeRef;

    /**
        The node to bind to
    */
    Node node;

    /**
        The parameter to bind
    */
    string paramName;

    /**
        The value at that breakpoint
    */
    float value;

    /**
        Serializes a binding
    */
    void serialize(S)(ref S serializer) {
        serializer.putKey("node");
        serializer.putValue(node.uuid);
        serializer.putKey("param_name");
        serializer.putValue(paramName);
        serializer.putKey("value");
        serializer.putValue(value);
    }
    
    /**
        Deserializes a binding
    */
    SerdeException deserializeFromAsdf(Asdf data) {
        data["node"].deserializeValue(this.nodeRef);
        data["param_name"].deserializeValue(this.paramName);
        data["value"].deserializeValue(this.value);
        return null;
    }

    /**
        Finalize loading of parameter
    */
    void finalize(Puppet puppet) {
        this.node = puppet.find(nodeRef);
    }
}

/**
    A keypoint in a parameter
*/
struct KeyPoint {

    /**
        The breakpoint location
    */
    vec2 keypoint;

    /**
        List of bindings
    */
    ParameterBinding[] bindings;

    /**
        Serializes a binding
    */
    void serialize(S)(ref S serializer) {
        serializer.putKey("keypoint");
        keypoint.serialize(serializer);
        serializer.putKey("bindings");
        serializer.serializeValue(bindings);
    }
    
    /**
        Deserializes a binding
    */
    SerdeException deserializeFromAsdf(Asdf data) {
        keypoint.deserialize(data);
        data["bindings"].deserializeValue(this.bindings);
        return null;
    }


    /**
        Finalize loading of parameter
    */
    void finalize(Puppet puppet) {
        foreach(binding; bindings) {
            binding.finalize(puppet);
        }
    }
}

/**
    A parameter
*/
class Parameter {
public:
    /**
        Unique ID of parameter
    */
    uint uuid;

    /**
        name of the parameter
    */
    string name;

    /**
        The parameter's handle
    */
    @Ignore
    vec2 handle = vec2(0);

    /**
        Whether the parameter is 2D
    */
    @Name("is_2d")
    bool isVec2;

    /**
        For serialization
    */
    this() { }

    /**
        Unload UUID on clear
    */
    ~this() {
        inUnloadUUID(this.uuid);
    }

    /**
        Create new parameter
    */
    this(string name) {
        this.uuid = inCreateUUID();
        this.name = name;
    }

    /**
        The breakpoints of the parameter
    */
    @Name("keypoints", "breakpoints") // Breakpoints specified for backwards compatibility
    KeyPoint[] keypoints;

    /**
        Finalize loading of parameter
    */
    void finalize(Puppet puppet) {
        foreach(keypoint; keypoints) {
            keypoint.finalize(puppet);
        }
    }

    void update() {} // stub
}