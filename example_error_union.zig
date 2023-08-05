const std = @import("std");
const treeFormatter = @import("./src/tree_fmt.zig").treeFormatter;

pub fn main() !void {
    var w = std.io.getStdOut().writer();
    var tree_printer = treeFormatter(std.heap.page_allocator, w);
    try tree_printer.format(getMyStructNotError(), .{ .name = "error_union_not_error" });
    try tree_printer.format(getMyStructError(), .{ .name = "error_union_error" });
}

fn getMyStructNotError() !MyStruct {
    return MyStruct{};
}

fn getMyStructError() !MyStruct {
    return error.HiYouGotAnError;
}

const MyStruct = struct {
    a: []const u8 = "hi",
    b: u32 = 987,
};
