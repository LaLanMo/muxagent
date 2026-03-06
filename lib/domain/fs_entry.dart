class FsEntry {
  final String name;
  final String path;
  final bool isDir;

  FsEntry({required this.name, required this.path, required this.isDir});

  factory FsEntry.fromJson(Map<String, dynamic> json) => FsEntry(
        name: json['name'] as String? ??
            (json['path'] as String).split('/').last,
        path: json['path'] as String,
        isDir: json['isDir'] as bool,
      );
}
