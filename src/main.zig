const std = @import("std");
const builtin = @import("builtin");
const zlm = @import("zlm");
const shape = @import("./shape.zig");

const c = @cImport({
    @cDefine("GLFW_INCLUDE_GLCOREARB", "1");
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    switch (builtin.os.tag) {
        .windows, .macos => @cInclude("glad/gl.h"),
        else => {},
    }
    @cInclude("GLFW/glfw3.h");
    @cInclude("GL/glcorearb.h");
    @cInclude("stb_image.h");
});

var game: Game = undefined;

export fn keyCallback(window: ?*c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) void {
    _ = scancode;
    _ = mods;

    if (action == c.GLFW_RELEASE) {
        const x_angle_delta = 45.0 / 2.0;
        const y_angle_delta = 60.0;
        switch (key) {
            c.GLFW_KEY_ESCAPE => c.glfwSetWindowShouldClose(window, c.GLFW_TRUE),
            c.GLFW_KEY_W => game.player.x_angle_target -= x_angle_delta,
            c.GLFW_KEY_S => game.player.x_angle_target += x_angle_delta,
            c.GLFW_KEY_A, c.GLFW_KEY_LEFT => game.player.setNormalizedYAngle(game.player.y_angle_target - y_angle_delta),
            c.GLFW_KEY_D, c.GLFW_KEY_RIGHT => game.player.setNormalizedYAngle(game.player.y_angle_target + y_angle_delta),
            c.GLFW_KEY_UP, c.GLFW_KEY_DOWN => game.player.setTarget(key),
            else => {},
        }
    }
}

const Sizes = struct {
    density: c_int = 0,
    window_width: c_int = 0,
    window_height: c_int = 0,
    world_width: c_int = 0,
    world_height: c_int = 0,
};

const Player = struct {
    x: f32 = 0,
    y: f32 = 0,
    x_target: f32 = 0,
    y_target: f32 = 0,
    x_tile: isize = 0,
    y_tile: isize = 0,
    x_angle: f32 = -45.0,
    y_angle: f32 = 0,
    x_angle_target: f32 = -45.0,
    y_angle_target: f32 = 0,

    fn setNormalizedYAngle(self: *Player, angle: f32) void {
        if (angle == 360) {
            self.y_angle = -60;
            self.y_angle_target = 0;
        } else if (angle == -60) {
            self.y_angle = 360;
            self.y_angle_target = 300;
        } else {
            self.y_angle_target = angle;
        }
    }

    fn setTarget(self: *Player, key: c_int) void {
        const x_direction: isize = 0;
        const y_direction: isize =
            switch (key) {
                c.GLFW_KEY_UP => 1,
                c.GLFW_KEY_DOWN => -1,
                else => 0,
            };

        const x_tile_diff, const y_tile_diff =
            if (self.y_angle_target == 0)
                .{ x_direction, y_direction }
            else if (self.y_angle_target == 60 and y_direction == 1)
                .{ y_direction, if (@mod(@as(f32, @floatFromInt(self.x_tile)), 2) == 0) 0 else y_direction }
            else if (self.y_angle_target == 60 and y_direction == -1)
                .{ y_direction, if (@mod(@as(f32, @floatFromInt(self.x_tile)), 2) == 0) y_direction else 0 }
            else if (self.y_angle_target == 120 and y_direction == 1)
                .{ y_direction, if (@mod(@as(f32, @floatFromInt(self.x_tile)), 2) == 0) -y_direction else 0 }
            else if (self.y_angle_target == 120 and y_direction == -1)
                .{ y_direction, if (@mod(@as(f32, @floatFromInt(self.x_tile)), 2) == 0) 0 else -y_direction }
            else if (self.y_angle_target == 180)
                .{ -x_direction, -y_direction }
            else if (self.y_angle_target == 240 and y_direction == 1)
                .{ -y_direction, if (@mod(@as(f32, @floatFromInt(self.x_tile)), 2) == 0) -y_direction else 0 }
            else if (self.y_angle_target == 240 and y_direction == -1)
                .{ -y_direction, if (@mod(@as(f32, @floatFromInt(self.x_tile)), 2) == 0) 0 else -y_direction }
            else if (self.y_angle_target == 300 and y_direction == 1)
                .{ -y_direction, if (@mod(@as(f32, @floatFromInt(self.x_tile)), 2) == 0) 0 else y_direction }
            else if (self.y_angle_target == 300 and y_direction == -1)
                .{ -y_direction, if (@mod(@as(f32, @floatFromInt(self.x_tile)), 2) == 0) y_direction else 0 }
            else
                .{ 0, 0 };

        const tile: [2]isize = .{ self.x_tile + x_tile_diff, self.y_tile + y_tile_diff };
        if (game.tiles_to_pixels.get(tile)) |pixels| {
            self.x_tile = tile[0];
            self.x_target = pixels[0];
            self.y_tile = tile[1];
            self.y_target = pixels[1];
        }
    }

    fn moveToTarget(self: *Player, delta_time: f64, speed: f64) void {
        if (self.x == self.x_target and self.y == self.y_target) return;
        const min_diff = 1.0;
        const xdiff = self.x_target - self.x;
        const ydiff = self.y_target - self.y;
        const new_x =
            if (@abs(xdiff) < min_diff)
                self.x_target
            else
                self.x + (xdiff * @min(1.0, delta_time * speed));
        const new_y =
            if (@abs(ydiff) < min_diff)
                self.y_target
            else
                self.y + (ydiff * @min(1.0, delta_time * speed));
        self.x = @floatCast(new_x);
        self.y = @floatCast(new_y);
    }

    fn moveToTargetAngle(self: *Player, delta_time: f64, speed: f64) void {
        if (self.x_angle == self.x_angle_target and self.y_angle == self.y_angle_target) return;
        const min_diff = 1.0;
        const xdiff = self.x_angle_target - self.x_angle;
        const ydiff = self.y_angle_target - self.y_angle;
        const new_x =
            if (@abs(xdiff) < min_diff)
                self.x_angle_target
            else
                self.x_angle + (xdiff * @min(1.0, delta_time * speed));
        const new_y =
            if (@abs(ydiff) < min_diff)
                self.y_angle_target
            else
                self.y_angle + (ydiff * @min(1.0, delta_time * speed));
        self.x_angle = @floatCast(new_x);
        self.y_angle = @floatCast(new_y);
    }
};

