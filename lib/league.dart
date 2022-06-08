import 'package:sayibulmaca/Options.dart';

class League {
  String? id, name = '', host = '', picture = '';
  List players = List.empty(growable: true);
  Options? options;
  League(
      {required this.id,
      required this.name,
      required this.host,
      required this.players,
      required this.options,
      this.picture});
}
