pub const TreeFormatterSettings = struct {
    array_print_limit: usize = 5,
    slice_print_limit: usize = 5,
    vector_print_limit: usize = 5,
    multi_array_list_get_limit: usize = 5,

    /// if []u8 should be printed as a string
    /// affects Arrays, Slice, Vector
    print_u8_chars: bool = true,

    /// determines maximum repeat count for a unique pointer
    ptr_repeat_limit: usize = 1,

    /// limits the number of children to print
    type_print_limit: usize = 1,

    /// if allowed to format multi array list (std.MultiArrayList)
    format_multi_array_list: bool = true,
};