export fn frameSizeCallback(window: ?*c.GLFWwindow, width: c_int, height: c_int) void {
    _ = window;
    game.sizes.window_width = width;
    game.sizes.window_height = height;
    game.sizes.world_width = @divTrunc(width, game.sizes.density);
    game.sizes.world_height = @divTrunc(height, game.sizes.density);
}

const Game = struct {
    delta_time: f64 = 0,
    total_time: f64 = 0,
    tex_count: c.GLint = 0,
    tiles_texture: Texture(c.GLubyte),
    uncompiled_grid_entity: UncompiledInstancedThreeDTextureEntity,
    grid_entity: InstancedThreeDTextureEntity,
    uncompiled_player_entity: UncompiledThreeDTextureEntity,
    player_entity: ThreeDTextureEntity,
    tiles_to_pixels: std.AutoArrayHashMapUnmanaged([2]isize, [2]c.GLfloat),
    sizes: Sizes = .{},
    player: Player = .{},

    const tiles_image = @embedFile("assets/tiles.png");
    const tile_size: c.GLfloat = 32;
    const hexagon_size: c.GLfloat = 70;
    const grid_width = 10;
    const grid_height = 10;
    const speed: f64 = 10;

    fn init(allocator: std.mem.Allocator) !Game {
        c.glEnable(c.GL_BLEND);
        c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);
        c.glEnable(c.GL_DEPTH_TEST);

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

        var base_entity = try UncompiledThreeDTextureEntity.init(allocator, &shape.hexagon, &shape.hexagon_texcoords, &shape.hexagon_sides, tiles_texture);
        errdefer base_entity.deinit(allocator);

        base_entity.setTile(1, 3 * tile_size, 0 * tile_size, tile_size, tile_size); // gravel
        base_entity.setTile(2, 0 * tile_size, 3 * tile_size, tile_size, tile_size); // water
        base_entity.setTile(3, 4 * tile_size, 0 * tile_size, tile_size, tile_size); // stone

        var uncompiled_grid_entity = try UncompiledInstancedThreeDTextureEntity.init(allocator, base_entity, grid_width * grid_height);
        errdefer uncompiled_grid_entity.deinit(allocator);

        var tiles_to_pixels = std.AutoArrayHashMapUnmanaged([2]isize, [2]c.GLfloat){};
        errdefer tiles_to_pixels.deinit(allocator);

        for (0..grid_width) |x| {
            for (0..grid_height) |y| {
                var e = base_entity;

                // duplicate tile data so base entity isn't mutated
                e.uncompiled_entity.entity.uniforms.u_tiles.data = try allocator.dupe(c.GLuint, &.{ 0, 0, 0, 0, 0, 0, 0, 0 });
                defer allocator.free(e.uncompiled_entity.entity.uniforms.u_tiles.data);

                const xx: c.GLfloat = @as(c.GLfloat, @floatFromInt(x)) * hexagon_size * 3 / 4 * 2;
                const y_offset: c.GLfloat = if (@mod(x, 2) == 0) 0 else hexagon_size * @sin(std.math.pi / 3.0);
                const yy: c.GLfloat = @as(c.GLfloat, @floatFromInt(y)) * hexagon_size * @sin(std.math.pi / 3.0) * 2 + y_offset;
                e.translate(xx, 0, yy);
                try tiles_to_pixels.put(allocator, .{ @intCast(x), @intCast(y) }, .{ xx, yy });
                e.scale(hexagon_size, hexagon_size, hexagon_size);
                if (2 < x and x < 7 and 2 < y and y < 7) {
                    e.setSide(.bottom, 2);
                    if (x == 3) {
                        e.setSide(.back_left, 3);
                        e.setSide(.front_left, 3);
                    } else if (x == 6) {
                        e.setSide(.back_right, 3);
                        e.setSide(.front_right, 3);
                    }
                    if (y == 3) {
                        e.setSide(.front, 3);
                        if (x % 2 == 0) {
                            e.setSide(.front_left, 3);
                            e.setSide(.front_right, 3);
                        }
                    } else if (y == 6) {
                        e.setSide(.back, 3);
                        if (x % 2 == 1) {
                            e.setSide(.back_left, 3);
                            e.setSide(.back_right, 3);
                        }
                    }
                } else {
                    e.setSide(.bottom, 1);
                }
                uncompiled_grid_entity.set((x * grid_width) + y, e);
            }
        }

        var uncompiled_player_entity = base_entity;
        uncompiled_player_entity.scale(hexagon_size, hexagon_size, hexagon_size);
        uncompiled_player_entity.setSide(.bottom, 2);

        var self = Game{
            .tiles_texture = tiles_texture,
            .uncompiled_grid_entity = uncompiled_grid_entity,
            .grid_entity = undefined,
            .uncompiled_player_entity = uncompiled_player_entity,
            .player_entity = undefined,
            .tiles_to_pixels = tiles_to_pixels,
        };

        self.grid_entity = try self.compile(InstancedThreeDTextureEntity, InstancedThreeDTextureEntityUniforms, InstancedThreeDTextureEntityAttributes, uncompiled_grid_entity.uncompiled_entity);
        self.player_entity = try self.compile(ThreeDTextureEntity, ThreeDTextureEntityUniforms, ThreeDTextureEntityAttributes, uncompiled_player_entity.uncompiled_entity);

        return self;
    }

    fn deinit(self: *Game, allocator: std.mem.Allocator) void {
        self.tiles_texture.deinit(allocator);
        self.uncompiled_grid_entity.deinit(allocator);
        self.uncompiled_player_entity.deinit(allocator);
        self.tiles_to_pixels.deinit(allocator);
    }

    fn tick(self: *Game) !void {
        c.glClearColor(1, 1, 1, 1);
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);
        c.glViewport(0, 0, self.sizes.window_width, self.sizes.window_height);

        self.player.moveToTarget(game.delta_time, speed);
        self.player.moveToTargetAngle(game.delta_time, speed);

        var camera = zlm.Mat4.identity;
        camera = camera.mul(translateMat4(self.player.x, 0, self.player.y));
        camera = camera.mul(rotateYMat4(degToRad(self.player.y_angle)));
        camera = camera.mul(rotateXMat4(degToRad(self.player.x_angle)));
        camera = camera.mul(translateMat4(-@as(f32, @floatFromInt(self.sizes.world_width)) / 2.0, -@as(f32, @floatFromInt(self.sizes.world_height)) / 2.0, 0));

        var e = self.grid_entity;
        e.compiled_entity.entity.uniforms.u_matrix.data = e.compiled_entity.entity.uniforms.u_matrix.data.mul(projectMat4(0, @floatFromInt(self.sizes.world_width), @floatFromInt(self.sizes.world_height), 0, 2048, -2048));
        e.compiled_entity.entity.uniforms.u_matrix.data = e.compiled_entity.entity.uniforms.u_matrix.data.mul(camera.invert().?);
        e.compiled_entity.entity.uniforms.u_matrix.disable = false;
        try self.render(InstancedThreeDTextureEntityUniforms, InstancedThreeDTextureEntityAttributes, &e);

        var p = self.player_entity;
        p.compiled_entity.entity.uniforms.u_matrix.data = p.compiled_entity.entity.uniforms.u_matrix.data.mul(projectMat4(0, @floatFromInt(self.sizes.world_width), @floatFromInt(self.sizes.world_height), 0, 2048, -2048));
        p.compiled_entity.entity.uniforms.u_matrix.data = p.compiled_entity.entity.uniforms.u_matrix.data.mul(camera.invert().?);
        p.compiled_entity.entity.uniforms.u_matrix.data = p.compiled_entity.entity.uniforms.u_matrix.data.mul(translateMat4(self.player.x, -1 / hexagon_size, self.player.y));
        p.compiled_entity.entity.uniforms.u_matrix.disable = false;
        try self.render(ThreeDTextureEntityUniforms, ThreeDTextureEntityAttributes, &p);
    }

    fn compile(
        self: *Game,
        comptime CompiledT: type,
        comptime UniT: type,
        comptime AttrT: type,
        uncompiled_entity: UncompiledEntity(CompiledT, UniT, AttrT),
    ) !CompiledT {
        var previous_program: c.GLuint = 0;
        var previous_vao: c.GLuint = 0;
        c.glGetIntegerv(c.GL_CURRENT_PROGRAM, @ptrCast(&previous_program));
        c.glGetIntegerv(c.GL_VERTEX_ARRAY_BINDING, @ptrCast(&previous_vao));

        var result: CompiledT = undefined;
        result.compiled_entity.program = try createProgram(uncompiled_entity.vertex_source, uncompiled_entity.fragment_source);
        c.glUseProgram(result.compiled_entity.program);
        c.glGenVertexArrays(1, &result.compiled_entity.vao);
        c.glBindVertexArray(result.compiled_entity.vao);
        result.compiled_entity.entity.attributes = uncompiled_entity.entity.attributes;
        result.compiled_entity.entity.uniforms = uncompiled_entity.entity.uniforms;

        inline for (@typeInfo(@TypeOf(result.compiled_entity.entity.attributes)).@"struct".fields) |field| {
            @field(result.compiled_entity.entity.attributes, field.name).buffer.buffer = initBuffer();
        }

        result.setBuffers();

        inline for (@typeInfo(@TypeOf(result.compiled_entity.entity.uniforms)).@"struct".fields) |field| {
            if (!@field(result.compiled_entity.entity.uniforms, field.name).disable) {
                try self.callUniform(
                    false,
                    result.compiled_entity.program,
                    field.name,
                    @FieldType(@TypeOf(result.compiled_entity.entity.uniforms), field.name),
                    &@field(result.compiled_entity.entity.uniforms, field.name),
                );
            }
        }

        c.glUseProgram(previous_program);
        c.glBindVertexArray(previous_vao);

        return result;
    }

    fn render(self: *Game, comptime UniT: type, comptime AttrT: type, entity: anytype) !void {
        var previous_program: c.GLuint = 0;
        var previous_vao: c.GLuint = 0;
        c.glGetIntegerv(c.GL_CURRENT_PROGRAM, @ptrCast(&previous_program));
        c.glGetIntegerv(c.GL_VERTEX_ARRAY_BINDING, @ptrCast(&previous_vao));

        c.glUseProgram(entity.compiled_entity.program);
        c.glBindVertexArray(entity.compiled_entity.vao);
        entity.setBuffers();

        inline for (@typeInfo(@TypeOf(entity.compiled_entity.entity.uniforms)).@"struct".fields) |field| {
            if (!@field(entity.compiled_entity.entity.uniforms, field.name).disable) {
                try self.callUniform(
                    true,
                    entity.compiled_entity.program,
                    field.name,
                    @FieldType(@TypeOf(entity.compiled_entity.entity.uniforms), field.name),
                    &@field(entity.compiled_entity.entity.uniforms, field.name),
                );
            }
        }

        switch (@TypeOf(entity)) {
            *ArrayEntity(UniT, AttrT) => c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(entity.draw_count)),
            *InstancedEntity(UniT, AttrT) => c.glDrawArraysInstanced(c.GL_TRIANGLES, 0, @intCast(entity.draw_count), @intCast(entity.instance_count)),
            else => unreachable,
        }

        c.glUseProgram(previous_program);
        c.glBindVertexArray(previous_vao);
    }

    fn callUniform(
        self: *Game,
        comptime compiled: bool,
        program: c.GLuint,
        uni_name: []const u8,
        comptime T: type,
        uni: *T,
    ) !void {
        switch (uni.InnerType) {
            zlm.Mat4 => {
                const loc = c.glGetUniformLocation(program, uni_name.ptr);
                if (loc == -1) unreachable;
                c.glUniformMatrix4fv(loc, 1, c.GL_TRUE, @ptrCast(&uni.data));
                uni.disable = true;
            },
            Texture(c.GLubyte) => {
                if (compiled) {
                    const loc = c.glGetUniformLocation(program, uni_name.ptr);
                    if (loc == -1) unreachable;
                    c.glUniform1i(loc, uni.data.unit);
                    uni.disable = true;
                } else {
                    const loc = c.glGetUniformLocation(program, uni_name.ptr);
                    if (loc == -1) unreachable;
                    const unit = self.createTexture(c.GLubyte, uni.data);
                    uni.data.unit = unit;
                    // TODO: we don't need to hold on to the texture anymore
                    c.glUniform1i(loc, uni.data.unit);
                    uni.disable = true;
                }
            },
            []zlm.Mat3 => {
                const loc = c.glGetUniformLocation(program, uni_name.ptr);
                if (loc == -1) unreachable;
                c.glUniformMatrix3fv(loc, @intCast(uni.data.len), c.GL_TRUE, @ptrCast(&uni.data[0]));
                uni.disable = true;
            },
            []c.GLuint => {
                const loc = c.glGetUniformLocation(program, uni_name.ptr);
                if (loc == -1) unreachable;
                c.glUniform1uiv(loc, @intCast(uni.data.len), &uni.data[0]);
                uni.disable = true;
            },
            else => unreachable,
        }
    }

    fn createTexture(self: *Game, comptime T: type, texture: Texture(T)) c.GLint {
        const unit = self.tex_count;
        self.tex_count += 1;
        var texture_num: c.GLuint = 0;
        c.glGenTextures(1, &texture_num);
        c.glActiveTexture(@intCast(c.GL_TEXTURE0 + unit));
        c.glBindTexture(c.GL_TEXTURE_2D, texture_num);
        for (texture.params) |param| {
            c.glTexParameteri(c.GL_TEXTURE_2D, param[0], @intCast(param[1]));
        }
        for (texture.pixel_store_params) |param| {
            c.glPixelStorei(param[0], @intCast(param[1]));
        }
        const src_type = getTypeEnum(T);
        c.glTexImage2D(
            c.GL_TEXTURE_2D,
            texture.opts.mip_level,
            @intCast(texture.opts.internal_fmt),
            texture.opts.width,
            texture.opts.height,
            texture.opts.border,
            texture.opts.src_fmt,
            src_type,
            &texture.image[0],
        );
        for (texture.mipmap_params) |param| {
            c.glGenerateMipmap(param);
        }
        return unit;
    }
};

