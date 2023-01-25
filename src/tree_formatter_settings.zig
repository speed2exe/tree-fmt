pub const TreeFormatterSettings = struct {
    /// limits the number of children to print
    /// affects Arrays, Slice, Vector, minimum 1
    array_print_limit: usize = 10,

    /// if []u8 should be printed as a string
    /// affects Arrays, Slice, Vector
    print_u8_chars: bool = true,

    /// determines maximum repeat count for a unique pointer
    ptr_repeat_limit: usize = 1,

    /// limits the number of children to print
    type_print_limit: usize = 1,
};
