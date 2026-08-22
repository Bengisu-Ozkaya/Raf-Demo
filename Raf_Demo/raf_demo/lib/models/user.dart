class AppUser {
  final String id;
  final String username;
  final String name;
  final String email;
  final String city;
  final String? phone;

  AppUser({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
    required this.city,
    this.phone,
  });

  /// JSON'dan AppUser nesnesi oluşturan factory constructor.
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id']?.toString() ?? '',
      username: json['username'] as String? ?? json['shop_name'] as String? ?? '',
      name: json['name'] as String? ?? json['owner_name'] as String? ?? json['username'] as String? ?? json['shop_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      city: json['city'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
    );
  }

  /// AppUser nesnesini JSON'a çeviren metod.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'email': email,
      'city': city,
      'phone': phone,
    };
  }
}