fn degToRad(degrees: c.GLfloat) c.GLfloat {
    return (degrees * std.math.pi) / 180.0;
}

fn initBuffer() c.GLuint {
    var result: c.GLuint = 0;
    c.glGenBuffers(1, &result);
    return result;
}

fn checkShaderStatus(shader: c.GLuint) !void {
    var params: c.GLint = 0;
    c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &params);
    if (params != c.GL_TRUE) {
        return error.InvalidShaderStatus;
    }
}

fn createShader(shader_type: c.GLenum, source: []const u8) !c.GLuint {
    const result = c.glCreateShader(shader_type);
    c.glShaderSource(result, 1, &source.ptr, null);
    c.glCompileShader(result);
    try checkShaderStatus(result);
    return result;
}

fn checkProgramStatus(program: c.GLuint) !void {
    var params: c.GLint = 0;
    c.glGetProgramiv(program, c.GL_LINK_STATUS, &params);
    if (params != c.GL_TRUE) {
        return error.InvalidProgramStatus;
    }
}

fn createProgram(v_source: []const u8, f_source: []const u8) !c.GLuint {
    const v_shader = try createShader(c.GL_VERTEX_SHADER, v_source);
    const f_shader = try createShader(c.GL_FRAGMENT_SHADER, f_source);
    const result = c.glCreateProgram();
    c.glAttachShader(result, v_shader);
    c.glAttachShader(result, f_shader);
    c.glLinkProgram(result);
    c.glDeleteShader(v_shader);
    c.glDeleteShader(f_shader);
    try checkProgramStatus(result);
    return result;
}

