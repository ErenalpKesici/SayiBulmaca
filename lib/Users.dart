class Users {
  String? name = '',
      email = '',
      password = '',
      picture = '',
      language = '',
      method = '',
      accessToken;
  int xp = 0, credit = 0;
  Users(
      {required this.name,
      required this.email,
      required this.password,
      this.picture,
      required this.language,
      required this.xp,
      required this.credit,
      required this.method,
      this.accessToken});
  Users.token({this.accessToken});
  Users.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        email = json['email'],
        picture = json['picture'],
        accessToken = json['accessToken'];
  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'picture': picture,
        'accessToken': accessToken,
      };
}
