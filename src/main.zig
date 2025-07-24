const std = @import("std");
const builtin = @import("builtin");
const zlm = @import("./zlm.zig").SpecializeOn(f32);
const shape = @import("./shape.zig");

const c = @cImport({
    @cInclude("glad/gl.h");
    @cInclude("GLFW/glfw3.h");
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

        var base_entity = try initThreeDTextureEntity(allocator, &shape.hexagon, &shape.hexagon_texcoords, &shape.hexagon_sides, tiles_texture);
        errdefer base_entity.uniforms.deinit(allocator);
        errdefer base_entity.attributes.deinit(allocator);

        base_entity.uniforms.setTile(1, 3 * tile_size, 0 * tile_size, tile_size, tile_size); // gravel
        base_entity.uniforms.setTile(2, 0 * tile_size, 3 * tile_size, tile_size, tile_size); // water
        base_entity.uniforms.setTile(3, 4 * tile_size, 0 * tile_size, tile_size, tile_size); // stone

        var uncompiled_grid_entity = try initInstancedThreeDTextureEntity(allocator, base_entity, grid_width * grid_height);
        errdefer uncompiled_grid_entity.uniforms.deinit(allocator);
        errdefer uncompiled_grid_entity.attributes.deinit(allocator);

        var tiles_to_pixels = std.AutoArrayHashMapUnmanaged([2]isize, [2]c.GLfloat){};
        errdefer tiles_to_pixels.deinit(allocator);

        for (0..grid_width) |x| {
            for (0..grid_height) |y| {
                var e = base_entity;

                // duplicate tile data so base entity isn't mutated
                e.uniforms.u_tiles.data = try allocator.dupe(c.GLuint, &.{ 0, 0, 0, 0, 0, 0, 0, 0 });
                defer allocator.free(e.uniforms.u_tiles.data);

                const xx: c.GLfloat = @as(c.GLfloat, @floatFromInt(x)) * hexagon_size * 3 / 4 * 2;
                const y_offset: c.GLfloat = if (@mod(x, 2) == 0) 0 else hexagon_size * @sin(std.math.pi / 3.0);
                const yy: c.GLfloat = @as(c.GLfloat, @floatFromInt(y)) * hexagon_size * @sin(std.math.pi / 3.0) * 2 + y_offset;
                e.uniforms.translate(xx, 0, yy);
                try tiles_to_pixels.put(allocator, .{ @intCast(x), @intCast(y) }, .{ xx, yy });
                e.uniforms.scale(hexagon_size, hexagon_size, hexagon_size);
                if (2 < x and x < 7 and 2 < y and y < 7) {
                    e.uniforms.setSide(.bottom, 2);
                    if (x == 3) {
                        e.uniforms.setSide(.back_left, 3);
                        e.uniforms.setSide(.front_left, 3);
                    } else if (x == 6) {
                        e.uniforms.setSide(.back_right, 3);
                        e.uniforms.setSide(.front_right, 3);
                    }
                    if (y == 3) {
                        e.uniforms.setSide(.front, 3);
                        if (x % 2 == 0) {
                            e.uniforms.setSide(.front_left, 3);
                            e.uniforms.setSide(.front_right, 3);
                        }
                    } else if (y == 6) {
                        e.uniforms.setSide(.back, 3);
                        if (x % 2 == 1) {
                            e.uniforms.setSide(.back_left, 3);
                            e.uniforms.setSide(.back_right, 3);
                        }
                    }
                } else {
                    e.uniforms.setSide(.bottom, 1);
                }
                uncompiled_grid_entity.attributes.set((x * grid_width) + y, e);
            }
        }

        var uncompiled_player_entity = base_entity;
        uncompiled_player_entity.uniforms.scale(hexagon_size, hexagon_size, hexagon_size);
        uncompiled_player_entity.uniforms.setSide(.bottom, 2);

        var self = Game{
            .tiles_texture = tiles_texture,
            .uncompiled_grid_entity = uncompiled_grid_entity,
            .grid_entity = undefined,
            .uncompiled_player_entity = uncompiled_player_entity,
            .player_entity = undefined,
            .tiles_to_pixels = tiles_to_pixels,
        };

        self.grid_entity = try self.compile(.instanced, InstancedThreeDTextureEntityUniforms, InstancedThreeDTextureEntityAttributes, &uncompiled_grid_entity);
        self.player_entity = try self.compile(.array, ThreeDTextureEntityUniforms, ThreeDTextureEntityAttributes, &uncompiled_player_entity);

        return self;
    }

    fn deinit(self: *Game, allocator: std.mem.Allocator) void {
        self.tiles_texture.deinit(allocator);
        self.uncompiled_grid_entity.uniforms.deinit(allocator);
        self.uncompiled_grid_entity.attributes.deinit(allocator);
        self.uncompiled_player_entity.uniforms.deinit(allocator);
        self.uncompiled_player_entity.attributes.deinit(allocator);
        self.tiles_to_pixels.deinit(allocator);
    }

    fn tick(self: *Game) !void {
        c.glClearColor(1, 1, 1, 1);
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);
        c.glViewport(0, 0, self.sizes.window_width, self.sizes.window_height);

        self.player.moveToTarget(game.delta_time, speed);
        self.player.moveToTargetAngle(game.delta_time, speed);

        var camera = zlm.Mat4.identity;
        camera = camera.mul(zlm.Mat4.initTranslate(self.player.x, 0, self.player.y));
        camera = camera.mul(zlm.Mat4.initRotateY(degToRad(self.player.y_angle)));
        camera = camera.mul(zlm.Mat4.initRotateX(degToRad(self.player.x_angle)));
        camera = camera.mul(zlm.Mat4.initTranslate(-@as(f32, @floatFromInt(self.sizes.world_width)) / 2.0, -@as(f32, @floatFromInt(self.sizes.world_height)) / 2.0, 0));

        var e = self.grid_entity;
        e.uniforms.u_matrix.data = e.uniforms.u_matrix.data.mul(zlm.Mat4.initOrthoProject(0, @floatFromInt(self.sizes.world_width), @floatFromInt(self.sizes.world_height), 0, 2048, -2048));
        e.uniforms.u_matrix.data = e.uniforms.u_matrix.data.mul(camera.invert().?);
        e.uniforms.u_matrix.disable = false;
        try self.render(.instanced, InstancedThreeDTextureEntityUniforms, InstancedThreeDTextureEntityAttributes, &e);

        var p = self.player_entity;
        p.uniforms.u_matrix.data = p.uniforms.u_matrix.data.mul(zlm.Mat4.initOrthoProject(0, @floatFromInt(self.sizes.world_width), @floatFromInt(self.sizes.world_height), 0, 2048, -2048));
        p.uniforms.u_matrix.data = p.uniforms.u_matrix.data.mul(camera.invert().?);
        p.uniforms.u_matrix.data = p.uniforms.u_matrix.data.mul(zlm.Mat4.initTranslate(self.player.x, -1 / hexagon_size, self.player.y));
        p.uniforms.u_matrix.disable = false;
        try self.render(.array, ThreeDTextureEntityUniforms, ThreeDTextureEntityAttributes, &p);
    }

    fn compile(
        self: *Game,
        comptime entity_kind: CompiledEntityKind,
        comptime UniT: type,
        comptime AttrT: type,
        uncompiled_entity: *const Entity(.uncompiled, UniT, AttrT),
    ) !Entity(.{ .compiled = entity_kind }, UniT, AttrT) {
        var previous_program: c.GLuint = 0;
        var previous_vao: c.GLuint = 0;
        c.glGetIntegerv(c.GL_CURRENT_PROGRAM, @ptrCast(&previous_program));
        c.glGetIntegerv(c.GL_VERTEX_ARRAY_BINDING, @ptrCast(&previous_vao));

        var result: Entity(.{ .compiled = entity_kind }, UniT, AttrT) = .{
            .uniforms = uncompiled_entity.uniforms,
            .attributes = uncompiled_entity.attributes,
            .extra = .{
                .program = try createProgram(uncompiled_entity.extra.vertex_source, uncompiled_entity.extra.fragment_source),
                .vao = undefined,
                .extra = undefined,
            },
        };
        c.glUseProgram(result.extra.program);
        c.glGenVertexArrays(1, &result.extra.vao);
        c.glBindVertexArray(result.extra.vao);

        inline for (@typeInfo(@TypeOf(result.attributes)).@"struct".fields) |field| {
            @field(result.attributes, field.name).buffer.buffer = initBuffer();
        }

        result.setBuffers();

        inline for (@typeInfo(@TypeOf(result.uniforms)).@"struct".fields) |field| {
            if (!@field(result.uniforms, field.name).disable) {
                try self.callUniform(
                    false,
                    result.extra.program,
                    field.name,
                    @FieldType(@TypeOf(result.uniforms), field.name),
                    &@field(result.uniforms, field.name),
                );
            }
        }

        c.glUseProgram(previous_program);
        c.glBindVertexArray(previous_vao);

        return result;
    }

    fn render(
        self: *Game,
        comptime entity_kind: CompiledEntityKind,
        comptime UniT: type,
        comptime AttrT: type,
        compiled_entity: *Entity(.{ .compiled = entity_kind }, UniT, AttrT),
    ) !void {
        var previous_program: c.GLuint = 0;
        var previous_vao: c.GLuint = 0;
        c.glGetIntegerv(c.GL_CURRENT_PROGRAM, @ptrCast(&previous_program));
        c.glGetIntegerv(c.GL_VERTEX_ARRAY_BINDING, @ptrCast(&previous_vao));

        c.glUseProgram(compiled_entity.extra.program);
        c.glBindVertexArray(compiled_entity.extra.vao);
        compiled_entity.setBuffers();

        inline for (@typeInfo(@TypeOf(compiled_entity.uniforms)).@"struct".fields) |field| {
            if (!@field(compiled_entity.uniforms, field.name).disable) {
                try self.callUniform(
                    true,
                    compiled_entity.extra.program,
                    field.name,
                    @FieldType(@TypeOf(compiled_entity.uniforms), field.name),
                    &@field(compiled_entity.uniforms, field.name),
                );
            }
        }

        switch (entity_kind) {
            .array => c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(compiled_entity.extra.extra.draw_count)),
            .instanced => c.glDrawArraysInstanced(c.GL_TRIANGLES, 0, @intCast(compiled_entity.extra.extra.draw_count), @intCast(compiled_entity.extra.extra.instance_count)),
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

const EntityKind = union(enum) {
    uncompiled,
    compiled: CompiledEntityKind,
};

fn Entity(comptime entity_kind: EntityKind, comptime UniT: type, comptime AttrT: type) type {
    return struct {
        uniforms: UniT,
        attributes: AttrT,
        extra: switch (entity_kind) {
            .uncompiled => struct {
                vertex_source: []const u8,
                fragment_source: []const u8,
            },
            .compiled => |compiled_entity_kind| CompiledEntity(compiled_entity_kind),
        },

        fn setBuffers(self: *Entity(entity_kind, UniT, AttrT)) void {
            comptime std.debug.assert(entity_kind == .compiled);
            inline for (@typeInfo(@TypeOf(self.attributes)).@"struct".fields) |field| {
                if (!@field(self.attributes, field.name).buffer.disable) {
                    self.extra.setBuffer(
                        field.name,
                        @FieldType(@TypeOf(self.attributes), field.name),
                        &@field(self.attributes, field.name),
                    );
                }
            }
        }
    };
}

const CompiledEntityKind = enum {
    array,
    instanced,
};

fn CompiledEntity(comptime entity_kind: CompiledEntityKind) type {
    return struct {
        program: c.GLuint,
        vao: c.GLuint,
        extra: switch (entity_kind) {
            .array => struct {
                draw_count: usize,
            },
            .instanced => struct {
                draw_count: usize,
                instance_count: usize,
            },
        },

        fn setBuffer(self: *CompiledEntity(entity_kind), attr_name: []const u8, comptime T: type, attr: *T) void {
            const draw_count = setProgramAttribute(self.program, attr_name, T, attr);
            switch (entity_kind) {
                .array => switch (attr.divisor) {
                    0 => self.extra.draw_count = draw_count,
                    1 => unreachable,
                },
                .instanced => switch (attr.divisor) {
                    0 => self.extra.draw_count = draw_count,
                    1 => self.extra.instance_count = draw_count,
                },
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

    const Side = enum { back, back_right, front_right, front, front_left, back_left, bottom, top };

    fn deinit(self: *ThreeDTextureEntityUniforms, allocator: std.mem.Allocator) void {
        allocator.free(self.u_texture_matrix.data);
        allocator.free(self.u_tiles.data);
    }

    fn setTile(
        self: *ThreeDTextureEntityUniforms,
        index: usize,
        x: c.GLfloat,
        y: c.GLfloat,
        width: c.GLfloat,
        height: c.GLfloat,
    ) void {
        const tex_width: c.GLfloat = @floatFromInt(self.u_texture.data.opts.width);
        const tex_height: c.GLfloat = @floatFromInt(self.u_texture.data.opts.height);
        var m = zlm.Mat3.initTranslate(x / tex_width, y / tex_height);
        m = m.mul(zlm.Mat3.initScale(width / tex_width, height / tex_height));
        self.u_texture_matrix.data[index] = m;
        self.u_texture_matrix.disable = false;
    }

    fn setSide(self: *ThreeDTextureEntityUniforms, side: Side, index: c.GLuint) void {
        self.u_tiles.data[@intFromEnum(side)] = index;
    }

    fn translate(self: *ThreeDTextureEntityUniforms, x: c.GLfloat, y: c.GLfloat, z: c.GLfloat) void {
        self.u_matrix.data = self.u_matrix.data.mul(zlm.Mat4.initTranslate(x, y, z));
    }

    fn scale(self: *ThreeDTextureEntityUniforms, x: c.GLfloat, y: c.GLfloat, z: c.GLfloat) void {
        self.u_matrix.data = self.u_matrix.data.mul(zlm.Mat4.initScale(x, y, z));
    }
};

const ThreeDTextureEntityAttributes = struct {
    a_position: Attribute(c.GLfloat),
    a_texcoord: Attribute(c.GLfloat),
    a_side: Attribute(c.GLuint),

    fn deinit(self: *ThreeDTextureEntityAttributes, allocator: std.mem.Allocator) void {
        allocator.free(self.a_position.buffer.data);
        allocator.free(self.a_texcoord.buffer.data);
        allocator.free(self.a_side.buffer.data);
    }
};

const UncompiledThreeDTextureEntity = Entity(.uncompiled, ThreeDTextureEntityUniforms, ThreeDTextureEntityAttributes);
const ThreeDTextureEntity = Entity(.{ .compiled = .array }, ThreeDTextureEntityUniforms, ThreeDTextureEntityAttributes);

fn initThreeDTextureEntity(
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

    var result: UncompiledThreeDTextureEntity = .{
        .uniforms = .{
            .u_matrix = .{ .data = zlm.Mat4.identity },
            .u_texture = .{ .data = image },
            .u_texture_matrix = .{ .data = undefined },
            .u_tiles = .{ .data = undefined },
        },
        .attributes = .{
            .a_position = position,
            .a_texcoord = texcoord,
            .a_side = side,
        },
        .extra = .{
            .vertex_source = vertex_shader,
            .fragment_source = fragment_shader,
        },
    };

    const zero = zlm.Mat3{
        .fields = [3][3]f32{
            [3]f32{ 0, 0, 0 },
            [3]f32{ 0, 0, 0 },
            [3]f32{ 0, 0, 0 },
        },
    };
    result.uniforms.u_texture_matrix.data = try allocator.dupe(zlm.Mat3, &.{ zero, zero, zero, zero });
    errdefer allocator.free(result.uniforms.u_texture_matrix.data);

    result.uniforms.u_tiles.data = try allocator.dupe(c.GLuint, &.{ 0, 0, 0, 0, 0, 0, 0, 0 });
    errdefer allocator.free(result.uniforms.u_tiles.data);

    return result;
}

const InstancedThreeDTextureEntityUniforms = struct {
    u_matrix: Uniform(zlm.Mat4),
    u_texture: Uniform(Texture(c.GLubyte)),
    u_texture_matrix: Uniform([]zlm.Mat3),

    fn deinit(self: *InstancedThreeDTextureEntityUniforms, allocator: std.mem.Allocator) void {
        allocator.free(self.u_texture_matrix.data);
    }
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

    fn deinit(self: *InstancedThreeDTextureEntityAttributes, allocator: std.mem.Allocator) void {
        allocator.free(self.a_position.buffer.data);
        allocator.free(self.a_texcoord.buffer.data);
        allocator.free(self.a_side.buffer.data);
        allocator.free(self.a_matrix.buffer.data);
        allocator.free(self.a_tile1.buffer.data);
        allocator.free(self.a_tile2.buffer.data);
        allocator.free(self.a_tile3.buffer.data);
        allocator.free(self.a_tile4.buffer.data);
        allocator.free(self.a_tile5.buffer.data);
        allocator.free(self.a_tile6.buffer.data);
        allocator.free(self.a_tile7.buffer.data);
        allocator.free(self.a_tile8.buffer.data);
    }

    fn set(self: *InstancedThreeDTextureEntityAttributes, index: usize, entity: UncompiledThreeDTextureEntity) void {
        self.a_matrix.buffer.setMat4(index, entity.uniforms.u_matrix);
        self.a_tile1.buffer.set(index, entity.uniforms.u_tiles.data[0]);
        self.a_tile2.buffer.set(index, entity.uniforms.u_tiles.data[1]);
        self.a_tile3.buffer.set(index, entity.uniforms.u_tiles.data[2]);
        self.a_tile4.buffer.set(index, entity.uniforms.u_tiles.data[3]);
        self.a_tile5.buffer.set(index, entity.uniforms.u_tiles.data[4]);
        self.a_tile6.buffer.set(index, entity.uniforms.u_tiles.data[5]);
        self.a_tile7.buffer.set(index, entity.uniforms.u_tiles.data[6]);
        self.a_tile8.buffer.set(index, entity.uniforms.u_tiles.data[7]);
    }
};

const UncompiledInstancedThreeDTextureEntity = Entity(.uncompiled, InstancedThreeDTextureEntityUniforms, InstancedThreeDTextureEntityAttributes);
const InstancedThreeDTextureEntity = Entity(.{ .compiled = .instanced }, InstancedThreeDTextureEntityUniforms, InstancedThreeDTextureEntityAttributes);

fn initInstancedThreeDTextureEntity(allocator: std.mem.Allocator, base_entity: UncompiledThreeDTextureEntity, count: usize) !UncompiledInstancedThreeDTextureEntity {
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
    position.buffer.data = try allocator.dupe(c.GLfloat, base_entity.attributes.a_position.buffer.data);
    errdefer allocator.free(position.buffer.data);

    var texcoord = Attribute(c.GLfloat){ .buffer = .{ .data = undefined }, .size = 2, .iter = 1, .normalize = true };
    texcoord.buffer.data = try allocator.dupe(c.GLfloat, base_entity.attributes.a_texcoord.buffer.data);
    errdefer allocator.free(texcoord.buffer.data);

    var side = Attribute(c.GLuint){ .buffer = .{ .data = undefined }, .size = 1, .iter = 1 };
    side.buffer.data = try allocator.dupe(c.GLuint, base_entity.attributes.a_side.buffer.data);
    errdefer allocator.free(side.buffer.data);

    var result: UncompiledInstancedThreeDTextureEntity = .{
        .uniforms = .{
            .u_matrix = .{ .data = zlm.Mat4.identity },
            .u_texture = base_entity.uniforms.u_texture,
            .u_texture_matrix = .{ .data = undefined },
        },
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
        .extra = .{
            .vertex_source = vertex_shader,
            .fragment_source = fragment_shader,
        },
    };

    result.attributes.a_matrix.buffer.data = try allocator.alloc(c.GLfloat, count * 16);
    errdefer allocator.free(result.attributes.a_matrix.buffer.data);

    result.attributes.a_tile1.buffer.data = try allocator.alloc(c.GLuint, count);
    errdefer allocator.free(result.attributes.a_tile1.buffer.data);

    result.attributes.a_tile2.buffer.data = try allocator.alloc(c.GLuint, count);
    errdefer allocator.free(result.attributes.a_tile2.buffer.data);

    result.attributes.a_tile3.buffer.data = try allocator.alloc(c.GLuint, count);
    errdefer allocator.free(result.attributes.a_tile3.buffer.data);

    result.attributes.a_tile4.buffer.data = try allocator.alloc(c.GLuint, count);
    errdefer allocator.free(result.attributes.a_tile4.buffer.data);

    result.attributes.a_tile5.buffer.data = try allocator.alloc(c.GLuint, count);
    errdefer allocator.free(result.attributes.a_tile5.buffer.data);

    result.attributes.a_tile6.buffer.data = try allocator.alloc(c.GLuint, count);
    errdefer allocator.free(result.attributes.a_tile6.buffer.data);

    result.attributes.a_tile7.buffer.data = try allocator.alloc(c.GLuint, count);
    errdefer allocator.free(result.attributes.a_tile7.buffer.data);

    result.attributes.a_tile8.buffer.data = try allocator.alloc(c.GLuint, count);
    errdefer allocator.free(result.attributes.a_tile8.buffer.data);

    result.uniforms.u_texture_matrix.data = try allocator.dupe(zlm.Mat3, base_entity.uniforms.u_texture_matrix.data);
    errdefer allocator.free(result.uniforms.u_texture_matrix.data);

    return result;
}

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

    if (c.gladLoadGL(c.glfwGetProcAddress) == 0) {
        return error.FailedToLoadGlad;
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
