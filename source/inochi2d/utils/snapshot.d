module inochi2d.utils.snapshot;

import inochi2d.core.nodes;
import inochi2d.core.nodes.composite.dcomposite;
import inochi2d.core.puppet;
import inochi2d.core.texture;
import inmath;

class Snapshot {
protected:
    Puppet snapshotPuppet = null;
    DynamicComposite dcomposite = null;
    int sharedCount = 0;
    static Snapshot[Puppet] handles;

    this(Puppet puppet) {
        sharedCount = 1;
        setup(puppet);
    }

    void setup(Puppet puppet) {
        if (dcomposite !is null) {
            if (dcomposite.textures[0] !is null) {
                dcomposite.textures[0].dispose();
                dcomposite.textures[0] = null;
            }
        }
        dcomposite = new DynamicComposite();
        snapshotPuppet = puppet;
        dcomposite.name = "Snapshot";
        dcomposite.parent(puppet.getPuppetRootNode());
        puppet.root.parent(cast(Node)dcomposite);
        dcomposite.setPuppet(puppet);
        puppet.rescanNodes();
        dcomposite.build();
    }

public:
    static Snapshot get(Puppet puppet) {
        if (puppet in handles) {
            handles[puppet].sharedCount ++;
            return handles[puppet];
        }
        auto result = new Snapshot(puppet);
        handles[puppet] = result;
        return result;
    }

    void release() {
        if (--sharedCount <= 0) {
            if (snapshotPuppet !is null) {
                if (snapshotPuppet.actualRoot != snapshotPuppet.root) {
                    foreach (child; dcomposite.children)
                        dcomposite.releaseChild(child);
                    snapshotPuppet.root.parent(snapshotPuppet.getPuppetRootNode());
                }
                handles.remove(snapshotPuppet);
                snapshotPuppet = null;
                dcomposite = null;
            }
        }
    }

    Texture capture() {
        snapshotPuppet.rescanNodes();
        dcomposite.setupSelf();
//        dcomposite.autoResizedMesh = false;
//        dcomposite.draw();
        auto tex = dcomposite.textures[0];
        return tex;
    }

    vec2 position() {
        if (dcomposite) {
            vec2 pos = dcomposite.transform.translation.xy + dcomposite.textureOffset;
            return pos;
        }
        return vec2(0, 0);
    }
}