module inochi2d.fmt.binfmt;
import std.bitmanip;

/**
    Entrypoint magic bytes that define this is an Inochi2D puppet

    Trans Rights!
*/
enum MAGIC_BYTES = cast(ubyte[])"TRNSRTS\0";

/**
    Verifies that a buffer has the Inochi2D magic bytes present.
*/
bool inVerifyMagicBytes(ubyte[] buffer) {
    return buffer.length > MAGIC_BYTES.length && buffer[0..MAGIC_BYTES.length] == MAGIC_BYTES;
}

size_t inInterpretDataFromBuffer(T)(ubyte[] buffer, ref T data) {
    ubyte[T.sizeof] toInterp;
    toInterp[0..T.sizeof] = buffer[0..T.sizeof];

    data = bigEndianToNative!T(toInterp);
    return T.sizeof;
}