class Options{
  String game = "guess";
  bool multiplayer = false, increasingDiff = false;
  int duration = 30, bestOf = 1, length = 4;
  Options.empty();
  Options({required this.game, required this.multiplayer, required this.duration, required this.bestOf, required this.increasingDiff, required length}); 
  @override
  String toString() {
    return 'multiplayer: ' + multiplayer.toString() + ' duration: ' + duration.toString() + ' best: ' + bestOf.toString() + ' digit: ' + 'inc: '  + this.increasingDiff.toString();
  }
}