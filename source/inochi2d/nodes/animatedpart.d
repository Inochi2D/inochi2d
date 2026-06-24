module inochi2d.nodes.animatedpart;
import inochi2d.nodes.part;
import inochi2d.nodes;
import inochi2d.core;

/**
    Parts which contain spritesheet animation
*/
@TypeId("AnimatedPart", 0x0201)
class AnimatedPart : Part {
private:
@nogc:
    vec2 frameSize_;
    vec2u frameCount_;
    vec2u frame_;

protected:

    /**
        Serializes this node to a DataNode.

        Params:
            object =    The DataNode to serialize to.
            recursive = Whether to recurse through children.
    */
    override
    void onSerialize(ref DataNode object, bool recursive = true) {
        super.onSerialize(object, recursive);

        object["frameSize"] = frameSize_.serialize();
        object["frameCount"] = frameCount_.serialize();
    }

    /**
        Deserializes this node from a DataNode.

        Params:
            object = The DataNode to deserialize from.
    */
    override
    void onDeserialize(ref DataNode object) {
        super.onDeserialize(object);

        object.tryGetRef(frameSize_, "frameSize");
        object.tryGetRef(frameCount_, "frameCount");
    }

    /**
        Called during the late update phase of a new frame.
        
        Params:
            drawList =  The drawlist for the active scene.
    */
    override
    void onPostUpdate(DrawList drawList) {
        this.deformedMesh.applyUVOffset(vec2(
            frameSize_.x * cast(float)frame_.x,
            frameSize_.y * cast(float)frame_.y,
        ));
        super.onPostUpdate(drawList);
    }

public:
    
    /**
        The size of a single frame in texel coordinates.
    */
    @property ref vec2 frameSize() => frameSize_;

    /**
        The amount of frames and animations in the animated part.
    */
    @property ref vec2u frameCount() => frameCount_;

    /**
        Gets whether a property with the given name exists
        in the object.

        Params:
            key = The name of the property.
        
        Returns:
            $(D true) if the property exists,
            $(D false) otherwise.
    */
    override
    bool hasProperty(string key) const {
        switch (key) {
        case "frame.x":
        case "frame.y":
            return true;
        
        default:
            return super.hasProperty(key);
        }
    }

    /**
        Gets the value of a given property.

        Params:
            key = The name of the property.
        
        Returns:
            The floating point value of the property.
    */
    override
    float getProperty(string key) const {
        switch (key) {
        case "frame.x":
            return frame_.x;
        case "frame.y":
            return frame_.y;
        default:
            return super.getProperty(key);
        }
    }

    /**
        Gets the default value of a given property.

        Params:
            key = The name of the property.
        
        Returns:
            The default value of the property.
    */
    override
    float getPropertyDefault(string key) const {
        switch (key) {
        case "frame.x":
            return 0;
        case "frame.y":
            return 0;
        default:
            return super.getPropertyDefault(key);
        }
    }

    /**
        Sets the value of the property.

        Params:
            key =   The name of the property.
            value = The value to set the property to.
    */
    override
    void setProperty(string key, float value) {
        switch (key) {
        case "frame.x":
            this.frame_.x = cast(uint)value;
            return;
        case "frame.y":
            this.frame_.y = cast(uint)value;
            return;
        default:
            return super.setProperty(key, value);
        }
    }
}

mixin Register!(AnimatedPart, in_node_registry);
