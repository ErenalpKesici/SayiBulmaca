
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math';
import 'Options.dart';
import 'Users.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_auth/firebase_auth.dart';
int randomNumber = 0;
int? selectedLength = 4;
// int selectedBestOf = 1;
// int secondsLeft = 0;
Timer? timerSeconds, timerPlayers;
List<dynamic> ns = new List.empty(growable: true);
void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseFirestore.instance.collection("Users").get().then((value) {
        value.docs.forEach((result) {
          ns.add(result.get("name"));
        });
  });
  print(ns);
  runApp(MyApp());
}

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

class MyApp extends StatelessWidget{

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sayi Bulmaca',
      theme: ThemeData(
        primarySwatch: Colors.pink
      ),
      home: InitialPageSend()
    );
  }
}

class InitialPageSend extends StatefulWidget {
  InitialPageSend();
  @override
  State<StatefulWidget> createState() {
    return InitialPage();
  }
}

class InitialPage extends State<InitialPageSend>{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: Container(), title: Text('Hesap Girisi'), centerTitle: true,),
      body: Center(
        child: Wrap(
          spacing: 50,
          direction: Axis.vertical,
          children: [
            ElevatedButton(onPressed:(){
              Navigator.of(context).push(MaterialPageRoute(builder: (context) =>LoginPageSend()));
            },
              style: ElevatedButton.styleFrom(padding: EdgeInsets.all(16)),
              child: Text('Giris Yap', style: TextStyle(fontSize: 30))),
              ElevatedButton(onPressed:(){
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) =>RegisterPageSend()));
            }, 
              style: ElevatedButton.styleFrom(padding: EdgeInsets.fromLTRB(16, 16, 24, 16)),
              child: Text('Kayit  Ol', textAlign: TextAlign.center, style: TextStyle(fontSize: 30))),
          ],
        ),
      ),
    );
  }
}

class RegisterPageSend extends StatefulWidget{
  RegisterPageSend();
  @override
  State<StatefulWidget> createState() {
    return RegisterPage();
  }
}
class RegisterPage extends State<RegisterPageSend>{
  TextEditingController email = new TextEditingController();
  TextEditingController name = new TextEditingController();
  TextEditingController password = new TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Kayit Ol', textAlign: TextAlign.center,), centerTitle: true,),
      body: Column(mainAxisAlignment: MainAxisAlignment.center,
        children: [
           Padding(
             padding: const EdgeInsets.all(8.0),
             child: Container(
                child: TextField(controller: email,
                  textAlign: TextAlign.center,
                   decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)) ),
                ),
              ),
           ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                child: TextField(controller: name,
                  textAlign: TextAlign.center,
                   decoration: InputDecoration(labelText: 'Kullanici Adi',  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)) ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                child: TextField(controller: password,
                  textAlign: TextAlign.center,
                   decoration: InputDecoration(labelText: 'Sifre', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)) ),
                ),
              ),
            ),
            ElevatedButton(onPressed: () async{
              if(email.text != '' && name.text != '' && password.text != ''){
                FirebaseFirestore.instance.collection('Users').doc(email.text).set({'email': email.text, 'name': name.text, 'password': password.text, 'status': 0, 'xp': 0});
                DocumentReference doc = FirebaseFirestore.instance.collection("Users").doc(email.text);
                var document = await doc.get();
                if(!document.exists)
                  return;
                Users user = new Users(email: document.get('email'), password: document.get('password'), name: document.get('name'));
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) =>HomePageSend(user: user)));
              }
              else{
                    ScaffoldMessenger.of(context).showSnackBar(new SnackBar(content: Text('Lutfen tum bilgileri doldurun')));
              }
            }, child: Text('OK'))
        ],
      ),
    );
  }
}

