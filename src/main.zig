const std = @import("std");
const builtin = @import("builtin");
const zlm = @import("zlm");

const c = @cImport({
    @cDefine("GLFW_INCLUDE_GLCOREARB", "1");
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GLFW/glfw3.h");
    @cInclude("GL/glcorearb.h");
    @cInclude("stb_image.h");
});

export fn keyCallback(window: ?*c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) void {
    _ = scancode;
    _ = mods;

    if (action == c.GLFW_RELEASE) {
        if (key == c.GLFW_KEY_ESCAPE) {
            c.glfwSetWindowShouldClose(window, c.GLFW_TRUE);
        }
    }
}

const Game = struct {
    tiles_texture: Texture(c.GLubyte),
    base_entity: UncompiledThreeDTextureEntity,

    fn init(allocator: std.mem.Allocator) !Game {
        c.glEnable(c.GL_BLEND);
        c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);
        c.glEnable(c.GL_DEPTH_TEST);

        const tiles_image = @embedFile("assets/tiles.png");
        var tiles_texture = try Texture(c.GLubyte).init(
            allocator,
            tiles_image,
            &.{
                .{ c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE },
                .{ c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE },
                .{ c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST },
                .{ c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST },
            },
            &.{},
            &.{c.GL_TEXTURE_2D},
        );
        errdefer tiles_texture.deinit(allocator);

        var base_entity = try UncompiledThreeDTextureEntity.init(allocator, &.{}, &.{}, &.{}, tiles_texture);
        errdefer base_entity.deinit(allocator);

        return .{
            .tiles_texture = tiles_texture,
            .base_entity = base_entity,
        };
    }

    fn deinit(self: *Game, allocator: std.mem.Allocator) void {
        self.tiles_texture.deinit(allocator);
        self.base_entity.deinit(allocator);
    }

    fn tick(self: *Game) !void {
        _ = self;
        c.glClearColor(173.0 / 255.0, 216.0 / 255.0, 230.0 / 255.0, 1);
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);
    }
};

const TextureOpts = struct {
    mip_level: c.GLint,
    internal_fmt: c.GLenum,
    width: c.GLsizei,
    height: c.GLsizei,
    border: c.GLint,
    src_fmt: c.GLenum,
};

fn Texture(comptime T: type) type {
    return struct {
        image: [*]T,
        opts: TextureOpts,
        params: []const [2]c.GLenum,
        pixel_store_params: []const [2]c.GLenum,
        mipmap_params: []const c.GLenum,
        unit: c.GLint,
        texture_num: c.GLuint,

        fn init(
            allocator: std.mem.Allocator,
            image: []const u8,
            params: []const [2]c.GLenum,
            pixel_store_params: []const [2]c.GLenum,
            mipmap_params: []const c.GLenum,
        ) !Texture(T) {
            var self = Texture(c.GLubyte){
                .image = undefined,
                .opts = .{
                    .mip_level = 0,
                    .internal_fmt = c.GL_RGBA,
                    .width = 0,
                    .height = 0,
                    .border = 0,
                    .src_fmt = c.GL_RGBA,
                },
                .params = undefined,
                .pixel_store_params = undefined,
                .mipmap_params = undefined,
                .unit = 0,
                .texture_num = 0,
            };

            var channels: c_int = 0;
            self.image = c.stbi_load_from_memory(image.ptr, @intCast(image.len), &self.opts.width, &self.opts.height, &channels, 4);
            errdefer c.stbi_image_free(self.image);

            self.params = try allocator.dupe([2]c.GLenum, params);
            errdefer allocator.free(self.params);

            self.pixel_store_params = try allocator.dupe([2]c.GLenum, pixel_store_params);
            errdefer allocator.free(self.pixel_store_params);

            self.mipmap_params = try allocator.dupe(c.GLenum, mipmap_params);
            errdefer allocator.free(self.mipmap_params);

            return self;
        }

        fn deinit(self: *Texture(T), allocator: std.mem.Allocator) void {
            c.stbi_image_free(self.image);
            allocator.free(self.params);
            allocator.free(self.pixel_store_params);
            allocator.free(self.mipmap_params);
        }
    };
}

