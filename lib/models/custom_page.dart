// في ملف lib/models/custom_page.dart

class CustomPage {
  final String id;
  final String title;
  final String partyType;

  CustomPage({
    required this.id,
    required this.title,
    required this.partyType,
  });

  factory CustomPage.fromMap(Map<String, dynamic> map) {
    return CustomPage(
      id: map['id'] as String,
      title: map['title'] as String,
      partyType: map['partyType'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'partyType': partyType,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomPage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CustomPage{id: $id, title: $title, partyType: $partyType}';
  }
}