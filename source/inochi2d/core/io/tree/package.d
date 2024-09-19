/*
    Copyright © 2024, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.

    Authors: Luna the Foxgirl
*/

/**
    The Inochi2D Puppet Object Model

    This contains the lower level tree structures used by Inochi2D
    to serialize a model to file.

    The contents of an InpNode gets passed to the (de)serialization backend
    for saving or loading.

    This allows Inochi2D to both support the older INP 1.0 and the new
    INP 2.0 file format w/ the inbf encoding style.
*/
module inochi2d.core.io.tree;
import numem.all;

public import inochi2d.core.io.tree.value;
public import inochi2d.core.io.tree.ctx;
