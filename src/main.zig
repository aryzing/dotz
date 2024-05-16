const std = @import("std");
const root = @import("root.zig");

const usage =
    \\Usage:
    \\  dotz $source $dest
    \\
;

pub fn main() !void {
    var args = std.process.args();

    // First arg is binary name.
    _ = args.next();

    const source = args.next() orelse {
        const std_error = std.io.getStdErr();
        try std_error.writeAll("Missing source directory.\n\n" ++ usage);
        std.posix.exit(1);
    };

    const dest = args.next() orelse {
        const std_error = std.io.getStdErr();
        try std_error.writeAll("Missing destination directory directory.\n\n" ++ usage);
        std.posix.exit(1);
    };

    try root.hardlinkFiles(source, dest);
}