fn getTypeEnum(comptime T: type) c.GLenum {
    return switch (T) {
        c.GLfloat => c.GL_FLOAT,
        c.GLint => c.GL_INT,
        c.GLuint => c.GL_UNSIGNED_INT,
        c.GLshort => c.GL_SHORT,
        c.GLushort => c.GL_UNSIGNED_SHORT,
        c.GLbyte => c.GL_BYTE,
        c.GLubyte => c.GL_UNSIGNED_BYTE,
        else => unreachable,
    };
}

fn setProgramAttribute(program: c.GLuint, attrib_name: []const u8, comptime T: type, attr: *T) usize {
    const total_size = @as(usize, @intCast(attr.size)) * attr.iter;
    const result: usize = attr.buffer.data.len / total_size;
    var previous_buffer: c.GLint = 0;
    c.glGetIntegerv(c.GL_ARRAY_BUFFER_BINDING, &previous_buffer);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, attr.buffer.buffer);
    if (attr.buffer.data.len > 0) {
        c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(@sizeOf(attr.InnerType) * attr.buffer.data.len), &attr.buffer.data[0], c.GL_STATIC_DRAW);
    } else {
        unreachable;
    }
    const kind = getTypeEnum(attr.InnerType);
    const attrib_location: c.GLuint = @intCast(c.glGetAttribLocation(program, attrib_name.ptr));
    for (0..attr.iter) |i| {
        const loc = attrib_location + @as(c.GLuint, @intCast(i));
        c.glEnableVertexAttribArray(loc);
        if (attr.InnerType == c.GLfloat) {
            c.glVertexAttribPointer(
                loc,
                attr.size,
                kind,
                if (attr.normalize) c.GL_TRUE else c.GL_FALSE,
                @intCast(@sizeOf(attr.InnerType) * total_size),
                @ptrFromInt(@sizeOf(attr.InnerType) * i * @as(c.GLuint, @intCast(attr.size))),
            );
        } else {
            c.glVertexAttribIPointer(
                loc,
                attr.size,
                kind,
                @intCast(@sizeOf(attr.InnerType) * total_size),
                @ptrFromInt(@sizeOf(attr.InnerType) * i * @as(c.GLuint, @intCast(attr.size))),
            );
        }
        c.glVertexAttribDivisor(loc, attr.divisor);
    }
    c.glBindBuffer(c.GL_ARRAY_BUFFER, @intCast(previous_buffer));
    return result;
}

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
    _ = CompiledT;
    return struct {
        entity: Entity(UniT, AttrT),
        vertex_source: []const u8,
        fragment_source: []const u8,
    };
}

