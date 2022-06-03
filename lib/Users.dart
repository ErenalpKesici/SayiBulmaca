class Users {
  String? name = '',
      email = '',
      password = '',
      picture = '',
      language = '',
      method = '';
  int xp = 0, credit = 0;
  Users(
      {required this.name,
      required this.email,
      required this.password,
      this.picture,
      required this.language,
      required this.xp,
      required this.credit,
      required this.method});
  Users.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        email = json['email'],
        picture = json['picture'];
  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'picture': picture,
      };
}
