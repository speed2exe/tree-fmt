const std = @import("std");
const reset = "\x1b[m";

pub fn comptimeFmtInColor(
    comptime color: Color,
    comptime fmt: []const u8,
    args: anytype,
) []const u8 {
    return std.fmt.comptimePrint(color.toEscapeCode() ++ fmt ++ reset, args);
}

pub fn comptimeInColor(
    comptime color: Color,
    comptime fmt: []const u8,
) []const u8 {
    return comptime color.toEscapeCode() ++ fmt ++ reset;
}

pub const Color = enum {
    bright_black,
    cyan,
    yellow,
    blue,
    green,

    inline fn toEscapeCode(self: Color) []const u8 {
        return switch (self) {
            inline .bright_black => "\x1b[90m",
            inline .cyan => "\x1b[36m",
            inline .yellow => "\x1b[33m",
            inline .blue => "\x1b[34m",
            inline .green => "\x1b[32m",
        };
    }
};
