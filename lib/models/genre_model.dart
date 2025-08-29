/// Enhanced Genre model with image path support
class EnhancedGenre {
  final int malId;
  final String name;
  final String? imagePath;

  const EnhancedGenre({
    required this.malId,
    required this.name,
    this.imagePath,
  });

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'malId': malId,
      'name': name,
      'imagePath': imagePath,
    };
  }

  /// Create from Firestore document
  factory EnhancedGenre.fromMap(Map<String, dynamic> map) {
    return EnhancedGenre(
      malId: map['malId'] ?? 0,
      name: map['name'] ?? '',
      imagePath: map['imagePath'],
    );
  }

  /// Create from jikan_api Genre
  factory EnhancedGenre.fromJikanGenre(dynamic jikanGenre, {String? imagePath}) {
    return EnhancedGenre(
      malId: jikanGenre.malId,
      name: jikanGenre.name,
      imagePath: imagePath,
    );
  }

  /// Create a copy with updated fields
  EnhancedGenre copyWith({
    int? malId,
    String? name,
    String? imagePath,
  }) {
    return EnhancedGenre(
      malId: malId ?? this.malId,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  @override
  String toString() {
    return 'EnhancedGenre(malId: $malId, name: $name, imagePath: $imagePath)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EnhancedGenre &&
        other.malId == malId &&
        other.name == name &&
        other.imagePath == imagePath;
  }

  @override
  int get hashCode {
    return malId.hashCode ^ name.hashCode ^ imagePath.hashCode;
  }
} 