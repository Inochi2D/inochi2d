/**
    INP 1 Format

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inp.format.inp1;

public import inp.format.inp1.reader;
public import inp.format.inp1.writer;

/**
    Magic bytes for INP 1 (Trans Rights!)
*/
enum INP1_MAGIC = "TRNSRTS\0";

