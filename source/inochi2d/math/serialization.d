module inochi2d.math.serialization;
import inochi2d.fmt.serialize;
import inmath.linalg;
import inmath.util;

/**
    Serializes any size of vector
*/
void serialize(V, S)(V value, ref S serializer) if(isVector!V) {
    auto state = serializer.listBegin();
    static foreach(i; 0..V.dimension) {
        serializer.elemBegin;
        serializer.serializeValue(value.vector[i]);
    }
    serializer.listEnd(state);
}

/**
    Serializes any size of matrix
*/
void serialize(T, S)(T matr, ref S serializer) if(isMatrix!T) {
    auto state = serializer.listBegin();
    static foreach(y; 0..T.rows) {
        static foreach(x; 0..T.cols) {
            serializer.elemBegin;
            serializer.serializeValue(matr.matrix[x][y]);
        }
    }
    serializer.listEnd(state);
}

SerdeException deserialize(V)(ref V value, Fghj data) if (isVector!V) {
    int i = 0;
    foreach(val; data.byElement) {
        
        // Some exporters export too many values
        if (i >= value.dimension) break;
        val.deserializeValue(value.vector[i++]);
    }
    return null;
}

bool isEmpty(Fghj value) {
    return value == Fghj.init;
}