fn CompiledEntity(comptime UniT: type, comptime AttrT: type) type {
    return struct {
        entity: Entity(UniT, AttrT),
        program: c.GLuint,
        vao: c.GLuint,

        fn setAttribute(self: CompiledEntity(UniT, AttrT), attr_name: []const u8, comptime T: type, attr: *T) usize {
            return setProgramAttribute(self.program, attr_name, T, attr);
        }
    };
}

fn ArrayEntity(comptime UniT: type, comptime AttrT: type) type {
    return struct {
        compiled_entity: CompiledEntity(UniT, AttrT),
        draw_count: usize,

        fn setBuffers(self: *ArrayEntity(UniT, AttrT)) void {
            inline for (@typeInfo(@TypeOf(self.compiled_entity.entity.attributes)).@"struct".fields) |field| {
                if (!@field(self.compiled_entity.entity.attributes, field.name).buffer.disable) {
                    self.setBuffer(
                        field.name,
                        @FieldType(@TypeOf(self.compiled_entity.entity.attributes), field.name),
                        &@field(self.compiled_entity.entity.attributes, field.name),
                    );
                }
            }
        }

        fn setBuffer(self: *ArrayEntity(UniT, AttrT), attr_name: []const u8, comptime T: type, attr: *T) void {
            const draw_count = self.compiled_entity.setAttribute(attr_name, T, attr);
            if (attr.divisor == 0) {
                self.draw_count = draw_count;
            }
            attr.buffer.disable = true;
        }
    };
}

fn InstancedEntity(comptime UniT: type, comptime AttrT: type) type {
    return struct {
        compiled_entity: CompiledEntity(UniT, AttrT),
        draw_count: usize,
        instance_count: usize,

        fn setBuffers(self: *InstancedEntity(UniT, AttrT)) void {
            inline for (@typeInfo(@TypeOf(self.compiled_entity.entity.attributes)).@"struct".fields) |field| {
                if (!@field(self.compiled_entity.entity.attributes, field.name).buffer.disable) {
                    self.setBuffer(
                        field.name,
                        @FieldType(@TypeOf(self.compiled_entity.entity.attributes), field.name),
                        &@field(self.compiled_entity.entity.attributes, field.name),
                    );
                }
            }
        }

        fn setBuffer(self: *InstancedEntity(UniT, AttrT), attr_name: []const u8, comptime T: type, attr: *T) void {
            const draw_count = self.compiled_entity.setAttribute(attr_name, T, attr);
            if (attr.divisor == 0) {
                self.draw_count = draw_count;
            } else if (attr.divisor == 1) {
                self.instance_count = draw_count;
            }
            attr.buffer.disable = true;
        }
    };
}

fn Uniform(comptime T: type) type {
    return struct {
        disable: bool = false,
        data: T,

        comptime InnerType: type = T,
    };
}

fn Buffer(comptime T: type) type {
    return struct {
        disable: bool = false,
        buffer: c.GLuint = 0,
        data: []T,

        fn set(self: *Buffer(T), index: usize, uni: T) void {
            self.data[index] = uni;
            self.disable = false;
        }

        fn setMat4(self: *Buffer(f32), index: usize, uni: Uniform(zlm.Mat4)) void {
            const m = uni.data.transpose();
            for (0..4) |row| {
                for (0..4) |col| {
                    self.data[row * 4 + col + index * 16] = m.fields[row][col];
                }
            }
            self.disable = false;
        }
    };
}

