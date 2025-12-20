/**
    CRC32 Implementation

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inp.crc;

/**
    Generates an crc32 checksum from a buffer.

    Params:
        buffer =    The buffer to make a checksum for
        crc =       The initial seed for the checksum.
    
    Returns:
        The checksum of the given buffer; checksums can be chained
        by passing the result to `crc` in a second iteration.
*/
uint crc32(ubyte[] buffer, uint crc = 0) @nogc nothrow {

    // Pre-generate CRC32 lookup table.
    static immutable(uint)[256] gen_crc_table_ctfe() {
        if (__ctfe) {
            uint[256] result;
            uint rem;
            foreach(i; 0..255) {
                rem = i;
                foreach(j; 0..8) {
                    bool isRem1 = rem & 1;

                    rem >>= 1;
                    if (isRem1)
                        rem ^= 0xedb88320;
                }
                result[i] = rem;
            }

            return result;
        } else {
            return typeof(return).init;
        }
    }
    __gshared immutable(uint)[256] __crc_table = gen_crc_table_ctfe();

    // Actual CRC32 algorithm.
    crc = ~crc;
    foreach(p; buffer) {
        crc = (crc >> 8) ^ __crc_table[(crc & 0xFF) ^ p];
    }
    return ~crc;
}

@("crc32: \"The quick brown fox jumps over the lazy dog\"")
unittest {
    string text = "The quick brown fox jumps over the lazy dog";
    assert(crc32(cast(ubyte[])text) == 0x414fa339);  
}

@("crc32: \"Hello, world!\"")
unittest {
    string text = "Hello, world!";
    assert(crc32(cast(ubyte[])text) == 0xebe6c6e6);  
}