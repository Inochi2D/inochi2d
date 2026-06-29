/**
    Inochi2D Legacy Nodes for backwards compatibility.

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
        Hoshino Lina
*/
module inochi2d.nodes.legacy;

// Allow disabling legacy nodes.
version (IN_NO_LEGACY) {
} else:

    public import inochi2d.nodes.legacy.simplephysics;