fn Attribute(comptime T: type) type {
    return struct {
        buffer: Buffer(T),
        size: c.GLint,
        iter: usize,
        normalize: bool = false,
        divisor: u1 = 0,

        comptime InnerType: type = T,
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

    const Side = enum { back, back_right, front_right, front, front_left, back_left, bottom, top };

    fn init(
        allocator: std.mem.Allocator,
        pos_data: []const c.GLfloat,
        texcoord_data: []const c.GLfloat,
        side_data: []const c.GLuint,
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

    fn setTile(
        self: *UncompiledThreeDTextureEntity,
        index: usize,
        x: c.GLfloat,
        y: c.GLfloat,
        width: c.GLfloat,
        height: c.GLfloat,
    ) void {
        const tex_width: c.GLfloat = @floatFromInt(self.uncompiled_entity.entity.uniforms.u_texture.data.opts.width);
        const tex_height: c.GLfloat = @floatFromInt(self.uncompiled_entity.entity.uniforms.u_texture.data.opts.height);
        var m = translateMat3(x / tex_width, y / tex_height);
        m = mulMat3(m, scaleMat3(width / tex_width, height / tex_height));
        self.uncompiled_entity.entity.uniforms.u_texture_matrix.data[index] = m;
        self.uncompiled_entity.entity.uniforms.u_texture_matrix.disable = false;
    }

    fn setSide(self: *UncompiledThreeDTextureEntity, side: Side, index: c.GLuint) void {
        self.uncompiled_entity.entity.uniforms.u_tiles.data[@intFromEnum(side)] = index;
    }

    fn translate(self: *UncompiledThreeDTextureEntity, x: c.GLfloat, y: c.GLfloat, z: c.GLfloat) void {
        self.uncompiled_entity.entity.uniforms.u_matrix.data = self.uncompiled_entity.entity.uniforms.u_matrix.data.mul(translateMat4(x, y, z));
    }

    fn scale(self: *UncompiledThreeDTextureEntity, x: c.GLfloat, y: c.GLfloat, z: c.GLfloat) void {
        self.uncompiled_entity.entity.uniforms.u_matrix.data = self.uncompiled_entity.entity.uniforms.u_matrix.data.mul(scaleMat4(x, y, z));
    }
};

fn translateMat3(x: f32, y: f32) zlm.Mat3 {
    return .{
        .fields = [3][3]f32{
            [3]f32{ 1, 0, x },
            [3]f32{ 0, 1, y },
            [3]f32{ 0, 0, 1 },
        },
    };
}

fn translateMat4(x: f32, y: f32, z: f32) zlm.Mat4 {
    return .{
        .fields = [4][4]f32{
            [4]f32{ 1, 0, 0, x },
            [4]f32{ 0, 1, 0, y },
            [4]f32{ 0, 0, 1, z },
            [4]f32{ 0, 0, 0, 1 },
        },
    };
}

fn scaleMat3(x: f32, y: f32) zlm.Mat3 {
    return .{
        .fields = [3][3]f32{
            [3]f32{ x, 0, 0 },
            [3]f32{ 0, y, 0 },
            [3]f32{ 0, 0, 1 },
        },
    };
}

fn scaleMat4(x: f32, y: f32, z: f32) zlm.Mat4 {
    return .{
        .fields = [4][4]f32{
            [4]f32{ x, 0, 0, 0 },
            [4]f32{ 0, y, 0, 0 },
            [4]f32{ 0, 0, z, 0 },
            [4]f32{ 0, 0, 0, 1 },
        },
    };
}

fn mulMat3(a: zlm.Mat3, b: zlm.Mat3) zlm.Mat3 {
    var result: zlm.Mat3 = undefined;
    inline for (0..3) |row| {
        inline for (0..3) |col| {
            var sum: f32 = 0.0;
            inline for (0..3) |i| {
                sum += a.fields[row][i] * b.fields[i][col];
            }
            result.fields[row][col] = sum;
        }
    }
    return result;
}

fn rotateXMat4(angle: f32) zlm.Mat4 {
    const cos = @cos(angle);
    const sin = @sin(angle);
    return .{
        .fields = [4][4]f32{
            [4]f32{ 1, 0, 0, 0 },
            [4]f32{ 0, cos, -sin, 0 },
            [4]f32{ 0, sin, cos, 0 },
            [4]f32{ 0, 0, 0, 1 },
        },
    };
}

fn rotateYMat4(angle: f32) zlm.Mat4 {
    const cos = @cos(angle);
    const sin = @sin(angle);
    return .{
        .fields = [4][4]f32{
            [4]f32{ cos, 0, sin, 0 },
            [4]f32{ 0, 1, 0, 0 },
            [4]f32{ -sin, 0, cos, 0 },
            [4]f32{ 0, 0, 0, 1 },
        },
    };
}

fn projectMat4(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) zlm.Mat4 {
    const width = right - left;
    const height = top - bottom;
    const depth = near - far;
    return .{
        .fields = [4][4]f32{
            [4]f32{ 2 / width, 0, 0, (left + right) / (left - right) },
            [4]f32{ 0, 2 / height, 0, (bottom + top) / (bottom - top) },
            [4]f32{ 0, 0, 2 / depth, (near + far) / (near - far) },
            [4]f32{ 0, 0, 0, 1 },
        },
    };
}

const InstancedThreeDTextureEntityUniforms = struct {
    u_matrix: Uniform(zlm.Mat4),
    u_texture: Uniform(Texture(c.GLubyte)),
    u_texture_matrix: Uniform([]zlm.Mat3),
};

const InstancedThreeDTextureEntityAttributes = struct {
    a_position: Attribute(c.GLfloat),
    a_texcoord: Attribute(c.GLfloat),
    a_matrix: Attribute(c.GLfloat),
    a_side: Attribute(c.GLuint),
    a_tile1: Attribute(c.GLuint),
    a_tile2: Attribute(c.GLuint),
    a_tile3: Attribute(c.GLuint),
    a_tile4: Attribute(c.GLuint),
    a_tile5: Attribute(c.GLuint),
    a_tile6: Attribute(c.GLuint),
    a_tile7: Attribute(c.GLuint),
    a_tile8: Attribute(c.GLuint),
};

const InstancedThreeDTextureEntity = InstancedEntity(InstancedThreeDTextureEntityUniforms, InstancedThreeDTextureEntityAttributes);

const UncompiledInstancedThreeDTextureEntity = struct {
    uncompiled_entity: UncompiledEntity(InstancedThreeDTextureEntity, InstancedThreeDTextureEntityUniforms, InstancedThreeDTextureEntityAttributes),

    fn init(allocator: std.mem.Allocator, base_entity: UncompiledThreeDTextureEntity, count: usize) !UncompiledInstancedThreeDTextureEntity {
        const vertex_shader =
            \\#version 330
            \\uniform mat4 u_matrix;
            \\uniform mat3 u_texture_matrix[4];
            \\in vec4 a_position;
            \\in vec2 a_texcoord;
            \\in uint a_side;
            \\in uint a_tile1;
            \\in uint a_tile2;
            \\in uint a_tile3;
            \\in uint a_tile4;
            \\in uint a_tile5;
            \\in uint a_tile6;
            \\in uint a_tile7;
            \\in uint a_tile8;
            \\in mat4 a_matrix;
            \\out vec2 v_texcoord;
            \\void main()
            \\{
            \\  gl_Position = u_matrix * a_matrix * a_position;
            \\  uint tile;
            \\  if (a_side == uint(0)) {
            \\    tile = a_tile1;
            \\  } else if (a_side == uint(1)) {
            \\    tile = a_tile2;
            \\  } else if (a_side == uint(2)) {
            \\    tile = a_tile3;
            \\  } else if (a_side == uint(3)) {
            \\    tile = a_tile4;
            \\  } else if (a_side == uint(4)) {
            \\    tile = a_tile5;
            \\  } else if (a_side == uint(5)) {
            \\    tile = a_tile6;
            \\  } else if (a_side == uint(6)) {
            \\    tile = a_tile7;
            \\  } else if (a_side == uint(7)) {
            \\    tile = a_tile8;
            \\  }
            \\  mat3 m = u_texture_matrix[tile];
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
        position.buffer.data = try allocator.dupe(c.GLfloat, base_entity.uncompiled_entity.entity.attributes.a_position.buffer.data);
        errdefer allocator.free(position.buffer.data);

        var texcoord = Attribute(c.GLfloat){ .buffer = .{ .data = undefined }, .size = 2, .iter = 1, .normalize = true };
        texcoord.buffer.data = try allocator.dupe(c.GLfloat, base_entity.uncompiled_entity.entity.attributes.a_texcoord.buffer.data);
        errdefer allocator.free(texcoord.buffer.data);

        var side = Attribute(c.GLuint){ .buffer = .{ .data = undefined }, .size = 1, .iter = 1 };
        side.buffer.data = try allocator.dupe(c.GLuint, base_entity.uncompiled_entity.entity.attributes.a_side.buffer.data);
        errdefer allocator.free(side.buffer.data);

        var uncompiled_entity = UncompiledEntity(InstancedThreeDTextureEntity, InstancedThreeDTextureEntityUniforms, InstancedThreeDTextureEntityAttributes){
            .vertex_source = vertex_shader,
            .fragment_source = fragment_shader,
            .entity = .{
                .attributes = .{
                    .a_position = position,
                    .a_texcoord = texcoord,
                    .a_side = side,
                    .a_matrix = .{ .buffer = .{ .data = undefined, .disable = true }, .divisor = 1, .size = 4, .iter = 4 },
                    .a_tile1 = .{ .buffer = .{ .data = undefined, .disable = true }, .divisor = 1, .size = 1, .iter = 1 },
                    .a_tile2 = .{ .buffer = .{ .data = undefined, .disable = true }, .divisor = 1, .size = 1, .iter = 1 },
                    .a_tile3 = .{ .buffer = .{ .data = undefined, .disable = true }, .divisor = 1, .size = 1, .iter = 1 },
                    .a_tile4 = .{ .buffer = .{ .data = undefined, .disable = true }, .divisor = 1, .size = 1, .iter = 1 },
                    .a_tile5 = .{ .buffer = .{ .data = undefined, .disable = true }, .divisor = 1, .size = 1, .iter = 1 },
                    .a_tile6 = .{ .buffer = .{ .data = undefined, .disable = true }, .divisor = 1, .size = 1, .iter = 1 },
                    .a_tile7 = .{ .buffer = .{ .data = undefined, .disable = true }, .divisor = 1, .size = 1, .iter = 1 },
                    .a_tile8 = .{ .buffer = .{ .data = undefined, .disable = true }, .divisor = 1, .size = 1, .iter = 1 },
                },
                .uniforms = .{
                    .u_matrix = .{ .data = zlm.Mat4.identity },
                    .u_texture = base_entity.uncompiled_entity.entity.uniforms.u_texture,
                    .u_texture_matrix = .{ .data = undefined },
                },
            },
        };

        uncompiled_entity.entity.attributes.a_matrix.buffer.data = try allocator.alloc(c.GLfloat, count * 16);
        errdefer allocator.free(uncompiled_entity.entity.attributes.a_matrix.buffer.data);

        uncompiled_entity.entity.attributes.a_tile1.buffer.data = try allocator.alloc(c.GLuint, count);
        errdefer allocator.free(uncompiled_entity.entity.attributes.a_tile1.buffer.data);

        uncompiled_entity.entity.attributes.a_tile2.buffer.data = try allocator.alloc(c.GLuint, count);
        errdefer allocator.free(uncompiled_entity.entity.attributes.a_tile2.buffer.data);

        uncompiled_entity.entity.attributes.a_tile3.buffer.data = try allocator.alloc(c.GLuint, count);
        errdefer allocator.free(uncompiled_entity.entity.attributes.a_tile3.buffer.data);

        uncompiled_entity.entity.attributes.a_tile4.buffer.data = try allocator.alloc(c.GLuint, count);
        errdefer allocator.free(uncompiled_entity.entity.attributes.a_tile4.buffer.data);

        uncompiled_entity.entity.attributes.a_tile5.buffer.data = try allocator.alloc(c.GLuint, count);
        errdefer allocator.free(uncompiled_entity.entity.attributes.a_tile5.buffer.data);

        uncompiled_entity.entity.attributes.a_tile6.buffer.data = try allocator.alloc(c.GLuint, count);
        errdefer allocator.free(uncompiled_entity.entity.attributes.a_tile6.buffer.data);

        uncompiled_entity.entity.attributes.a_tile7.buffer.data = try allocator.alloc(c.GLuint, count);
        errdefer allocator.free(uncompiled_entity.entity.attributes.a_tile7.buffer.data);

        uncompiled_entity.entity.attributes.a_tile8.buffer.data = try allocator.alloc(c.GLuint, count);
        errdefer allocator.free(uncompiled_entity.entity.attributes.a_tile8.buffer.data);

        uncompiled_entity.entity.uniforms.u_texture_matrix.data = try allocator.dupe(zlm.Mat3, base_entity.uncompiled_entity.entity.uniforms.u_texture_matrix.data);
        errdefer allocator.free(uncompiled_entity.entity.uniforms.u_texture_matrix.data);

        return .{ .uncompiled_entity = uncompiled_entity };
    }

    fn deinit(self: UncompiledInstancedThreeDTextureEntity, allocator: std.mem.Allocator) void {
        allocator.free(self.uncompiled_entity.entity.attributes.a_position.buffer.data);
        allocator.free(self.uncompiled_entity.entity.attributes.a_texcoord.buffer.data);
        allocator.free(self.uncompiled_entity.entity.attributes.a_side.buffer.data);
        allocator.free(self.uncompiled_entity.entity.attributes.a_matrix.buffer.data);
        allocator.free(self.uncompiled_entity.entity.attributes.a_tile1.buffer.data);
        allocator.free(self.uncompiled_entity.entity.attributes.a_tile2.buffer.data);
        allocator.free(self.uncompiled_entity.entity.attributes.a_tile3.buffer.data);
        allocator.free(self.uncompiled_entity.entity.attributes.a_tile4.buffer.data);
        allocator.free(self.uncompiled_entity.entity.attributes.a_tile5.buffer.data);
        allocator.free(self.uncompiled_entity.entity.attributes.a_tile6.buffer.data);
        allocator.free(self.uncompiled_entity.entity.attributes.a_tile7.buffer.data);
        allocator.free(self.uncompiled_entity.entity.attributes.a_tile8.buffer.data);
        allocator.free(self.uncompiled_entity.entity.uniforms.u_texture_matrix.data);
    }

    fn set(self: *UncompiledInstancedThreeDTextureEntity, index: usize, entity: UncompiledThreeDTextureEntity) void {
        self.uncompiled_entity.entity.attributes.a_matrix.buffer.setMat4(index, entity.uncompiled_entity.entity.uniforms.u_matrix);
        self.uncompiled_entity.entity.attributes.a_tile1.buffer.set(index, entity.uncompiled_entity.entity.uniforms.u_tiles.data[0]);
        self.uncompiled_entity.entity.attributes.a_tile2.buffer.set(index, entity.uncompiled_entity.entity.uniforms.u_tiles.data[1]);
        self.uncompiled_entity.entity.attributes.a_tile3.buffer.set(index, entity.uncompiled_entity.entity.uniforms.u_tiles.data[2]);
        self.uncompiled_entity.entity.attributes.a_tile4.buffer.set(index, entity.uncompiled_entity.entity.uniforms.u_tiles.data[3]);
        self.uncompiled_entity.entity.attributes.a_tile5.buffer.set(index, entity.uncompiled_entity.entity.uniforms.u_tiles.data[4]);
        self.uncompiled_entity.entity.attributes.a_tile6.buffer.set(index, entity.uncompiled_entity.entity.uniforms.u_tiles.data[5]);
        self.uncompiled_entity.entity.attributes.a_tile7.buffer.set(index, entity.uncompiled_entity.entity.uniforms.u_tiles.data[6]);
        self.uncompiled_entity.entity.attributes.a_tile8.buffer.set(index, entity.uncompiled_entity.entity.uniforms.u_tiles.data[7]);
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
    _ = c.glfwSetFramebufferSizeCallback(window, frameSizeCallback);

    switch (builtin.os.tag) {
        .windows, .macos => if (c.gladLoadGL(c.glfwGetProcAddress) == 0) {
            return error.FailedToLoadGlad;
        },
        else => {},
    }

    game = try Game.init(allocator);
    defer game.deinit(allocator);

    var width: c_int = 0;
    var height: c_int = 0;
    c.glfwGetFramebufferSize(window, &width, &height);

    var window_width: c_int = 0;
    var window_height: c_int = 0;
    c.glfwGetWindowSize(window, &window_width, &window_height);

    game.sizes.density = @max(1, @divTrunc(width, window_width));
    frameSizeCallback(window, width, height);

    while (c.glfwWindowShouldClose(window) != c.GLFW_TRUE) {
        const ts = c.glfwGetTime();
        game.delta_time = ts - game.total_time;
        game.total_time = ts;
        try game.tick();
        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
}
