class Options{
  bool multiplayer = false;
  int duration = 30, bestOf = 1;
  Options.empty();
  Options({required this.multiplayer, required this.duration, required this.bestOf}); 
  @override
  String toString() {
    return 'multiplayer: ' + multiplayer.toString() + ' duration: ' + duration.toString() + ' best: ' + bestOf.toString() + ' digit: ';
  }
}