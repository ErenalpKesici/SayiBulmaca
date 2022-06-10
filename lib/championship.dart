import 'package:sayibulmaca/Options.dart';

class Championship {
  String? id, name = '', host = '';
  List players = List.empty(growable: true);
  Options? options;
  Championship(
      {required this.id,
      required this.name,
      required this.host,
      required this.players,
      required this.options});
}
