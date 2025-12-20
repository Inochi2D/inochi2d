/**
    INP2 Format

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inp.format.inp2;

public import inp.format.inp2.reader;
public import inp.format.inp2.writer;

/**
    Magic bytes for INP 2 (Trans Rights 2: Electric Boogaloo)
*/
enum INP2_MAGIC = "TRNSRTS2";

/**
    Mask used to get the tag portion of a tag.
*/
enum uint INP2_TAG_MASK         = 0x000000FF;

/**
    Mask used to get the metadata portion of a tag.
*/
enum uint INP2_META_MASK        = 0xFFFFFF00;

/**
    INP2 DataNode Tag specifying a key for a key-value pair.

    Notes:
        Keys can maximum be 255 UTF8 characters.
*/
enum uint INP2_TAG_KEY          = 0xF0;

/**
    INP2 DataNode Tag specifying a nil value.
    Readers should just skip these.
*/
enum uint INP2_TAG_NIL          = 0x00;

/**
    INP2 DataNode Tag for 32-bit integers
*/
enum uint INP2_TAG_INT          = 0x01;

/**
    INP2 DataNode Tag for 32-bit unsigned integers
*/
enum uint INP2_TAG_UINT         = 0x02;

/**
    INP2 DataNode Tag for 32-bit floats
*/
enum uint INP2_TAG_FLOAT        = 0x03;

/**
    INP2 DataNode Tag for UTF8 Strings
*/
enum uint INP2_TAG_STRING       = 0x04;

/**
    INP2 DataNode Tag for data blobs
*/
enum uint INP2_TAG_BLOB         = 0x05;

/**
    INP2 DataNode Tag for an array beginning.

    Note:
        Uses Metadata
*/
enum uint INP2_TAG_ARRAY_BEGIN  = 0x10;

/**
    INP2 DataNode Tag for an array ending.
*/
enum uint INP2_TAG_ARRAY_END    = 0x11;

/**
    INP2 DataNode Tag for an object beginning.

    Note:
        Uses Metadata
*/
enum uint INP2_TAG_OBJECT_BEGIN = 0x12;

/**
    INP2 DataNode Tag for an object ending.
*/
enum uint INP2_TAG_OBJECT_END   = 0x13;