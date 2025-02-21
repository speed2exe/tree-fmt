const std = @import("std");
const builtin = std.builtin;

const TreeFormatterSettings = @import("./tree-fmt.zig").TreeFormatterSettings;

const ansi_esc_code = @import("./ansi-esc-code.zig");
const Color = ansi_esc_code.Color;
const comptimeFmtInColor = ansi_esc_code.comptimeFmtInColor;
const comptimeInColor = ansi_esc_code.comptimeInColor;

pub fn treeFormatter(
    allocator: std.mem.Allocator,
    std_io_writer: anytype,
) TreeFormatter(@TypeOf(std_io_writer)) {
    return .{
        .allocator = allocator,
        .writer = std_io_writer,
    };
}

pub fn TreeFormatter(comptime StdIoWriter: type) type {
    return struct {
        const Self = @This();

        const arrow = comptimeFmtInColor(Color.bright_black, "=>", .{});
        const empty = " " ++ arrow ++ " .{}";
        const address_fmt = comptimeInColor(Color.blue, "@{x}");
        const not_shown = comptimeInColor(Color.bright_black, " (not shown)");
        const indent_blank = "  ";
        const indent_bar = "│ ";
        const ptr_repeat_reached = comptimeInColor(Color.bright_black, " ...(Repeat Limit Reached)");
        const ptr_repeat = comptimeInColor(Color.bright_black, " (Repeated)");
        const pointer_dereference = comptimeInColor(Color.yellow, ".*");
        const optional_unwrap = comptimeInColor(Color.yellow, ".?");
        const slice_method = comptimeInColor(Color.green, ".slice()");
        const items_method = comptimeInColor(Color.green, ".items()");
        const get_method = comptimeInColor(Color.green, ".get()");
        const iterator_method = comptimeInColor(Color.green, ".iterator()");
        const next_method = comptimeInColor(Color.green, ".next()");
        const ChildPrefix = enum {
            non_last,
            last,
            fn bytes(self: ChildPrefix) []const u8 {
                return switch (self) {
                    .non_last => "├─",
                    .last => "└─",
                };
            }
        };

        /// type to keep count of number of times address of the same value appear
        const CountsByAddress = std.AutoHashMap(usize, usize);

        allocator: std.mem.Allocator,
        writer: StdIoWriter,

        pub fn init(
            allocator: std.mem.Allocator,
            writer: StdIoWriter,
            settings: TreeFormatterSettings,
        ) TreeFormatter {
            return TreeFormatter{
                .allocator = allocator,
                .settings = settings,
                .writer = writer,
            };
        }

        pub fn format(self: Self, arg: anytype, settings: TreeFormatterSettings) !void {
            var prefix = std.ArrayList(u8).init(self.allocator);
            defer prefix.deinit();
            var counts_by_address = CountsByAddress.init(self.allocator);
            defer counts_by_address.deinit();
            var instance = Instance{
                .prefix = &prefix,
                .counts_by_address = &counts_by_address,
                .settings = settings,
                .writer = self.writer,
            };
            try self.writer.print(comptimeInColor(Color.yellow, "{s}"), .{settings.name});
            try instance.formatRecursive(arg);
            try self.writer.print("\n", .{});
        }

        const Instance = struct {
            prefix: *std.ArrayList(u8),
            counts_by_address: *CountsByAddress,
            settings: TreeFormatterSettings,
            writer: StdIoWriter,

            fn formatRecursive(self: *Instance, arg: anytype) anyerror!void { // TODO: remove anyerror
                try self.formatTypeName(arg);

                const arg_type = @TypeOf(arg);
                switch (@typeInfo(arg_type)) {
                    .@"struct" => |s| {
                        if (s.fields.len == 0) return try self.writer.writeAll(empty);

                        // extra method formatting for some types
                        if (self.settings.format_multi_array_list and isMultiArrayList(arg_type)) {
                            try self.formatMultiArrayListMethods(arg, arg_type);
                        } else if (self.settings.format_multi_array_list and isMultiArrayListSlice(arg_type)) {
                            try self.formatMultiArrayListSliceMethods(arg);
                        } else if (self.settings.format_hash_map_unmanaged and isHashMapUnmanaged(arg_type)) {
                            try self.formatHashMapUnmanagedMethods(arg);
                        }

                        return try self.formatFieldValues(arg, s);
                    },
                    .array => |a| {
                        if (a.child == u8 and self.settings.print_u8_chars) {
                            try self.writer.print(" \"{s}\"", .{arg});
                            if (self.settings.ignore_u8_in_lists) return;
                        }
                        if (a.len == 0) return try self.writer.writeAll(empty);
                        return try self.formatArrayValues(arg);
                    },
                    .vector => |v| {
                        if (v.child == u8 and self.settings.print_u8_chars) {
                            try self.writer.print(" \"{s}\"", .{arg});
                            if (self.settings.ignore_u8_in_lists) return;
                        }
                        if (v.len == 0) return try self.writer.writeAll(empty);
                        return try self.formatVectorValues(arg, v);
                    },
                    .pointer => |p| {
                        // TODO: detect invalid pointers and print them as such
                        switch (p.size) {
                            .one => {
                                const addr: usize = @intFromPtr(arg);
                                try self.writer.print(" " ++ address_fmt, .{addr});

                                if (self.counts_by_address.getPtr(addr)) |counts_ptr| {
                                    if (counts_ptr.* >= self.settings.ptr_repeat_limit)
                                        return try self.writer.writeAll(ptr_repeat_reached);
                                    try self.writer.writeAll(ptr_repeat);
                                    counts_ptr.* += 1;
                                } else {
                                    try self.counts_by_address.put(addr, 1);
                                }

                                // TODO: segment ignores unprintable values, more verification is needed
                                if (addr == 0) return;
                                if (p.child == anyopaque) return;
                                const child_type_info = @typeInfo(p.child);
                                switch (child_type_info) {
                                    .@"fn" => return,
                                    else => {},
                                }
                                if (!isComptime(arg)) {
                                    switch (child_type_info) {
                                        .@"opaque" => return,
                                        else => {},
                                    }
                                }

                                try self.writeChildComptime(.last, pointer_dereference);
                                try self.formatValueRecursiveIndented(.last, arg.*);
                            },
                            .slice => {
                                if (!isComptime(arg)) {
                                    try self.writer.print(" " ++ address_fmt, .{@intFromPtr(arg.ptr)});
                                }
                                if (p.child == u8 and self.settings.print_u8_chars) {
                                    try self.writer.print(" \"{s}\"", .{arg});
                                    if (self.settings.ignore_u8_in_lists) return;
                                }
                                try self.formatSliceValues(arg);
                            },
                            .many, .c => {
                                try self.writer.print(" " ++ address_fmt, .{@intFromPtr(arg)});
                                _ = p.sentinel() orelse return; // if it doesn't have sentinel, it is not possible to safely print the values, so return
                                if (p.child == u8 and self.settings.print_u8_chars) {
                                    try self.writer.print(" \"{s}\"", .{arg});
                                    if (self.settings.ignore_u8_in_lists) return;
                                }
                                const spanned = std.mem.span(arg);
                                try self.formatSliceValues(spanned);
                            },
                        }
                    },
                    .optional => {
                        if (arg) |value| {
                            try self.writeChildComptime(.last, optional_unwrap);
                            try self.formatValueRecursiveIndented(.last, value);
                        } else {
                            try self.writer.print(" {s} null", .{arrow});
                        }
                    },
                    .@"union" => |u| {
                        if (u.fields.len == 0) return try self.writer.writeAll(empty);
                        if (u.tag_type) |_| {
                            return try self.formatTaggedUnion(arg, u, @intFromEnum(arg));
                        }
                        try self.formatFieldValues(arg, u);
                    },
                    .error_union => {
                        const value = arg catch |err| {
                            return try self.writer.print(" {s} {any}", .{ arrow, err });
                        };
                        try self.formatValueRecursiveIndented(.last, value);
                    },
                    .@"enum" => try self.writer.print(" {s} {} ({d})", .{ arrow, arg, @intFromEnum(arg) }),
                    .@"fn" => {
                        // cant print any values for fn types
                    },
                    else => try self.writer.print(" {s} {any}", .{ arrow, arg }),
                }
            }

            fn formatValueRecursiveIndented(self: *Instance, child_prefix: ChildPrefix, arg: anytype) !void {
                const backup_len = self.prefix.items.len;
                defer self.prefix.shrinkRetainingCapacity(backup_len);

                switch (child_prefix) {
                    .non_last => try self.prefix.appendSlice(indent_bar),
                    .last => try self.prefix.appendSlice(indent_blank),
                }
                try self.formatRecursive(arg);
            }

            fn writeIndexingLimitMessage(self: *Instance, limit: usize, len: usize) !void {
                try self.writeChild(
                    .last,
                    "..." ++ comptimeInColor(Color.bright_black, " (showed first {d} out of {d} items only)"),
                    .{ limit, len },
                );
            }

            fn formatArrayValues(self: *Instance, array: anytype) !void {
                // std.debug.print("array len: {d}\n", .{array.len});
                if (self.settings.array_elem_limit == 0) {
                    return try self.writeIndexingLimitMessage(self.settings.array_elem_limit, array.len);
                }

                if (array.len > self.settings.array_elem_limit) {
                    inline for (array, 0..) |item, index| {
                        if (index >= self.settings.array_elem_limit) break;
                        try self.formatIndexedValueComptime(.non_last, item, index);
                    }
                    return try self.writeIndexingLimitMessage(self.settings.array_elem_limit, array.len);
                }

                inline for (array[0 .. array.len - 1], 0..) |item, index| {
                    try self.formatIndexedValueComptime(.non_last, item, index);
                }
                try self.formatIndexedValueComptime(.last, array[array.len - 1], array.len - 1);
            }

            inline fn formatIndexedValueComptime(self: *Instance, child_prefix: ChildPrefix, item: anytype, comptime index: usize) !void {
                try self.writeChildComptime(child_prefix, comptimeFmtInColor(Color.yellow, "[{d}]", .{index}));
                try self.formatValueRecursiveIndented(child_prefix, item);
            }

            fn formatVectorValues(self: *Instance, vector: anytype, vector_type: anytype) !void {
                if (self.settings.vector_elem_limit == 0) {
                    return try self.writeIndexingLimitMessage(self.settings.vector_elem_limit, vector_type.len);
                }

                if (vector_type.len > self.settings.vector_elem_limit) {
                    comptime var i: usize = 0;
                    inline while (i < vector_type.len) : (i += 1) {
                        if (i >= self.settings.vector_elem_limit) break;
                        try self.formatIndexedValueComptime(.non_last, vector[i], i);
                    }
                    return try self.writeIndexingLimitMessage(self.settings.vector_elem_limit, vector_type.len);
                }

                comptime var i: usize = 0;
                inline while (i < vector_type.len - 1) : (i += 1) {
                    try self.formatIndexedValueComptime(.non_last, vector[i], i);
                }
                try self.formatIndexedValueComptime(.last, vector[i], i);
            }

            fn formatIndexedValue(self: *Instance, comptime child_prefix: ChildPrefix, item: anytype, index: usize) !void {
                try self.writeChild(child_prefix, comptimeInColor(Color.yellow, "[{d}]"), .{index});
                try self.formatValueRecursiveIndented(child_prefix, item);
            }

            fn formatSliceValuesComptime(self: *Instance, slice: anytype) !void {
                inline for (slice, 0..) |item, index| {
                    if (index == self.settings.slice_elem_limit) {
                        return try self.writeIndexingLimitMessage(self.settings.slice_elem_limit, slice.len);
                    }
                    if (index == slice.len - 1) {
                        try self.formatIndexedValueComptime(.last, item, index);
                    } else {
                        try self.formatIndexedValueComptime(.non_last, item, index);
                    }
                }
            }

            fn formatSliceValues(self: *Instance, slice: anytype) !void {
                if (slice.len == 0) return self.writer.writeAll(empty);

                if (self.settings.slice_elem_limit == 0) {
                    return try self.writeIndexingLimitMessage(self.settings.slice_elem_limit, slice.len);
                }

                if (isComptime(slice)) {
                    return try self.formatSliceValuesComptime(slice);
                }

                if (slice.len > self.settings.slice_elem_limit) {
                    for (slice[0..self.settings.slice_elem_limit], 0..) |item, index| {
                        try self.formatIndexedValue(.non_last, item, index);
                    }
                    return try self.writeIndexingLimitMessage(self.settings.slice_elem_limit, slice.len);
                }

                const last_index = slice.len - 1;
                for (slice[0..last_index], 0..) |item, index| {
                    try self.formatIndexedValue(.non_last, item, index);
                }
                try self.formatIndexedValue(.last, slice[last_index], last_index);
            }

            fn formatFieldValues(self: *Instance, arg: anytype, arg_type: anytype) !void {
                // Note:
                // This is set so that unions can be printed for all its values
                // This can be removed if we are able to determine the active union
                // field during ReleaseSafe and Debug builds,
                @setRuntimeSafety(false);

                inline for (arg_type.fields, 0..) |field, index| {
                    const child_prefix = if (index == arg_type.fields.len - 1) .last else .non_last;
                    try self.writeChildComptime(child_prefix, comptimeInColor(Color.yellow, "." ++ field.name));
                    try self.formatValueRecursiveIndented(child_prefix, @field(arg, field.name));
                }
            }

            fn formatTaggedUnionComptime(self: *Instance, arg: anytype) !void {
                const tag_name = @tagName(arg);
                try self.writeChildComptime(.last, comptimeInColor(Color.yellow, "." ++ tag_name));
                return try self.formatValueRecursiveIndented(.last, @field(arg, tag_name));
            }

            fn formatTaggedUnion(self: *Instance, arg: anytype, arg_type: anytype, target_index: usize) !void {
                if (isComptime(arg)) {
                    return try self.formatTaggedUnionComptime(arg);
                }

                inline for (arg_type.fields, 0..) |field, index| {
                    if (index == target_index) {
                        try self.writeChildComptime(.last, comptimeInColor(Color.yellow, "." ++ field.name));
                        return try self.formatValueRecursiveIndented(.last, @field(arg, field.name));
                    }
                }
            }

            fn formatMultiArrayListMethods(self: *Instance, arr: anytype, comptime arr_type: type) !void {
                try self.formatMultiArrayListSliceItems(arr, arr_type);
                try self.formatMultiArrayListGet(arr);
            }

            fn formatMultiArrayListSliceItems(self: *Instance, arr: anytype, comptime arr_type: type) !void {
                const slice = arr.slice();
                try self.writeChildComptime(.non_last, slice_method);
                try self.formatTypeName(slice);

                const backup_len = self.prefix.items.len;
                defer self.prefix.shrinkRetainingCapacity(backup_len);
                try self.prefix.appendSlice(indent_bar);

                try self.writeChildComptime(.last, items_method);
                const fields = @typeInfo(arr_type.Field).@"enum".fields;
                inline for (fields, 0..) |field, index| {
                    const backup_len2 = self.prefix.items.len;
                    defer self.prefix.shrinkRetainingCapacity(backup_len2);
                    try self.prefix.appendSlice(indent_blank);

                    const child_prefix = if (index == fields.len - 1) .last else .non_last;
                    try self.writeChild(child_prefix, comptimeInColor(Color.green, "(.{s})"), .{field.name});
                    const items = slice.items(@as(arr_type.Field, @enumFromInt(index)));
                    try self.formatValueRecursiveIndented(child_prefix, items);
                }
            }

            fn formatMultiArrayListGet(self: *Instance, arr: anytype) !void {
                try self.writeChildComptime(.non_last, get_method);

                const backup_len = self.prefix.items.len;
                var index: usize = 0;
                while (index < arr.len) : (index += 1) {
                    defer self.prefix.shrinkRetainingCapacity(backup_len);
                    try self.prefix.appendSlice(indent_bar);

                    if (index == self.settings.multi_array_list_get_limit) {
                        return try self.writeIndexingLimitMessage(self.settings.multi_array_list_get_limit, arr.len);
                    }
                    if (index == arr.len - 1) {
                        try self.writeChild(.last, comptimeInColor(Color.green, "({d})"), .{index});
                        return try self.formatValueRecursiveIndented(.last, arr.get(index));
                    }
                    try self.writeChild(.non_last, comptimeInColor(Color.green, "({d})"), .{index});
                    try self.formatValueRecursiveIndented(.non_last, arr.get(index));
                }
            }

            fn formatMultiArrayListSliceMethods(self: *Instance, slice: anytype) !void {
                // can reuse the methods from the multi array list
                // contains the same logic anyway
                const arr = slice.toMultiArrayList();
                try self.formatMultiArrayListMethods(arr, @TypeOf(arr));
            }

            fn formatHashMapUnmanagedMethods(self: *Instance, map: anytype) !void {
                try self.writeChildComptime(.non_last, iterator_method);

                var count: usize = 0;
                var it = map.iterator();
                const backup_len = self.prefix.items.len;
                while (it.next()) |entry| : (count += 1) {
                    defer self.prefix.shrinkRetainingCapacity(backup_len);
                    try self.prefix.appendSlice(indent_bar);

                    if (count > self.settings.hash_map_entry_limit) {
                        return try self.writeIndexingLimitMessage(self.settings.hash_map_entry_limit, map.count());
                    }
                    if (count == map.count() - 1) {
                        try self.writeChildComptime(.last, next_method);
                        return try self.formatValueRecursiveIndented(.last, entry);
                    }
                    try self.writeChildComptime(.non_last, next_method);
                    try self.formatValueRecursiveIndented(.non_last, entry);
                }
            }

            fn writeChild(self: *Instance, comptime child_prefix: ChildPrefix, comptime fmt: []const u8, args: anytype) !void {
                try self.writer.print("\n{s}" ++ child_prefix.bytes(), .{self.prefix.items});
                try self.writer.print(fmt, args);
            }

            fn writeChildComptime(self: *Instance, comptime child_prefix: ChildPrefix, comptime bytes: []const u8) !void {
                try self.writer.print("\n{s}" ++ child_prefix.bytes() ++ bytes, .{self.prefix.items});
            }

            fn formatTypeName(self: *Instance, arg: anytype) !void {
                try self.writer.print("{s}{s}", .{
                    comptimeInColor(Color.bright_black, ": "),
                    comptimeInColor(Color.cyan, @typeName(@TypeOf(arg))),
                });
            }
        };
    };
}

inline fn isComptime(val: anytype) bool {
    return @typeInfo(@TypeOf(.{val})).@"struct".fields[0].is_comptime;
}

inline fn isMultiArrayList(comptime T: type) bool {
    return std.mem.containsAtLeast(u8, @typeName(T), 1, "MultiArrayList") and @hasDecl(T, "Field") and @hasDecl(T, "Slice");
}

inline fn isMultiArrayListSlice(comptime T: type) bool {
    return std.mem.containsAtLeast(u8, @typeName(T), 1, "MultiArrayList") and @hasDecl(T, "toMultiArrayList") and @hasDecl(T, "items");
}

inline fn isHashMapUnmanaged(comptime T: type) bool {
    return std.mem.containsAtLeast(u8, @typeName(T), 1, "HashMapUnmanaged") and @hasDecl(T, "KV") and @hasDecl(T, "Hash");
}
