module inochi2d.fmt.binfmt;

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