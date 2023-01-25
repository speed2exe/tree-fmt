# Zig Tree Formattar
- Tree-like formatter for Zig Programming Language
- This library is in development
- If you have trouble with the formatting, please open an issue.

![Screenshot](./images/screenshot.png)

## Objective
- Provide a tree-like visual representation of a Zig value

## Usage
- Use `git submodule` or copy the `src` folder into your project directly. This
  project will be packaged properly once the official package manager is released.
- Below shows a simple example of how to use this library.

```zig
const std = @import("std");

// add imports here
const TreeFormatter = @import("./src/tree_fmt.zig").TreeFormatter;

pub fn main() !void {
    // initialize your allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const leaked = gpa.deinit();
        if (leaked) {
            @panic("leaked memory!");
        }
    }

    // initialize TreeFormatter
    var tree_formatter = TreeFormatter.init(allocator, .{});

    // initialize a writer (std.io.Writer)
    var w = std.io.getStdOut().writer();

    // initialize your value
    var sentinel_array: [*:0]const u8 = "hello world";

    // call the method with writer and value
    try tree_formatter.formatValueWithId(w, sentinel_array, "sentinel_array");
}
```

- Example output:
```
sentinel_array: [*:0]const u8 @20a71e "hello world"
├─[0]: u8 => 104
├─[1]: u8 => 101
├─[2]: u8 => 108
├─[3]: u8 => 108
├─[4]: u8 => 111
├─[5]: u8 => 32
├─[6]: u8 => 119
├─[7]: u8 => 111
├─[8]: u8 => 114
├─[9]: u8 => 108
└─... (showed first 10 out of 11 items only)
```

- You can find other examples in the root directory. To run the examples, use
  `zig run examples_<example_name>.zig`

## Example
- `std.ArrayList(u8)`
```
.: array_list.ArrayListAligned(u8,null)
├─.items: []u8 @7efcc912f000
│ ├─[0]: u8 => 0
│ ├─[1]: u8 => 1
│ ├─[2]: u8 => 2
│ ├─[3]: u8 => 3
│ ├─[4]: u8 => 4
│ └─... (showed first 5 out of 100 items only)
├─.capacity: usize => 105
└─.allocator: mem.Allocator
  ├─.ptr: *anyopaque @7fffadc5b3d8
  └─.vtable: *const mem.Allocator.VTable @202a38
    └─.*: mem.Allocator.VTable
      ├─.alloc: *const fn(*anyopaque, usize, u8, usize) ?[*]u8 @238e00
      ├─.resize: *const fn(*anyopaque, []u8, u8, usize, usize) bool @2393c0
      └─.free: *const fn(*anyopaque, []u8, u8, usize) void @23a2d0
```

- `std.AutoHashMap(u8, u8)`
```
map: hash_map.HashMap(u8,u8,hash_map.AutoContext(u8),80)
├─.unmanaged: hash_map.HashMapUnmanaged(u8,u8,hash_map.AutoContext(u8),80)
│ ├─.metadata: ?[*]hash_map.HashMapUnmanaged(u8,u8,hash_map.AutoContext(u8),80).Metadata
│ │ └─.?: [*]hash_map.HashMapUnmanaged(u8,u8,hash_map.AutoContext(u8),80).Metadata @7f5ea0bc7018
│ ├─.size: u32 => 100
│ └─.available: u32 => 2
├─.allocator: mem.Allocator
│ ├─.ptr: *anyopaque @7ffe61d91c30
│ └─.vtable: *const mem.Allocator.VTable @2033e0
│   └─.*: mem.Allocator.VTable
│     ├─.alloc: *const fn(*anyopaque, usize, u8, usize) ?[*]u8 @239470
│     ├─.resize: *const fn(*anyopaque, []u8, u8, usize, usize) bool @239a30
│     └─.free: *const fn(*anyopaque, []u8, u8, usize) void @23a940
└─.ctx: hash_map.AutoContext(u8) => .{}
```
