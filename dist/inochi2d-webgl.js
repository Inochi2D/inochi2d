const __basic_vert = `#version 300 es
/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
precision mediump float;

layout(location = 0) in vec2 verts;
layout(location = 1) in vec2 uvs;
uniform mat4 modelViewMatrix;

out vec2 texUVs;
out vec2 ndcTexCoords;

void main() {
    texUVs = uvs;

    vec4 vertexCoords = modelViewMatrix * vec4(verts.x, verts.y, 0, 1);

    // Normalized device coordinates go from -1..+1,
    // but texture sampling goes from 0..1, so we need to
    // remap the ndc coordinates to texture coordinates.
    ndcTexCoords = (vertexCoords.xy * 0.5 + vertexCoords.w * 0.5) / vertexCoords.w;
    gl_Position = vertexCoords;
}`;

const __basic_frag = `#version 300 es
/*
    Copyright © 2020, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
precision mediump float;

in vec2 texUVs;
in vec2 ndcTexCoords;

layout(location = 0) out vec4 outAlbedo;
layout(location = 1) out vec4 outEmission;
layout(location = 2) out vec4 outBumpmap;
uniform sampler2D mask;
uniform sampler2D albedo;
uniform sampler2D emission;
uniform sampler2D bumpmap;

vec4 screen(vec4 inColor, vec3 screenColor) {
    return vec4(vec3(1.0) - ((vec3(1.0)-inColor.rgb) * (vec3(1.0)-(screenColor*inColor.a))), inColor.a);
}

void main() {
    vec4 inAlbedo = texture(albedo, texUVs);
    vec4 inEmission = texture(emission, texUVs);
    vec4 inBumpmap = texture(bumpmap, texUVs);

    outAlbedo = inAlbedo;
    outEmission = inEmission * outAlbedo.aaaa;
    outBumpmap = inBumpmap * outAlbedo.aaaa;
}
`;

let tag_store = {
    counter: 1,
    tags: new Map(),
    next() {
        return tag_store.counter++;
    },
    store(key, value) {
        tag_store.tags[key] = value;
    },
    get(key) {
        if (tag_store.tags.has(key))
            return tag_store.tags[key];
        return null;
    }
}


/**
    A tagged OpenGL object.    
*/
class GLObject {
    #handle;
    #id;
    #gl;