class LoginPageSend extends StatefulWidget{
  LoginPageSend();
  @override
  State<StatefulWidget> createState() {
    return LoginPage();
  }
}
class LoginPage extends State<LoginPageSend>{
  TextEditingController email = new TextEditingController();
  TextEditingController password = new TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Giris Yap'), centerTitle: true,),
      body: Column(mainAxisAlignment: MainAxisAlignment.center,
        children: [
           Padding(
             padding: const EdgeInsets.all(8.0),
             child: Container(
                child: TextField(controller: email,
                  textAlign: TextAlign.center,
                   decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
           ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                child: TextField(controller: password,
                  textAlign: TextAlign.center,
                   decoration: InputDecoration(labelText: 'Sifre', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)) ),
                ),
              ),
            ),
             ElevatedButton(onPressed: () async{
              if(email.text != "" && password.text != ""){
                email.text = email.text.trim();
                password.text = password.text.trim();
                DocumentReference doc = FirebaseFirestore.instance.collection("Users").doc(email.text);
                var document = await doc.get();
                if(!document.exists){
                    ScaffoldMessenger.of(context).showSnackBar(new SnackBar(content: Text('Kullanici bulunamadi ')));
                    return;
                }
                if(document.get('email') == email.text && document.get('password') == password.text){
                  Users user = new Users(email: document.get('email'), name: document.get('name'), password: document.get('password')); 
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) =>HomePageSend(user: user)));
                }
                else{
                    ScaffoldMessenger.of(context).showSnackBar(new SnackBar(content: Text('Sifre yanlis girildi')));
                }
              }
            }, child: Text('Ok'))
        ],
      ),
    );
  }
}


class HomePageSend extends StatefulWidget {
  final Users? user;
  HomePageSend({@required this.user});
  @override
  State<StatefulWidget> createState() {
    return HomePage(this.user);
  }
}

