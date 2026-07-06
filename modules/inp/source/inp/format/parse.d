/**
    Parser utilities.

    Copyright: 
        Copyright © 2020-2026, Inochi2D Project
    
    License:
        $(LINK2 https://github.com/Inochi2D/inochi2d/blob/main/LICENSE, BSD 2-clause License)
    
    Authors:
        Luna Nielsen
*/
module inp.format.parse;
import nulib.text.ascii;
import nulib.io.stream.rw;
import nulib.io.stream;
import nulib.string;
import nulib.math;
import numem;

@nogc:

// Alias to make things more obvious
alias ErrorString = string;


/**
    Gets whether the end of the stream has been reached.

    Params:
        reader = The stream reader.

    Returns:
        $(D true) if the end of the stream was reached,
        $(D false) otherwise.
*/
bool eof(StreamReader reader) {
    return reader.stream.tell() >= reader.stream.length();
}

/**
    Skips the given amount of characters in the stream.

    Params:
        reader =    The stream reader.
        count =     Amount of characters to skip.
*/
pragma(inline, true)
void skip(StreamReader reader, ptrdiff_t count) {
    reader.stream.seek(count, SeekOrigin.relative);
}

/**
    Skips ascii whitespace characters.

    Params:
        reader = The stream reader.
*/
void skipWhitespace(StreamReader reader) {
    char c;
    do { c = cast(char)reader.readU8(); } while(c == ' ' || c == '\t' || c == '\r' || c == '\n');
    reader.skip(-1);
}

/**
    Peeks a single ASCII character from the stream.

    Params:
        reader = The stream reader.

    Returns:
        The character 1 byte ahead of the current read position.
*/
char peekChar(StreamReader reader) {
    char c = cast(char)reader.readU8();
    reader.skip(-1);
    return c;
}

/**
    Takes a peek at the upcoming string contents of the given stream.

    Params:
        reader = The stream reader.
        length = The length of the string.

    Returns:
        The text read from the stream, length might be shorter
        than the requested length.
*/
nstring peekString(StreamReader reader, uint length) {
    auto s = reader.readUTF8(length);
    if (s.length > 0) {
        reader.skip(-cast(ptrdiff_t)s.length);
    }
    return s;
}

/**
    Peeks a string from the stream and checks whether
    it is the same as the given key.

    Params:
        reader =    The stream reader.
        key =       The key to compare against.

    Returns:
        $(D true) if the upcoming characters in the stream match
        $(D key), $(D false) otherwise.
*/
bool peekString(StreamReader reader, string key) {
    nstring read = reader.peekString(cast(uint)key.length);
    return key == read[];
}

/**
    Reads JSON encoded numbers from the stream.

    Params:
        reader =        The stream reader.
        isFloating =    Whether the read number was floating point.

    Returns:
        The JSON number read from the stream.
*/
nstring readNumberJson(StreamReader reader, ref bool isFloating) {
    char c = cast(char)reader.readU8();
    if (!c.isNumeric && c != '-' && c != '+') {
        reader.skip(-1);
        return nstring.init;
    }

    nstring result;
    result ~= c;

    // Read characters until they're no longer number-like.
    bool isExponent;
    while(true) {
        c = cast(char)reader.readU8();

        // Integral part
        if (!isFloating) {
            if (c == '.') {
                isFloating = true;
                result ~= c;
                continue;
            }

            if (c.isNumeric) {
                result ~= c;
                continue;
            }

            // No longer a number.
            break;
        }

        // Fractional part
        if (!isExponent) {
            if (c == 'e' || c == 'E') {
                isExponent = true;
                result ~= c;
                continue;
            }

            if (c.isNumeric) {
                result ~= c;
                continue;
            }

            // No longer a number.
            break;
        }

        // Exponential part.
        if (!(c.isNumeric || c == '-' || c == '+'))
            break;

        result ~= c;
    }

    reader.skip(-1);
    return result;
}

/**
    Reads a JSON string element from the given stream.

    Params:
        reader = The stream reader.

    Returns:
        The JSON string read from the stream.
*/
nstring readStringJson(StreamReader reader) {
    char c = cast(char)reader.readU8();

    // Not a string.
    if (c != '"') {
        reader.skip(-1);
        return nstring.init;
    }

    nstring result;
    do {
        c = cast(char)reader.readU8();
        if (c == '"')
            break;
        
        result ~= c;

        // Read escape codes.
        if (c == '\\') {
            c = cast(char)reader.readU8();
            result ~= c;
        }
    } while(c != '"');
    return result;
}

/**
    Gets whether the upcoming character is a numeric symbol.

    Params:
        c = the character

    Returns:
        Whether the upcoming character is a valid     
*/
bool isNumeric(char c) {
    return (c >= '0' && c <= '9');
}