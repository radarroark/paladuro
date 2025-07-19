const std = @import("std");
const zlm = @import("zlm");

fn getX(n: f32) f32 {
    return @cos((2 * std.math.pi * n) / 6);
}

fn getY(n: f32) f32 {
    return @sin((2 * std.math.pi * n) / 6);
}

pub const hexagon = [_]f32{
    // back
    getX(2), -0.5, getY(2), // left top from top
    getX(2), 0.5, getY(2), // left top from bottom
    getX(1), -0.5, getY(1), // right top from top
    getX(2), 0.5, getY(2), // left top from bottom
    getX(1), 0.5, getY(1), // right top from bottom
    getX(1), -0.5, getY(1), // right top from top

    // back right
    getX(1), -0.5, getY(1), // right top from top
    getX(1), 0.5, getY(1), // right top from bottom
    getX(0), -0.5, -getY(0), // right from top
    getX(1), 0.5, getY(1), // right top from bottom
    getX(0), 0.5, -getY(0), // right from bottom
    getX(0), -0.5, -getY(0), // right from top

    // front right
    getX(6), -0.5, getY(6), // right from top
    getX(6), 0.5, getY(6), // right from bottom
    getX(5), -0.5, getY(5), // right bottom from top
    getX(6), 0.5, getY(6), // right from bottom
    getX(5), 0.5, getY(5), // right bottom from bottom
    getX(5), -0.5, getY(5), // right bottom from top

    // front
    getX(5), -0.5, getY(5), // right bottom from top
    getX(5), 0.5, getY(5), // right bottom from bottom
    getX(4), -0.5, getY(4), // left bottom from top
    getX(5), 0.5, getY(5), // right bottom from bottom
    getX(4), 0.5, getY(4), // left bottom from bottom
    getX(4), -0.5, getY(4), // left bottom from top

    // front left
    getX(4), -0.5, getY(4), // left bottom from top
    getX(4), 0.5, getY(4), // left bottom from bottom
    getX(3), -0.5, getY(3), // left from top
    getX(4), 0.5, getY(4), // left bottom from bottom
    getX(3), 0.5, getY(3), // left from bottom
    getX(3), -0.5, getY(3), // left from top

    // back left
    getX(2), -0.5, getY(2), // left from top
    getX(2), 0.5, getY(2), // left from bottom
    getX(3), -0.5, getY(3), // left top from top
    getX(2), 0.5, getY(2), // left from bottom
    getX(3), 0.5, getY(3), // left top from bottom
    getX(3), -0.5, getY(3), // left top from top

    // bottom
    // top
    0.0, 0.5, 0.0, // center
    getX(1), 0.5, -getY(1), // right top
    getX(2), 0.5, -getY(2), // left top
    // right top
    0.0, 0.5, 0.0, // center
    getX(0), 0.5, getY(0), // right
    getX(1), 0.5, -getY(1), // right top
    // right bottom
    0.0, 0.5, 0.0, // center
    getX(5), 0.5, -getY(5), // right bottom
    getX(6), 0.5, -getY(6), // right
    // bottom
    0.0, 0.5, 0.0, // center
    getX(4), 0.5, -getY(4), // left bottom
    getX(5), 0.5, -getY(5), // right bottom
    // left bottom
    0.0, 0.5, 0.0, // center
    getX(3), 0.5, -getY(3), // left
    getX(4), 0.5, -getY(4), // left bottom
    // left top
    0.0, 0.5, 0.0, // center
    getX(2), 0.5, -getY(2), // left
    getX(3), 0.5, -getY(3), // left top

    // top
    // top
    0.0, -0.5, 0.0, // center
    getX(1), -0.5, -getY(1), // right top
    getX(2), -0.5, -getY(2), // left top
    // right top
    0.0, -0.5, 0.0, // center
    getX(0), -0.5, getY(0), // right
    getX(1), -0.5, -getY(1), // right top
    // right bottom
    0.0, -0.5, 0.0, // center
    getX(5), -0.5, -getY(5), // right bottom
    getX(6), -0.5, -getY(6), // right
    // bottom
    0.0, -0.5, 0.0, // center
    getX(4), -0.5, -getY(4), // left bottom
    getX(5), -0.5, -getY(5), // right bottom
    // left bottom
    0.0, -0.5, 0.0, // center
    getX(3), -0.5, -getY(3), // left
    getX(4), -0.5, -getY(4), // left bottom
    // left top
    0.0, -0.5, 0.0, // center
    getX(2), -0.5, -getY(2), // left
    getX(3), -0.5, -getY(3), // left top
};

pub const hexagon_sides = [_]u32{
    // back
    0,
    0,
    0,
    0,
    0,
    0,

    // back right
    1,
    1,
    1,
    1,
    1,
    1,

    // front right
    2,
    2,
    2,
    2,
    2,
    2,

    // front
    3,
    3,
    3,
    3,
    3,
    3,

    // front left
    4,
    4,
    4,
    4,
    4,
    4,

    // back left
    5,
    5,
    5,
    5,
    5,
    5,

    // bottom
    6,
    6,
    6,
    6,
    6,
    6,
    6,
    6,
    6,
    6,
    6,
    6,
    6,
    6,
    6,
    6,
    6,
    6,

    // top
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
};

pub const hexagon_texcoords = [_]f32{
    // back
    0, 0,
    0, 1,
    1, 0,
    0, 1,
    1, 1,
    1, 0,

    // back right
    0, 0,
    0, 1,
    1, 0,
    0, 1,
    1, 1,
    1, 0,

    // front right
    0, 0,
    0, 1,
    1, 0,
    0, 1,
    1, 1,
    1, 0,

    // front
    0, 0,
    0, 1,
    1, 0,
    0, 1,
    1, 1,
    1, 0,

    // front left
    0, 0,
    0, 1,
    1, 0,
    0, 1,
    1, 1,
    1, 0,

    // back left
    0, 0,
    0, 1,
    1, 0,
    0, 1,
    1, 1,
    1, 0,

    // bottom
    0, 0,
    0, 1,
    1, 0,
    0, 1,
    1, 1,
    1, 0,
    0, 0,
    0, 1,
    1, 0,
    0, 1,
    1, 1,
    1, 0,
    0, 0,
    0, 1,
    1, 0,
    0, 1,
    1, 1,
    1, 0,

    // top
    0, 0,
    0, 1,
    1, 0,
    1, 0,
    0, 1,
    1, 1,
    0, 0,
    0, 1,
    1, 0,
    1, 0,
    0, 1,
    1, 1,
    0, 0,
    0, 1,
    1, 0,
    1, 0,
    0, 1,
    1, 1,
};