fn Entity(comptime UniT: type, comptime AttrT: type) type {
    return struct {
        uniforms: UniT,
        attributes: AttrT,
    };
}

fn UncompiledEntity(comptime CompiledT: type, comptime UniT: type, comptime AttrT: type) type {
    return struct {
        entity: Entity(UniT, AttrT),
        vertex_source: []const u8,
        fragment_source: []const u8,

        fn compile(self: UncompiledEntity) CompiledT {
            _ = self;
        }
    };
}

fn CompiledEntity(comptime UniT: type, comptime AttrT: type) type {
    return struct {
        entity: Entity(UniT, AttrT),
        program: c.GLuint,
        vao: c.GLuint,
    };
}

fn ArrayEntity(comptime UniT: type, comptime AttrT: type) type {
    return struct {
        compiled_entity: CompiledEntity(UniT, AttrT),
        draw_count: c.GLsizei,
    };
}

fn Uniform(comptime T: type) type {
    return struct {
        disable: bool = false,
        data: T,
    };
}

fn Buffer(comptime T: type) type {
    return struct {
        disable: bool = false,
        //buffer: c.GLuint,
        data: []T,
    };
}

fn Attribute(comptime T: type) type {
    return struct {
        buffer: Buffer(T),
        size: c.GLint,
        iter: usize,
        normalize: bool = false,
        divisor: u1 = 0,
    };
}

const ThreeDTextureEntityUniforms = struct {
    u_matrix: Uniform(zlm.Mat4),
    u_texture: Uniform(Texture(c.GLubyte)),
    u_texture_matrix: Uniform([]zlm.Mat3),
    u_tiles: Uniform([]c.GLuint),
};

const ThreeDTextureEntityAttributes = struct {
    a_position: Attribute(c.GLfloat),
    a_texcoord: Attribute(c.GLfloat),
    a_side: Attribute(c.GLuint),
};

const ThreeDTextureEntity = ArrayEntity(ThreeDTextureEntityUniforms, ThreeDTextureEntityAttributes);

