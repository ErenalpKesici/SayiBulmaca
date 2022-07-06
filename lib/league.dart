import 'package:sayibulmaca/Options.dart';

class League {
  String? id, name = '', host = '';
  DateTime? startDate, endDate;
  int status = 0;
  List players = List.empty(growable: true);
  Options? options;
  List matchups = List.empty(growable: true);
  List results = List.empty(growable: true);
  League(
      {required this.id,
      required this.name,
      required this.startDate,
      required this.endDate,
      required this.host,
      required this.status,
      required this.players,
      required this.matchups,
      required this.options,
      required this.results});
}
