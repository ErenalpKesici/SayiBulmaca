class Options {
  String game = "guess";
  bool multiplayer = false, increasingDiff = false;
  int duration = 30, bestOf = 1, length = 4;
  Options.empty();
  Options(
      {required this.game,
      required this.multiplayer,
      required this.duration,
      required this.bestOf,
      required this.increasingDiff,
      required length});
  Options.fromJson(Map<String, dynamic> json)
      : game = json['game'],
        multiplayer = json['multiplayer'],
        duration = json['duration'],
        bestOf = json['bestOf'],
        increasingDiff = json['increasingDiff'],
        length = json['length'];
  Map<String, dynamic> toJson() => {
        'game': game,
        'multiplayer': multiplayer,
        'duration': duration,
        'bestOf': bestOf,
        'increasingDiff': increasingDiff,
        'length': length
      };
}