    /**
        Handle of this object.
    */
    get handle() { return this.#handle; }

    /**
        GL Instance of this object.
    */
    get gl() { return this.#gl; }

    /**
        ID of this object.
    */
    get id() { return this.#id; }

    /**
        Constructs a new GL object from an ID.
    */
    constructor(gl, handle) {
        this.#handle = handle;
        this.#id = tag_store.next();
        this.#gl = gl;

        tag_store.store(this, this.#id);
    }
}

class GLTexture extends GLObject {
    #width;
    #height;
    #format;

    /**
        Width of this texture.
    */
    get width() { return this.#width; }

    /**
        Height of this texture.
    */
    get height() { return this.#height; }

    /**
        Format of this texture.
    */
    get format() { return this.#format; }

    /**
        Constructs an empty gl texture.
    */
    constructor(gl, handle, width, height, format) {
        super(gl, handle);
        this.#width = width;
        this.#height = height;
        this.#format = format;
    }

    /**
        Creates an empty texture for the given gl context.
    */
    static createEmpty(gl, width, height, format) {
        let handle = gl.createTexture();
        gl.bindTexture(gl.TEXTURE_2D, handle);
        gl.texImage2D(
            gl.TEXTURE_2D,
            0,
            format,
            width,
            height,
            0,
            format,
            gl.UNSIGNED_BYTE,
            null
        );
        return new GLTexture(gl, handle, width, height, format);
    }

    /**
        Creates a texture from an Inochi2D texture.
    */
    static fromInTexture(gl, texture) {
        let handle = gl.createTexture();
        gl.bindTexture(gl.TEXTURE_2D, handle);
        gl.texImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RGBA,
            texture.width,
            texture.height,
            0,
            gl.RGBA,
            gl.UNSIGNED_BYTE,
            texture.bytes
        );
        gl.generateMipmap(gl.TEXTURE_2D);
        return new GLTexture(gl, handle, texture.width, texture.height, gl.RGBA);
    }

    /**
        Resizes the texture
    */
    resize(width, height) {
        if (width == this.#width && height == this.#height)
            return;

        this.#width = width;
        this.#height = height;
        this.gl.bindTexture(this.gl.TEXTURE_2D, this.handle);
        this.gl.texImage2D(
            this.gl.TEXTURE_2D,
            0,
            this.#format,
            this.#width,
            this.#height,
            0,
            this.#format,
            this.gl.UNSIGNED_BYTE,
            null
        );
        this.gl.generateMipmap(gl.TEXTURE_2D);
    }

    bind(slot) {
        this.gl.activeTexture(this.gl.TEXTURE0+slot);
        this.gl.bindTexture(this.gl.TEXTURE_2D, this.handle);
    }
}

class GLFramebuffer extends GLObject {
    #width;
    #height;
    #textures;

    /**
        Width of this texture.
    */
    get width() { return this.#width; }

    /**
        Height of this texture.
    */
    get height() { return this.#height; }

    /**
        Constructs a new framebuffer.
    */
    constructor(gl, width, height) {
        super(gl, gl.createFramebuffer());
        this.#textures = new Array();
        this.resize(width, height);
    }

    /**
        Resizes this framebuffer.
    */
    resize(width, height) {
        if (width == this.#width && height == this.#height)
            return;

        this.#width = width;
        this.#height = height;
        this.gl.bindFramebuffer(this.gl.FRAMEBUFFER, this.handle);
        let i = 0;
        for (let texture of this.#textures) {
            texture.resize(width, height);
            this.gl.framebufferTexture2D(
                this.gl.FRAMEBUFFER,
                this.gl.COLOR_ATTACHMENT0+i,
                this.gl.TEXTURE_2D,
                texture.id,
                0
            );
            i++;
        }
    }

    /**
        Attaches a GLTexture to this framebuffer.
    */
    attach(texture) {
        this.#textures.push(texture);
        this.gl.bindFramebuffer(this.gl.FRAMEBUFFER, this.handle);
        this.gl.framebufferTexture2D(
            this.gl.FRAMEBUFFER,
            this.gl.COLOR_ATTACHMENT0+(this.#textures.length-1),
            this.gl.TEXTURE_2D,
            texture.handle,
            0
        );
    }

    /**
        Makes this framebuffer active.
    */
    use() {
        this.gl.bindFramebuffer(this.gl.FRAMEBUFFER, this.handle);
    }

    /**
        Blits to the given framebuffer id
    */
    blitTo(fb) {
        if (fb != null) {
            this.gl.bindFramebuffer(this.gl.READ_FRAMEBUFFER, this.handle);
            this.gl.bindFramebuffer(this.gl.DRAW_FRAMEBUFFER, fb.handle)
            this.gl.blitFramebuffer(0, 0, this.width, this.height, 0, 0, fb.width, fb.height, this.gl.COLOR_BUFFER_BIT, this.gl.LINEAR);
            return;
        }

        this.gl.bindFramebuffer(this.gl.READ_FRAMEBUFFER, this.handle);
        this.gl.bindFramebuffer(this.gl.DRAW_FRAMEBUFFER, null);
        this.gl.blitFramebuffer(0, 0, this.width, this.height, 0, 0, this.width, this.height, this.gl.COLOR_BUFFER_BIT, this.gl.LINEAR);
    }
}




//
//          MATH PRIMITIVES
//

/**
    Multiplies this matrix
*/
function mat4_mul(lhs, rhs) {
    let result = mat4.zero;
    for (let r = 0; r < 4; r++) {
        for (let c = 0; c < 4; c++) {
            for (let c2 = 0; c2 < 4; c2++) {
                result[(r*4)+c] += lhs[(r*4)+c2] + lhs[(c2*4)+c];
            }
        }    
    }
    return result;
}

class mat4 {
    #data;

    /**
        The data stored within the matrix.
    */
    get data() { return this.#data; }

    /**
        Identity matrix.
    */
    static get identity() {
        return new mat4([
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1
        ]);
    }

    /**
        Zero matrix.
    */
    static get zero() {
        return new mat4([
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0
        ]);
    }

    /**
        Constructs a new matrix.
    */
    constructor(data) {
        this.#data = new Float32Array(data);
        return new Proxy(this, {
            get: (obj, key) => {
                if (typeof(key) === 'string' && (Number.isInteger(Number(key))))
                    return obj.#data[key]
                else
                    return obj[key]
            },
            set: (obj, key, value) => {
                obj.#data[key] = value;
                return true;
            }
        });
    }

    /**
        Creates a translation matrix.
    */
    static translation(x, y, z) {
        return new mat4([
            1, 0, 0, x,
            0, 1, 0, y,
            0, 0, 1, z,
            0, 0, 0, 1
        ]);
    }

    /**
        Creates a scaling matrix.
    */
    static scaling(x, y, z) {
        return new mat4([
            x, 0, 0, 0,
            0, y, 0, 0,
            0, 0, z, 0,
            0, 0, 0, 1
        ]);
    }

    /**
        Creates an orthographic projection matrix
    */
    static ortho(left, right, bottom, top, near, far) {
        var M = mat4.identity;

        // Make sure there is no division by zero
        if (left === right || bottom === top || near === far) {
            return M;
        }

        var widthRatio  = 1.0 / (right - left);
        var heightRatio = 1.0 / (top - bottom);
        var depthRatio  = 1.0 / (far - near);

        var sx = 2 * widthRatio;
        var sy = 2 * heightRatio;
        var sz = -2 * depthRatio;

        var tx = -(right + left) * widthRatio;
        var ty = -(top + bottom) * heightRatio;
        var tz = -(far + near) * depthRatio;

        M[0] = sx;  M[4] = 0;   M[8] = 0;   M[12] = tx;
        M[1] = 0;   M[5] = sy;  M[9] = 0;   M[13] = ty;
        M[2] = 0;   M[6] = 0;   M[10] = sz; M[14] = tz;
        M[3] = 0;   M[7] = 0;   M[11] = 0;  M[15] = 1;
        return M;
    }

    /**
        Translates the matrix.
    */
    translate(x, y, z) {
        return mat4_mul(mat4.translation(x, y, z), this);
    }

    /**
        Scales the matrix.
    */
    scale(x, y, z) {
        return mat4_mul(mat4.scaling(x, y, z), this);
    }
}




//
//          RENDERER
//

/**
    An OpenGL Scene    
*/
class InGLScene {
    #canvas;
    #gl;
    #puppets;




    //
    //      RENDER STATE
    //
    #basic_shader;
    #vbo;
    #ibo;
    #ubo;




    //
    //      FRAMEBUFFER STACK
    //
    #fbidx;     // Current framebuffer index.
    #maskfb;    // Mask framebuffer.
    #mainfb;
    #compfbs;   // Composite framebuffers.

    // Push framebuffer to stack, creating a new one if needed.
    #push_fb() {
        this.#fbidx++;
        if (this.#fbidx+1 >= this.#compfbs.length) {
            this.#compfbs.push(this.#make_fb());
        }

        this.#compfbs[this.#fbidx-1].use();
    }

    // Pops a framebuffer from the framebuffer stack.
    #pop_fb() {
        if (this.#fbidx > 0)
            this.#fbidx--;

        if (this.#fbidx > 0)
            this.#compfbs[this.#fbidx-1].use();
        else
            this.#mainfb.use();
    }

    #make_fb() {
        let newfb = new GLFramebuffer(this.#gl, this.#canvas.width, this.#canvas.height);
        for (let i = 0; i < IN_MAX_ATTACHMENTS; i++) {
            newfb.attach(GLTexture.createEmpty(this.#gl, this.#canvas.width, this.#canvas.height, this.#gl.RGBA));
        }
        return newfb;
    }




    //
    //      SHADERS
    //
    #make_shader(vert, frag) {
        let vtx = this.#gl.createShader(this.#gl.VERTEX_SHADER);
        let frg = this.#gl.createShader(this.#gl.FRAGMENT_SHADER);

        // Compile
        this.#gl.shaderSource(vtx, vert);
        this.#gl.compileShader(vtx);
        this.#gl.shaderSource(frg, frag);
        this.#gl.compileShader(frg);
    
        // Link
        let prog = this.#gl.createProgram();
        this.#gl.attachShader(prog, vtx);
        this.#gl.attachShader(prog, frg);
        this.#gl.linkProgram(prog);

        return prog;
    }


    /**
        Constructs a new OpenGL scene for the given canvas
        element.
    */
    constructor(canvas) {
        this.#gl = canvas.getContext("webgl2");
        if (!this.#gl)
            throw Error("WebGL 2 is not supported on this device.");

        // Set up core state
        this.#puppets = new Array();
        this.#canvas = canvas;
        this.#compfbs = new Array();
        this.#maskfb = this.#make_fb();
        this.#mainfb = this.#make_fb();
        this.#basic_shader = this.#make_shader(__basic_vert, __basic_frag);

        // Create buffers.
        this.#vbo = this.#gl.createBuffer();
        this.#ibo = this.#gl.createBuffer();
        this.#ubo = this.#gl.createBuffer();

        // Bind buffers.
        this.#gl.bindBuffer(this.#gl.ARRAY_BUFFER, this.#vbo);
        this.#gl.bindBuffer(this.#gl.ELEMENT_ARRAY_BUFFER, this.#ibo);
        this.#gl.bindBuffer(this.#gl.UNIFORM_BUFFER, this.#ubo);
        this.#gl.bufferData(
            this.#gl.UNIFORM_BUFFER, 
            new Uint8ClampedArray(64), 
            this.#gl.DYNAMIC_DRAW
        );

        // Enable vertex attributes
        this.#gl.enableVertexAttribArray(0);
        this.#gl.enableVertexAttribArray(1);

        // Set attribute pointers.
        this.#gl.vertexAttribPointer(0, 3, this.#gl.FLOAT, false, IN_VTXDATA_SIZE, 0);
        this.#gl.vertexAttribPointer(1, 2, this.#gl.FLOAT, false, IN_VTXDATA_SIZE, IN_VTXDATA_UV_OFFSET);
    }

    /**
        Adds a puppet to the scene.
    */
    addPuppet(puppet) {

        // Add textures to texture map.
        for (let texture of puppet.textures) {
            texture.id = GLTexture.fromInTexture(this.#gl, texture).id;
        }

        // Add puppet to scene.
        this.#puppets.push(puppet);
        console.info("Loaded puppet \"" + puppet.name + "\" by \"" + puppet.author + "\"...");
    }

    /**
        Updates and draws the scene.
    */
    updateAndDraw(delta) {

        // Call on_frame call-back if user attached one.
        if (this["_on_frame"])
            this["_on_frame"](this, delta);

        this.#gl.viewport(0, 0, this.#canvas.width, this.#canvas.height);
        this.#gl.clearColor(0, 0, 0, 0);
        this.#gl.clear(this.#gl.COLOR_BUFFER_BIT);
        this.#gl.enable(this.#gl.BLEND);

        let mvMatrix = mat4
            .ortho(0, this.#canvas.width, this.#canvas.height, 0, 0.001, 1000)
            .translate(-(this.#canvas.width/2), -(this.#canvas.height/2), -500);

        this.#gl.useProgram(this.#basic_shader);
        this.#gl.uniform1i(this.#gl.getUniformLocation(this.#basic_shader, "mask"), 0);
        this.#gl.uniform1i(this.#gl.getUniformLocation(this.#basic_shader, "albedo"), 1);
        this.#gl.uniform1i(this.#gl.getUniformLocation(this.#basic_shader, "emission"), 2);
        this.#gl.uniformMatrix4fv(
            this.#gl.getUniformLocation(this.#basic_shader, "modelViewMatrix"), 
            true, 
            mvMatrix.data
        );

        this.#gl.bindBuffer(this.#gl.ARRAY_BUFFER, this.#vbo);
        this.#gl.bindBuffer(this.#gl.ELEMENT_ARRAY_BUFFER, this.#ibo);
        this.#gl.bindBuffer(this.#gl.UNIFORM_BUFFER, this.#ubo);


        for (var puppet of this.#puppets) {
            puppet.update(delta);
            puppet.draw(delta);

            // Reset neccesary state.
            this.#fbidx = 0;

            // Upload puppet data.
            this.#gl.bufferData(this.#gl.ARRAY_BUFFER, puppet.drawList.vertexData, this.#gl.DYNAMIC_DRAW);
            this.#gl.bufferData(this.#gl.ELEMENT_ARRAY_BUFFER, puppet.drawList.indexData, this.#gl.DYNAMIC_DRAW);

            // // Clear mask fb.
            // this.#maskfb.use();
            // this.#gl.clearColor(1, 1, 1, 1);
            // this.#gl.clear(this.#gl.COLOR_BUFFER_BIT);

            // // Clear main fb.
            // this.#mainfb.use();
            // this.#gl.clearColor(0, 0, 0, 0);
            // this.#gl.clear(this.#gl.COLOR_BUFFER_BIT);

            this.#gl.bindFramebuffer(this.#gl.FRAMEBUFFER, null);

            // Execute draw commands.
            for (let cmd of puppet.drawList.commands) {
                if (cmd.elemCount == 0)
                    continue;

                // console.log(cmd);

                switch(cmd.state) {
                case IN_DRAW_STATE_NORMAL:
                    for (let i = 0; i < cmd.sources.length; i++) {
                        let tex = tag_store.get(cmd.sources[i]);
                        if (tex != null)
                            tex.bind(i+1);
                    }
                    this.#gl.drawElements(
                        this.#gl.TRIANGLES,
                        cmd.elemCount,
                        this.#gl.UNSIGNED_INT, 
                        cmd.idxOffset*4
                    );
                    break;
                case IN_DRAW_STATE_DEFINE_MASK:
                    break;
                case IN_DRAW_STATE_MASKED_DRAW:
                    break;
                case IN_DRAW_STATE_COMPOSITE_BEGIN:
                    this.#push_fb();
                    break;
                case IN_DRAW_STATE_COMPOSITE_END:
                    this.#pop_fb();
                    break;
                case IN_DRAW_STATE_COMPOSITE_BLIT:
                    break;
                }
            }

            // this.#gl.blendFunc(this.#gl.ONE, this.#gl.ONE_MINUS_SRC_ALPHA);
            // this.#mainfb.blitTo(null);
        }
    }
}




//
//      BOOTSTRAP
//
document.addEventListener("DOMContentLoaded", function(event) {
    in_init().then(() => {

        // Create scenes for every canvas tagged "inochi2d"
        for (let canvas of document.getElementsByTagName("canvas")) {
            if (canvas.className == "inochi2d") {
                canvas.scene = new InGLScene(canvas);

                // Look for "puppet" dom nodes.
                for (let puppet of canvas.getElementsByTagName("puppet")) {
                    
                    let src = puppet.getAttribute("src");
                    if (src == null) {
                        console.error("puppet node", puppet, "lacks a src reference");
                        break;
                    }

                    // Allow user to set an animation to play on loop.
                    let anim_play  = puppet.getAttribute("animation");
                    let anim_loop  = puppet.getAttribute("loop")?.toLowerCase?.() === 'true';
                    let anim_count = puppet.getAttribute("count") ? parseFloat(puppet.getAttribute("count")) : 0;

                    // Allow user to call a JS callback.
                    let on_frame = puppet.getAttribute("onframe");

                    InPuppet.fromUrl(src).then((puppet) => {
                        puppet["_play_anim"] = anim_play;
                        puppet["_loop_anim"] = anim_loop;
                        puppet["_loop_count"] = anim_count;
                        puppet["_on_frame"] = on_frame != null ? window[on_frame] : null;
                        canvas.scene.addPuppet(puppet);
                    });
                }
            }
        }

        let _prev_time = 0;
        function _in_render_loop(time) {
            let delta = (time-_prev_time)*0.0001;

            for (let canvas of document.getElementsByTagName("canvas")) {
                if (canvas.className == "inochi2d") {
                    canvas.scene.updateAndDraw(delta);
                }
            }

            _prev_time = time;
            requestAnimationFrame(_in_render_loop);
        }

        _in_render_loop(0.016);
        console.info("Inochi2D WebGL initialized...");
    });
});