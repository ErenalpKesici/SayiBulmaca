import 'package:sayibulmaca/Options.dart';

class League {
  String? id, name = '', host = '';
  List players = List.empty(growable: true);
  Options? options;
  List matchups = List.empty(growable: true);
  League(
      {required this.id,
      required this.name,
      required this.host,
      required this.players,
      required this.matchups,
      required this.options});
}
