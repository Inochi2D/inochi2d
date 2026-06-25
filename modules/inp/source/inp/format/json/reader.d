/**
    JSON Reader

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inp.format.json.reader;
import inp.format.parse;
import inp.format.node;
import nulib.io.stream;
import nulib.io.stream.rw;
import nulib.string;
import nulib.math;
import nulib.conv;
import numem;

@nogc:

/**
    Reads and parses a JSON string into a $(D DataNode).

    Params:
        stream = The stream to read.
        length = The amount of characters to read.
    
    Returns:
        A result type containing either a $(D DataNode)
        or an error message.
*/
Result!DataNode readJson(Stream stream, size_t length = 0) @nogc {
    DataNode result;
    scope StreamReader reader = new StreamReader(stream);
    if (auto err = reader.readJson(result, length))
        return error!DataNode(err);
    return ok(result.move());
}

/**
    Reads JSON data from the given existing stream.

    Params:
        reader =    The stream reader to read from.
        node =      The node to store the result in.
        length =    The length of the buffer to read.

    Returns:
        Any errors emitted.
*/
ErrorString readJson(StreamReader reader, ref DataNode node, size_t length) {
    if (length > 0) {
        ubyte[] buffer = nu_malloca!ubyte(length);
        if (reader.stream.read(buffer) < length)
            return "Reached EOF!";

        scope MemoryStream mstream = new MemoryStream(buffer);
        scope StreamReader mreader = new StreamReader(mstream);
        return mreader.readJson(node);
    }
    return reader.readJson(node);
}




//
//              IMPLEMENTATION DETAILS
//
private:

/**
    Reads a JSON value from the stream.    
*/
ErrorString readJson(StreamReader reader, ref DataNode node) {
    reader.skipWhitespace();
    switch(reader.peekChar()) {
        default:
            if (reader.peekString("true")) {
                reader.skip(4);
                node = DataNode(true);
                return null;
            }

            if (reader.peekString("false")) {
                reader.skip(5);
                node = DataNode(false);
                return null;
            }

            // Skip 'null'
            if (reader.peekString("null")) {
                reader.skip(4);
                return null;
            }

            // Okay, no idea what this character is.
            return "Unexpected token";

        case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9':
        case '+', '-':
            return reader.readJsonNumber(node);

        case '"':
            return reader.readJsonString(node);

        case '{':
            return reader.readJsonObject(node);

        case '[':
            return reader.readJsonArray(node);
    }
}

ErrorString readJsonString(StreamReader reader, ref DataNode node) {
    node = DataNode(reader.readStringJson().take());
    return null;
}

ErrorString readJsonNumber(StreamReader reader, ref DataNode node) {
    bool isFloating;
    nstring num = reader.readNumberJson(isFloating);

    if (isFloating)
        node = DataNode(parseFloat!double(num[]));
    else
        node = DataNode(parseInt!long(num[]));
    
    return null;
}

ErrorString readJsonArray(StreamReader reader, ref DataNode node) {
    char c = cast(char)reader.readU8();
    if (c != '[')
        return "Not an array";

    node = DataNode.createArray();
            
    // Empty array.
    if (reader.peekChar() == ']') {
        reader.skip(1);
        return null;
    }

    DataNode value;
    do {
        
        // Read value
        reader.skipWhitespace();
        if (auto error = reader.readJson(value)) {
            return error;
        }
        reader.skipWhitespace();

        // Append value
        node ~= value.move();

        // Consume comma if needed.
        c = cast(char)reader.readU8();
        if (c == ',') {
            reader.skipWhitespace();
            continue;
        }

        // Consume array end.
        if (c == ']')
            break;

    } while(!reader.eof());
    return null;
}

ErrorString readJsonObject(StreamReader reader, ref DataNode node) {
    char c = cast(char)reader.readU8();
    if (c != '{')
        return "Not an object";

    node = DataNode.createObject();
            
    // Empty object.
    if (reader.peekChar() == '}') {
        reader.skip(1);
        return null;
    }

    DataNode value;
    do {

        // Read key
        reader.skipWhitespace();
        nstring key = reader.readStringJson();
        reader.skipWhitespace();

        // Ensure it's a k-v pair.
        c = cast(char)reader.readU8();
        if (c != ':')
            return "Invalid key-value pair!";
        
        // Read value
        reader.skipWhitespace();
        if (auto error = reader.readJson(value)) {
            return error;
        }
        reader.skipWhitespace();

        // Assign key-value pair.
        node[key[]] = value.move();

        // Consume comma if needed.
        c = cast(char)reader.readU8();
        if (c == ',') {
            reader.skipWhitespace();
            continue;
        }

        // Comsume object end.
        if (c == '}')
            break;

    } while(!reader.eof());
    return null;
}