class HomePage extends State<HomePageSend> {
  Users? user;
  Timer? searchTimer;
  HomePage(this.user);
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async{
          showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: Center(child: Text('Uyari')),
              content: Text('Hesaptan cikmak istediginize emin misiniz?'),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      child: Text('No'),
                      onPressed: () => Navigator.pop(c, false),
                    ),
                    SizedBox(width: 10,),
                    ElevatedButton(
                      child: Text('Yes'),
                      onPressed: () {
                        Navigator.pop(c, false);
                        Navigator.of(context).push(MaterialPageRoute(builder: (context) => InitialPageSend()));
                      },
                    ),
                  ],
                ),
               
              ],
            ),
          );
          return false;
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Ana Sayfa'),centerTitle: true,),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(style: ElevatedButton.styleFrom(padding: EdgeInsets.all(16)), onPressed: () async{
                bool searching = false;
                var foundRoom, currentPlayers;
                searchTimer = Timer.periodic(new Duration(seconds: 1), (timer) async{
                  await FirebaseFirestore.instance.collection("Rooms").get().then((value) {
                    value.docs.forEach((result) {
                      print("search");
                      if(result.get('status') == 'ready'){
                        print("?");
                        timer.cancel();
                        foundRoom = result.id;
                        currentPlayers = result.get('players');
                      }
                    });
                  });  
                List<String> playersFound = new List.empty(growable: true);
                if(foundRoom != null){
                  DocumentReference doc = FirebaseFirestore.instance.collection("Rooms").doc(foundRoom);
                  Timer.periodic(new Duration(seconds: 1), (timer) async{
                    var document = await doc.get();
                    if(!document.exists){
                      timer.cancel();
                      return;
                    }
                    if(document.get('status') == 'playing'){
                      var document = await doc.get();
                      Navigator.of(context).push(MaterialPageRoute(builder: (context) =>GamePageSend(user, foundRoom, new Options(multiplayer: true, duration: document.get('duration'), bestOf: document.get('bestOf')))));
                      timer.cancel();
                    }
                  });
                  FirebaseFirestore.instance.collection('Rooms').doc(foundRoom).update({'players': currentPlayers + this.user!.email! + ', '});
                  showDialog(context: context,  barrierDismissible: false, builder: (BuildContext context) {
                    return StatefulBuilder(builder: (context, setState) {
                        timerPlayers = Timer.periodic(new Duration(seconds: 1), (timer) async{
                          var document = await doc.get();
                          if(document.exists)  
                            setState(() {
                              playersFound = document.get('players').split(', ');                
                            });
                        });
                      return AlertDialog(
                          title: Center(child: Text("Oyunun Baslatilmasi Bekleniyor...",)),
                          content: Container(
                            height: 125,
                            child: Column(
                              children: [
                                Text((playersFound.length != 0?(playersFound.length - 2).toString():'0') + ' kisi bulundu...'),
                                SizedBox(height: 50,),
                                CircularProgressIndicator(),
                              ],
                            ),
                          ),
                          actions: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                 ElevatedButton(onPressed: () async{
                              var document = await doc.get();
                              if(document.exists){
                                List<String> pls = currentPlayers.split(', ');
                                currentPlayers = '';
                                for(int i=0;i<pls.length - 1;i++)
                                  if(pls[i] != this.user?.email)
                                    currentPlayers = currentPlayers + pls[i] + ', ';
                                doc.update({'players': currentPlayers});
                              }
                              Navigator.pop(context);
                            }, child: Text('Vazgec')),
                              ],
                            )
                          ],
                      );
                    });
                  });}  
                else if(!searching){
                  searching = true;
                  showDialog(context: context,  barrierDismissible: false, builder: (BuildContext context) {
                    return StatefulBuilder(builder: (context, setState) {
                      return AlertDialog(
                          title: Center(child: Text("Oyun Araniyor...",)),
                          content: Container(
                            height: 125,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                              ],
                            ),
                          ),
                          actions: [
                            ElevatedButton(onPressed: () async{
                              searchTimer?.cancel();
                              Navigator.pop(context);
                              }, child:  Center(child: Text('Vazgec'))),
                          ],
                      );
                    });
                  });
                }
                });
              }, child: Text('Oyun Ara', style: TextStyle(fontSize: 30))),
              SizedBox(height: 25,),
              ElevatedButton(style: ElevatedButton.styleFrom(padding: EdgeInsets.all(16)), onPressed: (){
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) =>SetupPageSend(user: user)));
              }, child: Text('Oyun Olustur', style: TextStyle(fontSize: 30))),
              SizedBox(height: 25,),
              ElevatedButton(style: ElevatedButton.styleFrom(padding: EdgeInsets.all(16)), onPressed: (){
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) =>AccountPageSend(user: user)));
              }, child: Text('Hesabim', style: TextStyle(fontSize: 30))),
            ],
          ),
        ),
      ),
    );
  }
}
class AccountPageSend extends StatefulWidget{
  final Users? user;
  AccountPageSend({@required this.user});
  @override
  State<StatefulWidget> createState() {
    return AccountPage(this.user);
  }
}
class AccountPage extends State<AccountPageSend>{
  Users? user;
  AccountPage(this.user);
  @override
  void initState() {

    super.initState();
  }
  Future<int> getXp() async{
    DocumentReference docUser = FirebaseFirestore.instance.collection("Users").doc(this.user?.email);
    var documentUser = await docUser.get();
    return documentUser.get('xp');
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Hesabim'),centerTitle: true,),
      body: Center(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 0),
              child: Text(this.user!.name!, textAlign: TextAlign.center, style: TextStyle(fontSize: 48),),
            ),
            SizedBox(height: 50,),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: FutureBuilder(future: getXp(), builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot){
                if(snapshot.hasData){
                  double xp = snapshot.data/500;
                  int level = xp.toInt() + 1;
                  xp /= 10;
                  return Stack(children: [ClipRRect(borderRadius: BorderRadius.all(Radius.circular(10)), child: LinearProgressIndicator(value: xp, color: Colors.purple, minHeight: 50)), Padding( padding: const EdgeInsets.all(4.0), child: Center(child: Text('Seviye ' + level.toString(), style: TextStyle(fontSize: 32, color: Colors.white),),),)]);
                }
                else
                  return LinearProgressIndicator(color: Colors.purple, minHeight: 50);
              }),
            ),
            SizedBox(height: 50,),
            ElevatedButton(style: ElevatedButton.styleFrom(padding: EdgeInsets.all(16)),onPressed: (){
              Navigator.of(context).push(MaterialPageRoute(builder: (context) =>UpdatePageSend(user: this.user,)));
            }, child: Text('Hesabi Guncelle', style: TextStyle(fontSize: 30))),
            SizedBox(height: 50,),
            ElevatedButton(style: ElevatedButton.styleFrom(padding: EdgeInsets.all(16)),onPressed: () async{
              return await showDialog(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Center(child: Text("Hesabi Sil")),
                    content: Center(child: Text('Hesabi silmek istediginize emin misiniz?')),
                    actions: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                          child: Text('Hayir'),
                          onPressed: () => Navigator.pop(c, false),
                        ),
                        SizedBox(width: 20,),
                          ElevatedButton(
                            child: Text('Evet'),
                            onPressed: () {
                              FirebaseFirestore.instance.collection('Users').doc(this.user!.email).delete();
                              Navigator.of(context).push(MaterialPageRoute(builder: (context) =>InitialPageSend()));
                            },
                          ),  
                        ],
                      ),
                    ],
                  ));
            }, child: Text('Hesabi Sil', style: TextStyle(fontSize: 30))),          
          ],
        ),
      ),
    );
  }
}

