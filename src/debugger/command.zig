pub const Command = union(enum) {
    exit: Exit,
    kill: Kill,
    cont: Continue,
    stop: Stop,
};

pub const Exit = struct {};
pub const Kill = struct {};
pub const Continue = struct {};
pub const Stop = struct {};
