/**
    INP 1 Format

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inp.format.inp1;

public import inp.format.inp1.reader;
public import inp.format.inp1.writer;

/**
    Magic bytes as a string.    
*/
enum char[8] INP1_MAGIC = "TRNSRTS\0";