class UpdatePageSend extends StatefulWidget{
  final Users? user;
  UpdatePageSend({@required this.user});
  @override
  State<StatefulWidget> createState() {
    return UpdatePage(this.user);
  }
}
class UpdatePage extends State<UpdatePageSend>{
  Users? user;
  var email = TextEditingController();
  var name = TextEditingController();
  var password = TextEditingController();
  UpdatePage(this.user);
  @override
  Widget build(BuildContext context) {
    return Center(child: Scaffold(
      appBar: AppBar(title: Text('Hesap Guncelleme'),centerTitle: true,),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  child: TextField(controller: email,
                    textAlign: TextAlign.center,
                   decoration: InputDecoration(labelText: 'Suanki Email', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ),
                Container(
                child: TextField(controller: name,
                  textAlign: TextAlign.center,
                   decoration: InputDecoration(labelText: 'Kullanici Adi', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
            Container(
              child: TextField(controller: password,
                textAlign: TextAlign.center,
                   decoration: InputDecoration(labelText: 'Sifre', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ),
            ElevatedButton(onPressed: () async{
              if(email.text == this.user?.email){
                FirebaseFirestore.instance.collection("Users").doc(email.text).update({'name': name.text, 'password': password.text});
                ScaffoldMessenger.of(context).showSnackBar(new SnackBar(content: Text('Hesap Guncellendi')));
              }
              else
                ScaffoldMessenger.of(context).showSnackBar(new SnackBar(content: Text('Email dogru girilmeli')));
            }, child: Text('OK'))
              ],
            ),
          )
        ],
      ),
    ));
  }
}

class SetupPageSend extends StatefulWidget {
  final Users? user;
  SetupPageSend({@required this.user});
  @override
  State<StatefulWidget> createState() {
    return SetupPage(this.user);
  }
}

class SetupPage extends State<SetupPageSend> with WidgetsBindingObserver{
  Users? user;
  Color btnStartColor = Colors.grey;
  Options options = new Options.empty();
  SetupPage(this.user);
  @override
  void initState() {
    WidgetsBinding.instance?.addObserver(this);
    super.initState();
  }
  @override
  void dispose() {
        WidgetsBinding.instance?.removeObserver(this);
    super.dispose();
  }
  int secondsPaused = 0;
  Timer? inactiveTimer;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state)  async{
    if(state == AppLifecycleState.paused){
      DocumentReference doc = FirebaseFirestore.instance.collection("Rooms").doc(this.user?.email);
      var document = await doc.get();
      if(document.exists && document.get('status') == 'ready')
        inactiveTimer = Timer.periodic(new Duration(seconds: 1), (timer) {
          if(secondsPaused > 5){
            FirebaseFirestore.instance.collection('Rooms').doc(this.user!.email).delete();
            Navigator.of(context).push(MaterialPageRoute(builder: (context) =>HomePageSend(user: user)));
          }
          secondsPaused++;
        });
    }
    else{
      secondsPaused = 0;
      inactiveTimer?.cancel();
    }
    print(state);
  }
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async{
        Navigator.of(context).push(MaterialPageRoute(builder: (context) =>HomePageSend(user: user)));
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text("Oyun Olusturma"),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CheckboxListTile(
                title: Text("Multiplayer", style: TextStyle(fontSize: 24)),
                value: options.multiplayer,
                onChanged: (value) {
                  setState(() {
                    options.multiplayer = value!;
                  });
                },
                controlAffinity: ListTileControlAffinity.trailing, 
              ),
              ListTile(
                leading: Text('Zaman: ', style: TextStyle(fontSize: 24),),
                trailing: DropdownButton<int>(
                value: options.duration,
                items: [5, 15, 30, 45, 60, 120].map<DropdownMenuItem<int>>((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(value.toString(), style:TextStyle(color:Colors.black, fontSize: 24),),
                  );
                }).toList(),
                  onChanged: (int? value) {
                    setState(() {
                      options.duration = value!;
                    });
                  },
                ),
              ),
              ListTile(
                leading: Text('Kac oyun uzerinden: ', style: TextStyle(fontSize: 24),),
                trailing: DropdownButton<int>(
                value: options.bestOf,
                items: [1, 3, 5].map<DropdownMenuItem<int>>((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(value.toString(), style:TextStyle(color:Colors.black, fontSize: 24),),
                  );
                }).toList(),
                  onChanged: (int? value) {
                    setState(() {
                      options.bestOf = value!;
                    });
                  },
                ),
              ),
              ListTile(
                leading: Text('Sayi hane sayisi: ', style: TextStyle(fontSize: 24),),
                trailing: DropdownButton<int>(
                value: selectedLength,
                items: [2, 3, 4, 5, 6, 7, 8, 9].map<DropdownMenuItem<int>>((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(value.toString(), style:TextStyle(color:Colors.black, fontSize: 24),),
                  );
                }).toList(),
                  onChanged: (int? value) {
                    setState(() {
                      selectedLength = value!;
                    });
                  },
                ),
              ),
              ElevatedButton(
                onPressed: () async{
                  if(options.multiplayer){
                    FirebaseFirestore.instance.collection('Rooms').doc(this.user!.email).set({'players': this.user!.email! + ', ', 'status': 'ready', 'won': '', 'bestOf': options.bestOf, 'duration': options.duration, 'roundInserted': false});
                    DocumentReference doc = FirebaseFirestore.instance.collection("Rooms").doc(this.user?.email);
                    List<String> playersFound = new List.empty(growable: true);
                    showDialog(context: context,  barrierDismissible: false, builder: (BuildContext context) {
                      return StatefulBuilder(builder: (context, setState) {
                          timerPlayers = Timer.periodic(new Duration(seconds: 5), (timer) async{
                            var document = await doc.get();
                            if(document.exists)
                              setState(() {
                                playersFound = document.get('players').split(', ');       
                                btnStartColor = playersFound.length > 2?Theme.of(context).primaryColor:Colors.grey;            
                              });
                            else
                              timer.cancel();
                          });
                          return AlertDialog(
                            title: Center(child: Text("Rakipler Araniyor...",)),
                            content: Container(
                              height: 125,
                              child: Column(
                                children: [
                                  Text((playersFound.length != 0?(playersFound.length - 2).toString():'0') + ' kisi bulundu...'),
                                  SizedBox(height: 50,),
                                  CircularProgressIndicator(),
                                ],
                              ),
                            ),
                            actions: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton(onPressed: (){
                                timerPlayers?.cancel();
                                FirebaseFirestore.instance.collection('Rooms').doc(this.user!.email).delete();
                                Navigator.pop(context);
                              }, child: Text('Vazgec')),
                              SizedBox(width: 20,),
                              ElevatedButton(onPressed: (){
                                if(btnStartColor == Colors.grey)
                                  return;
                                FirebaseFirestore.instance.collection('Rooms').doc(this.user?.email).update({'status': 'playing'});
                                Navigator.of(context).push(MaterialPageRoute(builder: (context) =>GamePageSend(user, this.user?.email, options)));
                              }, style: ElevatedButton.styleFrom(primary: btnStartColor),
                              child: Text('Baslat'))
                                ],
                              )
                            ],
                        );
                      });
                    });  
                  }
                  else{
                    FirebaseFirestore.instance.collection("Rooms").doc(this.user?.email).set({'players': this.user!.email! + ", ", 'status': 'playing', 'won': '', 'bestOf': options.bestOf, 'roundInserted': false});
                Navigator.of(context).push(MaterialPageRoute(builder: (context) =>GamePageSend(user, this.user?.email, this.options)));
                  }   
                },
                style: ElevatedButton.styleFrom(padding: EdgeInsets.all(16)),
                child: Text('Oyunu Baslat', style: TextStyle(fontSize: 30)))
            ],
          ),
        ),
      ),
    );
  }
}
int findRandom(int? length){
  if(length != null) {
    int min = pow(10, length - 1).toInt();
    int max = pow(10, length).toInt();
    return min + Random().nextInt(max - min);
  }
  return 0;
}
class GamePageSend extends StatefulWidget {
  final Users? user;
  final String? room;
  final Options? options;
  GamePageSend(this.user, this.room, this.options);
  State<StatefulWidget> createState() {
    return GamePage(this.user, this.room, this.options);
  }
}
class GamePage extends State<GamePageSend> {
  Users? user;
  String? room;
  Options? options;
  TextEditingController entered = new TextEditingController();
  List<Entry> entryList = new List.empty(growable: true);
  Color btnApplyColor = Colors.grey;
  FocusNode focused = FocusNode();
  int currentDuration = 0, roundCounter = 0;
  List<String>? otherPlayers;
  bool guessEnabled = true;
  GamePage(this.user, this.room, this.options);

