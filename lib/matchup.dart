class Matchup {
  late List players;
  late List scores;
  Matchup({required this.players, required this.scores});
  Matchup.fromJson(Map<String, dynamic> json)
      : players = json['players'],
        scores = json['scores'];
  Map<String, dynamic> toJson() => {'players': players, 'scores': scores};
}
