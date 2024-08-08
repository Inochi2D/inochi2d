/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/
module inochi2d.puppet.node;
import numem.all;

@nogc:

/**
    An Inochi2D Node
*/
class Node {
@nogc:
private:

    // Node tree primitives.
    weak_vector!Node children;
    Node parent;

public:

}

