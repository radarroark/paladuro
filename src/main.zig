const std = @import("std");

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

const tiles_image = @embedFile("assets/tiles.png");

fn init() !void {
    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);
    c.glEnable(c.GL_DEPTH_TEST);

    var width: c_int = 0;
    var height: c_int = 0;
    var channels: c_int = 0;
    _ = c.stbi_load_from_memory(tiles_image, tiles_image.len, &width, &height, &channels, 4);
}

fn tick() !void {
    c.glClearColor(173.0 / 255.0, 216.0 / 255.0, 230.0 / 255.0, 1);
    c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);
}

pub fn main() !void {
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

    try init();

    while (c.glfwWindowShouldClose(window) != c.GLFW_TRUE) {
        try tick();
        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
}
