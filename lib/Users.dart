class Users{
  String? name = '', email = '', password = '';
  Users({this.name, this.email, this.password});
  @override
  String toString() {
    return this.name! +", "+ email! +" " + password!;
  }
}