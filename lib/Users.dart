class Users {
  String? name = '',
      email = '',
      password = '',
      language = '',
      method = '',
      settings = '';
  int xp = 0, credit = 0;
  Users(
      {required this.name,
      required this.email,
      required this.password,
      required this.language,
      required this.xp,
      required this.credit,
      required this.method,
      required this.settings});
}
