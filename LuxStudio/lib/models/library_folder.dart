/// A Media Library folder (V2 Decision #2) — purely organizational, lives
/// independently of any project. See backend/app/routers/library.py.
class LibraryFolder {
  final String id;
  final String name;

  const LibraryFolder({required this.id, required this.name});

  factory LibraryFolder.fromJson(Map<String, dynamic> json) => LibraryFolder(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}
