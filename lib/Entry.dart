class Entry{
  int id = -1, dogru = 0, yanlis = 0;
  String tahmin = '';
  bool kazandi = false;
  Entry(int id, String tahmin, int dogru, int yanlis, bool kazandi){
    this.id = id;
    this.tahmin = tahmin;
    this.dogru = dogru;
    this.yanlis = yanlis;
    this.kazandi = kazandi;
  }
}