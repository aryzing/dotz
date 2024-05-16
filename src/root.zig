const std = @import("std");

pub fn hardlinkFiles(source: []const u8, dest: []const u8) !void {
    var source_dir = try std.fs.cwd().openDir(source, .{ .iterate = true });
    defer source_dir.close();

    var dest_dir: std.fs.Dir = if (std.fs.cwd().openDir(dest, .{ .iterate = true })) |dir|
        dir
    else |err| switch (err) {
        error.FileNotFound => try std.fs.cwd().makeOpenPath(dest, .{ .iterate = true }),
        else => return err,
    };
    defer dest_dir.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    var dir_walker = try source_dir.walk(allocator);
    defer dir_walker.deinit();

    while (try dir_walker.next()) |entry| {
        switch (entry.kind) {
            .file => {
                const source_file_rel_path = entry.path;
                const source_file_abs_path = try source_dir.realpathAlloc(allocator, source_file_rel_path);
                defer allocator.free(source_file_abs_path);

                const dest_dir_abs_path = try dest_dir.realpathAlloc(allocator, ".");
                defer allocator.free(dest_dir_abs_path);

                var dest_file_abs_path = try allocator.alloc(u8, dest_dir_abs_path.len + entry.path.len + 1);
                defer allocator.free(dest_file_abs_path);
                std.mem.copyForwards(u8, dest_file_abs_path[0..dest_dir_abs_path.len], dest_dir_abs_path);
                std.mem.copyForwards(u8, dest_file_abs_path[dest_dir_abs_path.len..(dest_dir_abs_path.len + 1)], "/");
                std.mem.copyForwards(u8, dest_file_abs_path[(dest_dir_abs_path.len + 1)..], entry.path);

                if (dest_dir.access(dest_file_abs_path, .{})) {
                    const timestamp_string = try std.fmt.allocPrint(allocator, "{d}", .{std.time.timestamp()});
                    defer allocator.free(timestamp_string);

                    const backup_intermediate_extension = ".bak.";

                    var backup_dest_file_abs_path = try allocator.alloc(u8, dest_file_abs_path.len + backup_intermediate_extension.len + timestamp_string.len);
                    defer allocator.free(backup_dest_file_abs_path);

                    std.mem.copyForwards(u8, backup_dest_file_abs_path[0..dest_file_abs_path.len], dest_file_abs_path);
                    std.mem.copyForwards(u8, backup_dest_file_abs_path[dest_file_abs_path.len..(dest_file_abs_path.len + backup_intermediate_extension.len)], backup_intermediate_extension);
                    std.mem.copyForwards(u8, backup_dest_file_abs_path[(dest_file_abs_path.len + backup_intermediate_extension.len)..], timestamp_string);

                    try dest_dir.rename(dest_file_abs_path, backup_dest_file_abs_path);

                    try std.posix.link(source_file_abs_path, dest_file_abs_path, 0);
                } else |err| {
                    switch (err) {
                        error.FileNotFound => {
                            try std.posix.link(source_file_abs_path, dest_file_abs_path, 0);
                        },
                        else => {
                            return err;
                        },
                    }
                }
            },
            .directory => {
                try dest_dir.makePath(entry.path);
            },
            else => {
                // Ignore.
            },
        }
    }
}

test "write files to provided destination" {
    const testing = std.testing;

    // Create source test files.
    const source_dir = "test-source";
    var dirs = try std.fs.cwd().makeOpenPath(source_dir ++ "/nested", .{});
    dirs.close();
    var file_foo = try std.fs.cwd().createFile(source_dir ++ "/foo.txt", .{});
    defer file_foo.close();
    const foo_content = "This is file foo";
    try file_foo.writeAll(foo_content);
    const bar_content = "This is file bar";
    var file_bar = try std.fs.cwd().createFile(source_dir ++ "/nested/bar.txt", .{});
    defer file_bar.close();
    try file_bar.writeAll(bar_content);

    const dest_dir = "test-dest";

    try hardlinkFiles(source_dir, dest_dir);

    var buffer: [16]u8 = undefined;
    _ = try std.fs.cwd().readFile("test-dest/foo.txt", &buffer);
    try testing.expect(std.mem.eql(u8, &buffer, foo_content));
    _ = try std.fs.cwd().readFile("test-dest/nested/bar.txt", &buffer);
    try testing.expect(std.mem.eql(u8, &buffer, bar_content));

    // Clean up
    try std.fs.cwd().deleteTree(source_dir);
    try std.fs.cwd().deleteTree(dest_dir);
}
