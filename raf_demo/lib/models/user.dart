class AppUser {
  final String id;
  final String username;
  final String name;
  final String email;
  final String city;

  AppUser({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
    required this.city,
  });

  /// JSON'dan AppUser nesnesi oluşturan factory constructor.
  /// Backend'den gelebilecek null değerlere karşı korumalıdır.
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      // id alanı hem int hem String gelebilir, her iki durumu da handle edip String'e çeviriyoruz.
      id: json['id']?.toString() ?? '',
      // username null gelirse boş string ata.
      username: json['username'] as String? ?? '',
      // name alanı backend'den gelmeyebilir, bu durumda username'i kullan, o da null ise boş string ata.
      name: json['name'] as String? ?? json['username'] as String? ?? '',
      // email null gelirse boş string ata.
      email: json['email'] as String? ?? '',
      // city null gelirse boş string ata.
      city: json['city'] as String? ?? '',
    );
  }

  /// AppUser nesnesini JSON'a çeviren metod.
  /// Bu veriler SharedPreferences'e kaydedilir.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'email': email,
      'city': city,
    };
  }
}