  Future<List<String>> findPlayers(bool withXp) async{
    List<String> ret = new List.empty(growable: true);
    DocumentReference doc = FirebaseFirestore.instance.collection("Rooms").doc(this.room);
    var document = await doc.get();
    var players = document.get('players').split(', ');
    for(int i=0;i<players.length - 1;i++)
        ret.add(players[i]);
    if(withXp){
      for(int i=0;i<ret.length;i++){
        DocumentReference doc = FirebaseFirestore.instance.collection("Users").doc(ret[i]);
        var document = await doc.get();
        int xp = document.get('xp');
        ret[i] += (':' + xp.toString());
      }
    }
    return ret;
  }
  void initializeNumber()async{
    DocumentReference docs = FirebaseFirestore.instance.collection('Rooms').doc(this.room);
    var document = await docs.get();
    randomNumber = document.get('number');
  }
  void processInput() async{
    print(randomNumber);
    if(btnApplyColor == Colors.grey)
      return;
    String rndNumber = randomNumber.toString();
    String tmpEntered = entered.text;
    int dogru = 0, yanlis = 0;
    for(int i=0;i<rndNumber.length;i++){
      if(rndNumber[i] == tmpEntered[i]){
        dogru++;
        rndNumber = rndNumber.substring(0, i)  + rndNumber.substring(i + 1);
        tmpEntered= tmpEntered.substring(0, i) + tmpEntered.substring(i + 1);
        i--;
      }      
    }
    bool kazandi = false;
    if(dogru == randomNumber.toString().length)
      kazandi = true;
    if(!kazandi)
      for(int i=0;i<tmpEntered.length;i++)
        for(int j=0;j<rndNumber.length;j++)
          if(tmpEntered[i] == rndNumber[j]){
            yanlis++;
            break;
          }   
    if(entryList.length > 0)
      entryList.insert(0, new Entry(entryList[0].id + 1, entered.text, dogru, yanlis, kazandi));
    else
      entryList.insert(0, new Entry(1, entered.text, dogru, yanlis, kazandi));
    if(kazandi){
      int score = (((randomNumber.toString().length/4)* currentDuration/(options!.duration * entryList[0].id)) * 100).toInt();
      DocumentReference doc = FirebaseFirestore.instance.collection("Rooms").doc(this.room);
      var document = await doc.get();
      var prevWinners = document.get('won');
      FirebaseFirestore.instance.collection('Rooms').doc(this.room).update({'won': prevWinners + this.user!.email! + ':' + score.toString() + ", "});
      DocumentReference docUser = FirebaseFirestore.instance.collection("Users").doc(this.user?.email);
      var documentUser = await docUser.get();
      FirebaseFirestore.instance.collection('Users').doc(this.user?.email).update({'xp': documentUser.get('xp') + score});
      setState(() {
        guessEnabled = false;
      });
      kazandi = true;
    }              
    entered.clear();
    btnApplyColor = Colors.grey;
  }
  Widget displayNumber(){
    return Text(randomNumber.toString(), style: TextStyle(fontSize: 32, color: Colors.green));
  }
  Widget displayResult(List<Map<String, dynamic>> userScore){
    return DataTable(
      columnSpacing: 40,
        headingRowColor: MaterialStateColor.resolveWith((states) => Colors.black12),
        headingRowHeight: 32,
      columns: [
        DataColumn(label: Text('Ad')),
        DataColumn(label: Text('Skor')),
      ],
      rows: userScore.map<DataRow>((e) => DataRow(
        cells: [
          DataCell(Text(e['user'].toString())),
          DataCell(Text(e['score'].toString())),
        ]
      )).toList(),
    );
  }
  roundEnd() async {
    setState(() {
      guessEnabled = false;
    });
    DocumentReference doc = FirebaseFirestore.instance.collection("Rooms").doc(this.room);
    var document = await doc.get();
    var wins = document.get('won');
    int cd = 3;
    FirebaseFirestore.instance.collection("Rooms").doc(this.room).update({'won': wins});  
    if(this.options!.bestOf >= document.get('won').split('-').length)
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return StatefulBuilder(builder: (context, setState) {
              if(cd != 0)
                Timer.periodic(new Duration(seconds: 1), (timer) { 
                  print(cd.toString());
                  if(cd == 0){
                    timer.cancel();
                    cd = -1;
                    print(this.otherPlayers.toString());
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) =>GamePageSend(user, this.room, this.options)));
                  }
                  else if(cd  < 0)
                    timer.cancel();
                  else
                    setState(() {
                      cd--;
                  });
                });
              return AlertDialog(
                title: Center(child: Text("Round Sonu")),
                content: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Center(child: displayNumber(),), SizedBox(height: 100,), Center(child: Text('Sonraki round ' + cd.toString() + ' saniye icinde basliyor')),],),
                actions: <Widget>[
                    ElevatedButton(onPressed: (){
                      leaveGame();
                      Navigator.pop(context);
                      Navigator.of(context).push(MaterialPageRoute(builder: (context) =>HomePageSend(user: this.user)));
                    },child: Center(child: Text("Oyundan Cik"))),           
                ],
              );
            });
        });
    else if(wins==''){
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Center(child: Text("Oyun Sonuclari")),
            content: Column(mainAxisAlignment: MainAxisAlignment.center, children: [displayNumber(), SizedBox(height: 100,), Center(child: Text('Kimse Kazanamadi')),],),
            actions: <Widget>[
              ElevatedButton(onPressed: (){
                Navigator.pop(context);
              },child: Center(child: Text("Geri"))),
              ElevatedButton(onPressed: (){
                leaveGame();
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(builder: (context) =>HomePageSend(user: this.user)));
              },child: Center(child: Text("Oyundan Cik"))),
            ],
          );
      });
    }
    else{
      List<String> gameWs = wins.split('-');
      List<Map<String, dynamic>> userScoreTmp = List.empty(growable: true);      
      List<Map<String, dynamic>> userScore = List.empty(growable: true);      
      for(int k=0;k<gameWs.length;k++){
        List<String> winners =  gameWs[k].split(', ');
        for(int i=0;i<winners.length - 1;i++){
          List<String> tmp = winners[i].split(':');
          userScoreTmp.add({'user': tmp[0], 'score': tmp[1]});
        }
      }
      List<String> players = await findPlayers(false);
      for(int i=0;i<players.length;i++){
        userScore.add({'user': players[i], 'score': 0});
      }
      for(int j=0;j<userScoreTmp.length;j++)
        for(int k=0;k<userScore.length;k++)
          if(userScoreTmp[j]['user'] == userScore[k]['user'])
            userScore[k]['score'] += int.parse(userScoreTmp[j]['score']);
      for(int i=0;i<userScore.length;i++){//sorting
        int maxIdx = i;
        for(int j=i+1;j<userScore.length;j++){
          if(userScore[maxIdx]['score'] < userScore[j]['score'])
            maxIdx = j;
        }
        Map<String, dynamic> temp = userScore[i];
        userScore[i] = userScore[maxIdx];
        userScore[maxIdx] = temp;
      }
      // String results = '';
      // for(int i=0;i<userScore.length;i++)
      //   results += (userScore[i]['user'].toString() + ': ' + userScore[i]['score'].toString() +'\n');     
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Center(child: Text("Oyun Sonuclari")),
            content: Column(mainAxisAlignment: MainAxisAlignment.center,children: [displayNumber(), SizedBox(height: 50,), displayResult(userScore)]),//  xText(results, style: TextStyle(fontSize: 24),)]),
            actions: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(onPressed: (){
                Navigator.pop(context);
              },child: (Text("Geri"))),
              SizedBox(width: 20,),
              ElevatedButton(onPressed: (){
                if(this.room == this.user?.email)
                  FirebaseFirestore.instance.collection("Rooms").doc(this.room).delete();
                else
                  leaveGame();
                Navigator.of(context).push(MaterialPageRoute(builder: (context) =>HomePageSend(user: this.user)));
              },child: Center(child: Text("Oyundan Cik"))),
                ],
              )        
            ],
          );
      });
    }
    FirebaseFirestore.instance.collection("Rooms").doc(this.room).update({'roundInserted': false});  
  }
  void insertRound() async{
    DocumentReference doc = FirebaseFirestore.instance.collection("Rooms").doc(this.room);
    var document = await doc.get();
    if(!document.exists)return;
    var inserted = document.get('roundInserted');
    var wins = document.get('won');
    roundCounter = wins.split('-').length;
    if(!inserted){
      await FirebaseFirestore.instance.collection("Rooms").doc(this.room).update({'number': findRandom(selectedLength), 'won': wins + '-', 'roundInserted': true});
    }
    initializeNumber();
  }
  @override
  void initState(){
    insertRound();
    currentDuration = options!.duration;
    timerSeconds = new Timer.periodic(Duration(seconds: 1),  (Timer timer) {
      if(currentDuration < 1){
          timer.cancel();
          roundEnd();
      }
      else{
        setState(() {
          currentDuration--;
        });
      }
    });
    super.initState();
  }
  void leaveGame() async{
    if(options!.multiplayer){
      timerPlayers?.cancel();
      DocumentReference doc = FirebaseFirestore.instance.collection("Rooms").doc(this.room);
      var document = await doc.get();
      if(document.exists){
        List<String> players = document.get('players').split(', ');
        if(players.length < 3)
          FirebaseFirestore.instance.collection('Rooms').doc(this.room).delete();
        else{
          String newPlayers = "";
          for(int i=0;i<players.length - 1;i++)
            if(players[i] != this.user?.email)
              newPlayers+= players[i]+', ';
          FirebaseFirestore.instance.collection('Rooms').doc(this.room).update({'players': newPlayers});
        }
      }
    }
    else
      FirebaseFirestore.instance.collection('Rooms').doc(this.room).delete();   
  }
   Future<bool> onWillPop(BuildContext c) async {
    return (await showDialog(
      context: context,
      builder: (context) => new AlertDialog(
          title: Text("Oyundan cikmak istediginize emin misiniz?"),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  child: Text('Hayir'),
                  onPressed: () => Navigator.pop(context, false),
                ),
                SizedBox(width: 10,),
                ElevatedButton(
                  child: Text('Evet'),
                  onPressed: () async{
                    timerSeconds?.cancel();
                    leaveGame();
                    Navigator.pop(context, true);
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) =>HomePageSend(user: user)));
                  },
                ),
              ],
            ),
          ],
        )
      ));
  }
  Widget gameScreen(){
    return WillPopScope(
        onWillPop: (() => onWillPop(context)),
          child: Scaffold(
            appBar: AppBar(
              centerTitle: true,
              title: Text(roundCounter==0?'Sayi Bulmaca':'Sayi Bulmaca - Round ' + roundCounter.toString()),
            ),
            body: Column(
              children: [  
                if(options!.multiplayer)
                  Row(
                   children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 5, 20, 0),
                        child: FutureBuilder(builder: (BuildContext context, AsyncSnapshot<List<String>> snapshot){
                          return snapshot.hasData?Container(
                            height: 50,
                            width: 50,                                               
                            child: ListView.builder(scrollDirection: Axis.horizontal,
                            shrinkWrap: true,itemBuilder: (BuildContext context, int idx){
                              var userXp = snapshot.data![idx].split(':');
                              var user = userXp[0];
                              var xp = userXp[1];
                              if(user != this.user!.email)
                                return Column(children: [Container(width: 25, height: 25, child: Image.asset('assets/account.png')), Text(xp), Text(user)],) ;
                              return Container();
                            }, itemCount: snapshot.data?.length),
                          ):Container();
                        }, future: findPlayers(true),),
                      ),
                    ],
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 10, 0),
                  child: Row(children: [ 
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 20, 0),
                      child: Text(currentDuration.toString(), style: TextStyle(fontSize: 24),),
                    ),
                    Flexible(
                      child: TextField(
                        autofocus: true,
                        focusNode: focused,
                        controller: entered,
                        enabled: guessEnabled,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(labelText: 'Tahmin (' + randomNumber.toString().length.toString() + ")", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)) ),
                        keyboardType: TextInputType.number,
                        onChanged: (String changed){
                          setState(() {
                            if(entered.text.length == 1 && entered.text[0] == '0')
                              entered.clear();
                            if(randomNumber.toString().length != entered.text.length)
                              btnApplyColor = Colors.grey;
                            else
                              btnApplyColor = Theme.of(context).backgroundColor;
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
                      child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(60, 60),
                          primary: btnApplyColor),
                        onPressed: (){                       
        print(randomNumber);
                          setState(() {                          
                            processInput();
                          });
                        }, 
                      child: Text("Uygula")),
                    )
                  ],),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(0, 12, 0, 0),
                        child: DataTable(
                          columnSpacing: 40,
                            headingRowColor: MaterialStateColor.resolveWith((states) => Colors.black12),
                            headingRowHeight: 32,
                          columns: [
                            DataColumn(label: Text('#')),
                            DataColumn(label: Text('Tahmin')),
                            DataColumn(label: Text('Dogru Yerde')),
                            DataColumn(label: Text('Yanlis Yerde')),
                          ],
                          rows: entryList.map<DataRow>((e) => DataRow(
                            color: MaterialStateColor.resolveWith((states) => e.kazandi?Colors.green:Colors.grey),
                            cells: [
                              DataCell(Text(e.id.toString())),
                              DataCell(Text(e.tahmin)),
                              DataCell(Text('+' + e.dogru.toString())),
                              DataCell(Text('-' + e.yanlis.toString())),
                            ]
                          )).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],) ,
          ),
        );
  }

  @override
  Widget build(BuildContext context){
    return gameScreen();
  }
}
