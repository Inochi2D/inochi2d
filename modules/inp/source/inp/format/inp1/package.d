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
    Magic bytes as a string.    
*/
enum char[8] INP1_MAGIC = "TRNSRTS\0";
