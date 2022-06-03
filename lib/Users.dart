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
}
