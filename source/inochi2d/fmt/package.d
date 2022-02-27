/*
    Inochi2D Puppet file format

    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module inochi2d.fmt;
import inochi2d.fmt.binfmt;
public import inochi2d.fmt.serialize;
import inochi2d.core;
import std.bitmanip;
import std.exception;
import std.path;
import std.file;
import std.format;
import imagefmt;

private bool isLoadingINP_ = false;

/**
    Gets whether the current loading state is set to INP loading
*/
bool inIsINPMode() {
    return isLoadingINP_;
}

/**
    Loads a puppet from a file
*/
Puppet inLoadPuppet(string file) {
    ubyte[] buffer = cast(ubyte[])read(file);

    switch(extension(file)) {

        case ".json":
            enforce(!inVerifyMagicBytes(buffer), "Tried loading INP format as JSON format, rename file to .inp extension");
            return inLoadJSONPuppet(cast(string)buffer);

        case ".inp":
            enforce(inVerifyMagicBytes(buffer), "Invalid data format for INP puppet");
            return inLoadINPPuppet(buffer);

        default:
            throw new Exception("Invalid file format of %s at path %s".format(extension(file), file));
    }
}

/**
    Loads a puppet from memory
*/
Puppet inLoadPuppetFromMemory(ubyte[] data) {
    return deserialize!Puppet(cast(string)data);
}

/**
    Loads a JSON based puppet
*/
Puppet inLoadJSONPuppet(string data) {
    isLoadingINP_ = false;
    return inLoadJsonDataFromMemory!Puppet(data);
}

/**
    Loads a INP based puppet
*/
Puppet inLoadINPPuppet(ubyte[] buffer) {
    size_t bufferOffset = 0;
    isLoadingINP_ = true;

    enforce(inVerifyMagicBytes(buffer), "Invalid data format for INP puppet");
    bufferOffset += 8; // Magic bytes are 8 bytes

    // Find the puppet data
    uint puppetDataLength;
    inInterpretDataFromBuffer(buffer[bufferOffset..bufferOffset+=4], puppetDataLength);

    string puppetData = cast(string)buffer[bufferOffset..bufferOffset+=puppetDataLength];

    enforce(inVerifySection(buffer[bufferOffset..bufferOffset+=8], TEX_SECTION), "Expected Texture Blob section, got nothing!");

    // Load textures in to memory
    inBeginTextureLoading();

    // Get amount of slots
    uint slotCount;
    inInterpretDataFromBuffer(buffer[bufferOffset..bufferOffset+=4], slotCount);

    Texture[] slots;
    foreach(i; 0..slotCount) {
        
        uint textureLength;
        inInterpretDataFromBuffer(buffer[bufferOffset..bufferOffset+=4], textureLength);

        ubyte textureType = buffer[bufferOffset++];
        inAddTextureBinary(ShallowTexture(buffer[bufferOffset..bufferOffset+=textureLength]));
    
        // Readd to puppet so that stuff doesn't break if we re-save the puppet
        slots ~= inGetLatestTexture();
    }

    Puppet puppet = inLoadJsonDataFromMemory!Puppet(puppetData);
    puppet.textureSlots = slots;

    puppet.updateTextureState();
    
    inEndTextureLoading();

    if (inVerifySection(buffer[bufferOffset..bufferOffset+=8], EXT_SECTION)) {
        uint sectionCount;
        inInterpretDataFromBuffer(buffer[bufferOffset..bufferOffset+=4], sectionCount);

        foreach(section; 0..sectionCount) {
            import std.json : parseJSON;

            // Get name of payload/vendor extended data
            uint sectionNameLength;
            inInterpretDataFromBuffer(buffer[bufferOffset..bufferOffset+=4], sectionNameLength);            
            string sectionName = cast(string)buffer[bufferOffset..bufferOffset+=sectionNameLength];

            // Get length of data
            uint payloadLength;
            inInterpretDataFromBuffer(buffer[bufferOffset..bufferOffset+=4], payloadLength);

            // Load the vendor JSON data in to the extData section of the puppet
            string payload = cast(string)buffer[bufferOffset..bufferOffset+=payloadLength];
            puppet.extData[sectionName] = parseJSON(payload);
        }
    }
    
    // We're done!
    return puppet;
}

/**
    Writes Inochi2D puppet to file
*/
void inWriteINPPuppet(Puppet p, string file) {
    import inochi2d.ver : IN_VERSION;
    import std.range : appender;
    import std.json : JSONValue;

    isLoadingINP_ = true;
    auto app = appender!(ubyte[]);

    // Write the current used Inochi2D version to the version_ meta tag.
    p.meta.version_ = IN_VERSION;
    string puppetJson = inToJson(p);

    app ~= MAGIC_BYTES;
    app ~= nativeToBigEndian(cast(uint)puppetJson.length)[0..4];
    app ~= cast(ubyte[])puppetJson;
    
    // Begin text section
    app ~= TEX_SECTION;
    app ~= nativeToBigEndian(cast(uint)p.textureSlots.length)[0..4];
    foreach(texture; p.textureSlots) {
        int e;
        ubyte[] tex = write_image_mem(IF_TGA, texture.width, texture.height, texture.getTextureData(), 4, e);
        app ~= nativeToBigEndian(cast(uint)tex.length)[0..4];
        app ~= (cast(ubyte)IN_TEX_TGA);
        app ~= (tex);
    }

    // Begin extended section
    app ~= EXT_SECTION;
    app ~= nativeToBigEndian(cast(uint)p.extData.length)[0..4];

    foreach(name, payload; p.extData) {
        
        // Write payload name and its length
        app ~= nativeToBigEndian(cast(uint)name.length)[0..4];
        app ~= cast(ubyte[])name;

        // Write payload length and payload
        string payloadText = payload.toString;
        app ~= nativeToBigEndian(cast(uint)payloadText.length)[0..4];
        app ~= cast(ubyte[])payloadText;

    }
    

    // Write it out to file
    write(file, app.data);
}

enum IN_TEX_PNG = 0u; /// PNG encoded Inochi2D texture
enum IN_TEX_TGA = 1u; /// TGA encoded Inochi2D texture
enum IN_TEX_BC7 = 2u; /// BC7 encoded Inochi2D texture

/**
    Writes a puppet to file
*/
void inWriteJSONPuppet(Puppet p, string file) {
    isLoadingINP_ = false;
    write(file, inToJson(p));
}