const UncompiledThreeDTextureEntity = struct {
    uncompiled_entity: UncompiledEntity(ThreeDTextureEntity, ThreeDTextureEntityUniforms, ThreeDTextureEntityAttributes),

    fn init(
        allocator: std.mem.Allocator,
        pos_data: []c.GLfloat,
        texcoord_data: []c.GLfloat,
        side_data: []c.GLuint,
        image: Texture(c.GLubyte),
    ) !UncompiledThreeDTextureEntity {
        const vertex_shader =
            \\#version 330
            \\uniform mat4 u_matrix;
            \\uniform mat3 u_texture_matrix[4];
            \\uniform uint u_tiles[8];
            \\in vec4 a_position;
            \\in vec2 a_texcoord;
            \\in uint a_side;
            \\out vec2 v_texcoord;
            \\void main()
            \\{
            \\  gl_Position = u_matrix * a_position;
            \\  mat3 m = u_texture_matrix[u_tiles[a_side]];
            \\  if (m == mat3(0.0)) {
            \\    v_texcoord = vec2(0.0);
            \\  } else {
            \\    v_texcoord = (m * vec3(a_texcoord, 1)).xy;
            \\  }
            \\}
        ;

        const fragment_shader =
            \\#version 330
            \\precision mediump float;
            \\uniform sampler2D u_texture;
            \\in vec2 v_texcoord;
            \\out vec4 outColor;
            \\void main()
            \\{
            \\  if (v_texcoord == vec2(0.0)) {
            \\    discard;
            \\  } else {
            \\    outColor = texture(u_texture, v_texcoord);
            \\  }
            \\}
        ;

        var position = Attribute(c.GLfloat){ .buffer = .{ .data = undefined }, .size = 3, .iter = 1 };
        position.buffer.data = try allocator.dupe(c.GLfloat, pos_data);
        errdefer allocator.free(position.buffer.data);

        var texcoord = Attribute(c.GLfloat){ .buffer = .{ .data = undefined }, .size = 2, .iter = 1, .normalize = true };
        texcoord.buffer.data = try allocator.dupe(c.GLfloat, texcoord_data);
        errdefer allocator.free(texcoord.buffer.data);

        var side = Attribute(c.GLuint){ .buffer = .{ .data = undefined }, .size = 1, .iter = 1 };
        side.buffer.data = try allocator.dupe(c.GLuint, side_data);
        errdefer allocator.free(side.buffer.data);

        var uncompiled_entity = UncompiledEntity(ThreeDTextureEntity, ThreeDTextureEntityUniforms, ThreeDTextureEntityAttributes){
            .vertex_source = vertex_shader,
            .fragment_source = fragment_shader,
            .entity = .{
                .attributes = .{
                    .a_position = position,
                    .a_texcoord = texcoord,
                    .a_side = side,
                },
                .uniforms = .{
                    .u_matrix = .{ .data = zlm.Mat4.identity },
                    .u_texture = .{ .data = image },
                    .u_texture_matrix = .{ .data = undefined },
                    .u_tiles = .{ .data = undefined },
                },
            },
        };

        const zero = zlm.Mat3{
            .fields = [3][3]f32{
                [3]f32{ 0, 0, 0 },
                [3]f32{ 0, 0, 0 },
                [3]f32{ 0, 0, 0 },
            },
        };
        uncompiled_entity.entity.uniforms.u_texture_matrix.data = try allocator.dupe(zlm.Mat3, &.{ zero, zero, zero, zero });
        errdefer allocator.free(uncompiled_entity.entity.uniforms.u_texture_matrix.data);

        uncompiled_entity.entity.uniforms.u_tiles.data = try allocator.dupe(c.GLuint, &.{ 0, 0, 0, 0, 0, 0, 0, 0 });
        errdefer allocator.free(uncompiled_entity.entity.uniforms.u_tiles.data);

        return .{ .uncompiled_entity = uncompiled_entity };
    }

    fn deinit(self: UncompiledThreeDTextureEntity, allocator: std.mem.Allocator) void {
        allocator.free(self.uncompiled_entity.entity.attributes.a_position.buffer.data);
        allocator.free(self.uncompiled_entity.entity.attributes.a_texcoord.buffer.data);
        allocator.free(self.uncompiled_entity.entity.attributes.a_side.buffer.data);
        allocator.free(self.uncompiled_entity.entity.uniforms.u_texture_matrix.data);
        allocator.free(self.uncompiled_entity.entity.uniforms.u_tiles.data);
    }
};

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    const allocator = if (builtin.mode == .Debug) debug_allocator.allocator() else std.heap.smp_allocator;
    defer if (builtin.mode == .Debug) {
        _ = debug_allocator.deinit();
    };

    if (c.glfwInit() != c.GLFW_TRUE) {
        var desc: [*c]const u8 = null;
        const err = c.glfwGetError(&desc);
        std.debug.print("error: {x} {s}\n", .{ err, desc });
        unreachable;
    }
    defer c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GLFW_TRUE);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
    c.glfwWindowHint(c.GLFW_RESIZABLE, c.GLFW_TRUE);

    const window = c.glfwCreateWindow(1024, 768, "Paladuro", null, null) orelse unreachable;
    defer c.glfwDestroyWindow(window);

    c.glfwMakeContextCurrent(window);
    c.glfwSwapInterval(1);

    _ = c.glfwSetKeyCallback(window, keyCallback);

    var game = try Game.init(allocator);
    defer game.deinit(allocator);

    while (c.glfwWindowShouldClose(window) != c.GLFW_TRUE) {
        try game.tick();
        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
}
