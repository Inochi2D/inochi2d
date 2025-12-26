/**
    JSON Reader

    Copyright © 2020-2025, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inp.format.json.reader;
import inp.format.node;
import nulib.io.stream;
import nulib.io.stream.rw;
import nulib.string;
import nulib.math;
import numem;

@nogc:

/**
    Reads and parses a JSON string into a $(D DataNode).

    Params:
        stream = The stream to read.
    
    Returns:
        A result type containing either a $(D DataNode)
        or an error message.
*/
Result!DataNode readJson(Stream stream) @nogc {
    scope StreamReader reader = new StreamReader(stream);
    DataNode result;

    if (auto err = reader.readJsonImpl(result, reader.stream.tell, reader.stream.length))
        return error!DataNode(err);

    return ok(result.move());
}

/**
    Reads and parses a JSON string into the given $(D DataNode).

    Params:
        reader =    The stream reader.
        node =      The node to write to.
        length =    Max length to read.
    
    Returns:
        $(D null) on success,
        otherwise an error message.

*/
string readJson(StreamReader reader, ref DataNode node, uint length = uint.max) @nogc {
    return reader.readJsonImpl(node, reader.stream.tell, min(reader.stream.length-reader.stream.tell, length));
}




//
//              IMPLEMENTATION DETAILS
//
private:

char peekChar(StreamReader reader) {
    char c = cast(char)reader.readU8();
    reader.stream.seek(-1, SeekOrigin.relative);
    return c;
}

string readJsonString(StreamReader reader) {

    // Skip initial quote.
    if (reader.peekChar() == '"') {
        reader.stream.seek(1, SeekOrigin.relative);
    }

    nstring result;
    char c;
    do {
        c = cast(char)reader.readU8();
        result ~= c;

        // Read escape codes.
        if (c == '\\') {
            c = cast(char)reader.readU8();
            result ~= c;
        }
    } while(c != '"');
    return result.take()[0..$-1];
}

string readJsonNumber(StreamReader reader) {
    nstring result;
    char c;

    do {
        c = cast(char)reader.readU8();
        result ~= c;
    } while (isNumberChar(c));
    return result.take();
}

bool isJsonSymbol(char c) {
    import nulib.text.ascii;
    return isAlphaNumeric(c) || 
        c == '"' || c == ':' || c == ',' || 
        c == '{' || c == '}' ||
        c == '[' || c == ']';
}

void skipWhitespace(StreamReader reader) {
    do {} while(!isJsonSymbol(cast(char)reader.readU8()));
    reader.stream.seek(-1, SeekOrigin.relative);
}

bool isNumberChar(char c) {
    return (c >= '0' && c <= '9') || c == '.';
}

string readJsonImpl()(StreamReader reader, ref DataNode node, size_t start, size_t length) {
    import nulib.conv : to_floating;
    reader.skipWhitespace();

    if (reader.stream.tell() > start+length)
        return "Reached EOF";

    char c = cast(char)reader.readU8();
    switch(c) {
        default:
            if (isNumberChar(c)) {
                reader.stream.seek(-1, SeekOrigin.relative);
                
                auto valueStr = reader.readJsonNumber();
                node = DataNode(to_floating!double(valueStr));
                nu_freea(valueStr);
            }
            return null;

        case '[':
            node = DataNode.createArray();
            do {
                DataNode value;

                reader.skipWhitespace();
                
                if (auto error = reader.readJsonImpl(value, start, length))
                    return error;
                node ~= value.move();

                reader.skipWhitespace();

                c = cast(char)reader.readU8();
                if (c == ',')
                    continue;
                
            } while(c != ']');
            return null;

        case '{':
            node = DataNode.createObject();
            do {
                DataNode value;

                // Get key
                reader.skipWhitespace();
                string key = reader.readJsonString();
                reader.skipWhitespace();

                c = cast(char)reader.readU8();
                if (c != ':')
                    return "Invalid key-value pair!";
                    
                reader.skipWhitespace();
                if (auto error = reader.readJsonImpl(value, start, length)) {
                    nu_freea(key);
                    return error;
                }
                reader.skipWhitespace();

                node[key] = value.move();
                nu_freea(key);

                c = cast(char)reader.readU8();
                if (c == ',')
                    continue;
                
            } while(c != '}');
            return null;

        case '"':
            reader.skipWhitespace();
            string value = reader.readJsonString();
            reader.skipWhitespace();
            node = DataNode(value);
            nu_freea(value);
            return null;
    }
}