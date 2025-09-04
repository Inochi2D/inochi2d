module inochi2d.core.nodes.drawable.apart;
import inochi2d.core.nodes.drawable.part;
import inochi2d.core;
import inochi2d.core.math;

/**
    Parts which contain spritesheet animation
*/
@TypeId("AnimatedPart")
class AnimatedPart : Part {
private:

protected:
    override
    string typeId() { return "AnimatedPart"; }

public:

    /**
        The amount of splits in the texture
    */
    vec2i splits;
}