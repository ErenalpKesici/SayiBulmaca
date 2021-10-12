import 'dart:io';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:math';
import 'AuthenticationServices.dart';
import 'Entry.dart';
import 'Introduction.dart';
import 'Options.dart';
import 'Users.dart';
import 'Configuration.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

int randomNumber = 0, xpPerLevel = 100, selectedBottomIdx = 0;
Timer? timerSeconds, timerPlayers;
String initialSettings = 'sound:false, ';
Configuration? configuration;
GetStorage introShown = GetStorage();
String systemLanguage = Platform.localeName.split('_')[0];
Future<Users> findUser(email) async{
  DocumentReference doc = FirebaseFirestore.instance.collection("Users").doc(email);
  var document = await doc.get();
  Users ret = new Users(email: document.get('email'), password: document.get('password'), name: document.get('name'), language: document.get('language'), xp: document.get('xp'), credit: document.get('credit'),  method: document.get('method'), settings: document.get('settings')); 
  return ret;
}

void toMainPage(BuildContext context, Users user) {
  selectedBottomIdx = 0;
  Navigator.of(context).push(MaterialPageRoute(builder: (context) =>SearchPageSend(user: user)));
}

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await EasyLocalization.ensureInitialized();
  await GetStorage.init();
  introShown.writeIfNull('displayed', false);
  runApp(EasyLocalization(
    supportedLocales: [
      Locale('tr'),
      Locale('en'),
    ],
    path: 'assets/translations',
    child: MyApp())
  );
}
class MyApp extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    return MultiProvider(
      providers: [
        Provider<AuthenticationServices>(
          create: (_) => AuthenticationServices(FirebaseAuth.instance),
        ),
        StreamProvider(
          create: (context) => context.read<AuthenticationServices>().authStateChanges, initialData: null,
        )
      ],
      child: MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        debugShowCheckedModeBanner: false,
        title:  'Sayi Bulmaca',
        theme: ThemeData(
          bottomNavigationBarTheme: BottomNavigationBarThemeData(backgroundColor: Colors.pink, selectedItemColor: Colors.tealAccent, unselectedItemColor: Colors.white),
          primarySwatch: Colors.pink,
        ),
        home: AuthenticationWrapper()
      ),
    );
  }
}
class AuthenticationWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context){
    final firebaseUser = context.watch<User?>();
    if(firebaseUser != null)
      return FutureBuilder(
        future: findUser(firebaseUser.email),
        builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
          if(snapshot.hasData)
            return SearchPageSend(user: snapshot.data);
          else 
            return Center(child: CircularProgressIndicator());
        },
      );
    else
      return introShown.read('displayed')?InitialPageSend():IntroductionPageSend();
  }
}
class InitialPageSend extends StatefulWidget {
  InitialPageSend();
  @override
  State<StatefulWidget> createState() {
    return InitialPage();
  }
}
void checkNetwork(BuildContext context)async{
  var connectivityResult = await (Connectivity().checkConnectivity());
  if (connectivityResult != ConnectivityResult.mobile && connectivityResult != ConnectivityResult.wifi) {
    ScaffoldMessenger.of(context).showSnackBar(new SnackBar(content: Text("noInternet".tr().toString())));
  }
}
class InitialPage extends State<InitialPageSend>{
  TextEditingController email = new TextEditingController();
  TextEditingController name = new TextEditingController();
  TextEditingController password = new TextEditingController();
  GoogleSignInAccount? googleAccount;
  GoogleSignIn googleSignIn = GoogleSignIn();
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance?.addPostFrameCallback((_) {
      String locale = Platform.localeName.split('_')[0];
      if(EasyLocalization.of(context)!.locale != Locale(locale))
        EasyLocalization.of(context)!.setLocale(Locale(locale));
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(leading: Container(), title: Text("title".tr().toString()), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
                   decoration: InputDecoration(labelText: 'pass'.tr().toString(), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)) ),
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
                  ScaffoldMessenger.of(context).showSnackBar(new SnackBar(content: Text('alertNotFound'.tr().toString())));
                  return;
                }
                if(document.get('email') == email.text && document.get('password') == password.text){
                  int result = await context.read<AuthenticationServices>().signIn(
                    email: email.text,
                    password: password.text,
                  );
                  if(result == 1){
                    Users user = new Users(email: document.get('email'), name: document.get('name'), password: document.get('password'), language: document.get('language'), xp: document.get('xp'), credit: document.get('credit'), method: document.get('method'), settings: document.get('settings')); 
                    toMainPage(context, user);
                  }
                  else
                    ScaffoldMessenger.of(context).showSnackBar(new SnackBar(content: Text('n')));
                }
                else
                    ScaffoldMessenger.of(context).showSnackBar(new SnackBar(content: Text('alertWrong'.tr().toString())));
              }
            }, child: Text('login'.tr().toString())),
            SizedBox(height: 25,),
            ElevatedButton.icon(style: ElevatedButton.styleFrom(primary: Colors.white), onPressed: ()async{ 
              var result;           
              await googleSignIn.signIn().then((userData){
                result = context.read<AuthenticationServices>().signIn(
                    email: userData!.email,
                    password: userData.id,
                );
                googleAccount = userData;
              });
              int read = await result;
              if(read == 1){
                DocumentReference doc = FirebaseFirestore.instance.collection("Users").doc(googleAccount!.email);
                var document = await doc.get();
                if(!document.exists)
                  return;
                Users user = new Users(email: document.get('email'), password: document.get('password'), name: document.get('name'), language: document.get('language'), xp: document.get('xp'), credit: document.get('credit'), method: document.get('method'), settings: document.get('settings'));   
                toMainPage(context, user);
              }
              else if(read == 0){
                await googleSignIn.signIn().then((userData){
                  result = context.read<AuthenticationServices>().signUp(
                      email: userData?.email,
                      password: userData?.id,
                  );
                  googleAccount = userData;
                });
                FirebaseFirestore.instance.collection('Users').doc(googleAccount!.email).set({'email': googleAccount!.email, 'name': googleAccount!.displayName, 'password': googleAccount!.id, 'credit': 0, 'status': 0, 'xp': 0, 'language': systemLanguage, 'method': 'google', 'settings': initialSettings});
                Users user = new Users(email: googleAccount!.email, password: googleAccount!.id, name: googleAccount!.displayName, language: systemLanguage, xp: 0, credit: 0, method: 'google', settings: initialSettings);  
                toMainPage(context, user);
                ScaffoldMessenger.of(context).showSnackBar(new SnackBar(content: Text('welcome'.tr().toString() + googleAccount!.displayName!)));
              }
            }, icon: Image.asset("assets/imgs/google.png", width: 16,), label: Text("loginGoogle".tr().toString(), style: TextStyle( color: Colors.black))),
            SizedBox(height: 50,),
            ElevatedButton.icon(onPressed: ()async{ 
              Navigator.of(context).push(MaterialPageRoute(builder: (context) =>RegisterPageSend()));
            }, icon: Icon(Icons.create_sharp), label: Text("noaccount".tr().toString(), )),
            SizedBox(height: 25,),
            ElevatedButton.icon(onPressed: ()async{ 
              Navigator.of(context).push(MaterialPageRoute(builder: (context) =>IntroductionPageSend()));
            }, icon: Icon(Icons.info_rounded), label: Text("help".tr().toString(), )),
          ],
        )
      ),
    );
  }
}
List<BottomNavigationBarItem> bottomNavItems(){
  return [
    BottomNavigationBarItem(
      icon: Icon(Icons.search),
      label: 'joinBtn'.tr().toString(),
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.create),
      label: 'createBtn'.tr().toString(),
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.account_box_rounded),
      label: 'account'.tr().toString(),
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.settings),
      label: 'settings'.tr().toString(),
    ),
  ];
}
void navigateBottom(BuildContext context, Users user){
  switch(selectedBottomIdx){
    case 0:
      Navigator.of(context).push(MaterialPageRoute(builder: (context) =>SearchPageSend(user: user)));        
      break;     
    case 1:
      Navigator.of(context).push(MaterialPageRoute(builder: (context) =>SetupPageSend(user: user)));
      break;     
    case 2:
      Navigator.of(context).push(MaterialPageRoute(builder: (context) =>AccountPageSend(user: user)));
      break;
    case 3:
      Navigator.of(context).push(MaterialPageRoute(builder: (context) =>SettingsPageSend(user: user)));
      break;        
  }
}
ButtonStyle btnStyle(BuildContext context, Color color){
   return ElevatedButton.styleFrom(minimumSize: Size(MediaQuery.of(context).size.width/4, (MediaQuery.of(context).size.height/4)), primary: color, elevation: color==Colors.white?50:0, shadowColor: Colors.black);
}
class RegisterPageSend extends StatefulWidget {
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
  String selectedLanguage = systemLanguage;
  GoogleSignInAccount? googleAccount;
  GoogleSignIn googleSignIn = GoogleSignIn();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: Text("signup".tr().toString()), centerTitle: true,),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
                   decoration: InputDecoration(labelText: "id".tr().toString(),  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)) ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                child: TextField(controller: password,
                  textAlign: TextAlign.center,
                   decoration: InputDecoration(labelText: "pass".tr().toString(), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)) ),
                ),
              ),
            ),
            ElevatedButton(onPressed: () async{
              email.text = email.text.trim();
              name.text = name.text.trim();
              password.text = password.text.trim();
              if(email.text != '' && name.text != '' && password.text != ''){
                int result = await context.read<AuthenticationServices>().signUp(
                    email: email.text,
                    password: password.text,
                );
                if(result == 1){
                  FirebaseFirestore.instance.collection('Users').doc(email.text).set({'email': email.text, 'name': name.text, 'password': password.text, 'status': 0, 'xp': 0, 'credit': 0, 'language': selectedLanguage, 'method': 'email', 'settings': initialSettings});
                  Users user = new Users(email: email.text, password: password.text, name: name.text, language: selectedLanguage, xp: 0, credit: 0, method: 'email', settings: initialSettings);  
                toMainPage(context, user);
                ScaffoldMessenger.of(context).showSnackBar(new SnackBar(content: Text('welcome'.tr().toString() + name.text)));
                }
                else{
                  ScaffoldMessenger.of(context).showSnackBar(new SnackBar(content: Text('alertFormat'.tr().toString())));
                }
              }
              else{
                ScaffoldMessenger.of(context).showSnackBar(new SnackBar(content: Text('alertFill'.tr().toString())));
              }
            }, child: Text('signup'.tr().toString())),
            SizedBox(height: 50,),
            ElevatedButton.icon(onPressed: ()async{ 
              Navigator.of(context).push(MaterialPageRoute(builder: (context) =>IntroductionPageSend()));
            }, icon: Icon(Icons.info_rounded), label: Text("help".tr().toString(), )),
            ],
        ),
      ),
    );
  }
}
void joinDialog(BuildContext context, String foundRoom, String currentPlayers, Users user) async{
  List<String> playersFound = new List.empty(growable: true);
  DocumentReference doc = FirebaseFirestore.instance.collection("Rooms").doc(foundRoom);
  Timer.periodic(new Duration(seconds: 1), (timer) async{ 
    var document = await doc.get();
    if(!document.exists){
      timer.cancel();
      return;
    }
    if(document.get('status') == 'playing'){
      var document = await doc.get();
      Navigator.of(context).push(MaterialPageRoute(builder: (context) =>GamePageSend(user, foundRoom, new Options(game: document.get('game'), multiplayer: true, duration: document.get('duration'), bestOf: document.get('bestOf'), increasingDiff: document.get('increasingDiff'), length: document.get('length')))));
      timer.cancel();
      timerPlayers?.cancel();
    }
  });
  FirebaseFirestore.instance.collection('Rooms').doc(foundRoom).update({'players': currentPlayers + user.name! + ', '});
  showDialog(context: context,  barrierDismissible: false, builder: (BuildContext context) {
    return StatefulBuilder(builder: (context, setState) {
        timerPlayers = Timer.periodic(new Duration(seconds: 1), (timer) async{
          var document = await doc.get();
          if(document.exists && document.get('status') == 'ready')  
            setState(() {
              playersFound = document.get('players').split(', ');                
            });
          else
            timer.cancel();
        });
      return AlertDialog(
          title: Center(child: Text("waitingStart".tr().toString())),
          content: Container(
            height: 125,
            child: Column(
              children: [
                Text((playersFound.length != 0?(playersFound.length - 2).toString():'0') + 'found'.tr().toString()),
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
                  timerPlayers?.cancel();
                  var document = await doc.get();
                  if(document.exists){
                    List<String> pls = currentPlayers.split(', ');
                    currentPlayers = '';
                    for(int i=0;i<pls.length - 1;i++)
                      if(pls[i] != user.email)
                        currentPlayers = currentPlayers + pls[i] + ', ';
                    doc.update({'players': currentPlayers});
                  }
                Navigator.pop(context);
            }, child: Text('abort'.tr().toString())),
              ],
            )
          ],
      );
    });
  });
}

Future<bool> logout(BuildContext context)async{
  showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Center(child: Text('alert'.tr().toString())),
      content: Text('alertLogout'.tr().toString()),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: Text('no'.tr().toString()),
              onPressed: () => Navigator.pop(c, false),
            ),
            SizedBox(width: 10,),
            ElevatedButton(
              child: Text('yes'.tr().toString()),
              onPressed: () async{
                await context.read<AuthenticationServices>().signOut();
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
}

class SearchPageSend extends StatefulWidget {
  final Users? user;
  SearchPageSend({@required this.user});
  @override
  State<StatefulWidget> createState() {
    return SearchPage(this.user);
  }
}
class SearchPage extends State<SearchPageSend> {
  Users? user;
  Timer? searchTimer;
  int selectedIdx = 0;
  SearchPage(this.user);
  @override
  void initState() {
    checkNetwork(context);
    if(configuration == null)
      configuration = new Configuration(this.user!.settings!);
    super.initState();
    SchedulerBinding.instance?.addPostFrameCallback((_) {
      if(EasyLocalization.of(context)!.locale != Locale(this.user!.language!))
        EasyLocalization.of(context)!.setLocale(Locale(this.user!.language!));
    });
  }
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async{
        return logout(context);
      },
      child: Scaffold(
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: bottomNavItems(),
          currentIndex: selectedBottomIdx,
          onTap: (int tappedIdx){
            if(selectedBottomIdx == tappedIdx)return;
            setState(() {
              selectedBottomIdx = tappedIdx;
            });
            navigateBottom(context, this.user!);
          },
        ),
        resizeToAvoidBottomInset: false,
        appBar: AppBar(title: Text('home'.tr().toString()),centerTitle: true,
          actions: [
            ElevatedButton.icon(onPressed: (){
              Navigator.of(context).push(MaterialPageRoute(builder: (context) =>IntroductionPageSend()));
            }, icon: Icon(Icons.help), label: Text('')),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                child: ElevatedButton.icon(onPressed: ()async{   
                  bool searching = false;
                  var foundRoom, currentPlayers;
                  searchTimer = Timer.periodic(new Duration(seconds: 1), (timer) async{
                    await FirebaseFirestore.instance.collection("Rooms").get().then((value) {
                      value.docs.forEach((result) {
                        if(result.get('status') == 'ready'){
                          timer.cancel();
                          foundRoom = result.id;
                          currentPlayers = result.get('players');
                        }
                      });
                    });  
                  if(foundRoom != null)
                    joinDialog(context, foundRoom, currentPlayers, this.user!);
                  else if(!searching){
                    searching = true;
                    showDialog(context: context,  barrierDismissible: false, builder: (BuildContext context) {
                      return StatefulBuilder(builder: (context, setState) {
                        return AlertDialog(
                            title: Center(child: Text("search".tr().toString(),)),
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
                                }, child:  Center(child: Text('abort'.tr().toString()))),
                            ],
                        );
                      });
                    });
                  }
                  });
                }, style: ElevatedButton.styleFrom(padding: EdgeInsets.all(16)), icon: Icon(Icons.speed_rounded ), label: Text('quickJoinBtn'.tr().toString(), style: TextStyle(fontSize: 30))),
              ),
              SizedBox(height: 25,),
              ElevatedButton.icon(onPressed: ()async{   
                Navigator.of(context).push(MaterialPageRoute(builder: (context) =>JoinGamePageSend(user: this.user,)));
              }, style: ElevatedButton.styleFrom(padding: EdgeInsets.all(16)), icon: Icon(Icons.search), label: Text('joinBtn'.tr().toString(), style: TextStyle(fontSize: 30))),
              SizedBox(height: 25,),
            ],
          ),
        ),
      ),
    );
  }
}

class JoinGamePageSend extends StatefulWidget{
  final Users? user;
  JoinGamePageSend({@required this.user});
  @override
  State<StatefulWidget> createState() {
    return JoinGamePage(this.user);
  }
}
class Room{
  String creator, currentPlayers;
  int? time, digit, bestOf;
  Room({required this.creator, required this.currentPlayers, required this.time, required this.digit, required this.bestOf});
}
class JoinGamePage extends State<JoinGamePageSend>{
  Users? user;
  List<Room> roomsFound = List.empty(growable: true);
  Timer? searchTimer;
  JoinGamePage(this.user);
  @override
  void initState() {
    searchTimer = Timer.periodic(new Duration(seconds: 3), (timer) async{
      List<Room> tmp=  List.empty(growable: true);
      roomsFound = List.empty(growable: true);
      await FirebaseFirestore.instance.collection("Rooms").get().then((value) {
          value.docs.forEach((result) async{
            if(result.get('status') == 'ready'){
              tmp.add(new Room(creator: result.id, currentPlayers: result.get('players'), time: result.get('duration'), digit: result.get('length'), bestOf: result.get('bestOf')));
            }
        });
        setState(() {
          roomsFound = tmp;
        });
      });  
    });
    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: ()async{
        searchTimer?.cancel();
        return true;
      },
      child: Scaffold(
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: bottomNavItems(),
          currentIndex: selectedBottomIdx,
          onTap: (int tappedIdx){
            if(selectedBottomIdx == tappedIdx)return;
            setState(() {
              selectedBottomIdx = tappedIdx;
            });
            navigateBottom(context, this.user!);
          },
        ),
        resizeToAvoidBottomInset: false,
        appBar: AppBar(title: Text('search'.tr().toString()),centerTitle: true,),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 25, 10, 10),
              child: LinearProgressIndicator(),
            ),
            FittedBox(
              fit: BoxFit.fitWidth,
              child: DataTable(
                showCheckboxColumn: false,
                columns: [
                  DataColumn(label: Text('creator'.tr().toString())),
                  DataColumn(label: Text('playerCount'.tr().toString())),
                  DataColumn(label: Text('time'.tr().toString())),
                  DataColumn(label: Text('digit'.tr().toString())),
                  DataColumn(label: Text('bestOf'.tr().toString())),
                ],
              rows: roomsFound.map<DataRow>((e) => DataRow(
                onSelectChanged: (selected){
                  searchTimer?.cancel();
                  joinDialog(context, e.creator, e.currentPlayers, this.user!);
                },
                cells: [
                  DataCell(Text(e.currentPlayers.split(', ')[0].toString(), textAlign: TextAlign.center,)),
                  DataCell(Text((e.currentPlayers.split(', ').length - 1).toString(), textAlign: TextAlign.center,)),
                  DataCell(Text(e.time.toString(), textAlign: TextAlign.center,)),
                  DataCell(Text(e.digit.toString(), textAlign: TextAlign.center,)),
                  DataCell(Text(e.bestOf.toString(), textAlign: TextAlign.center,)),
                ]
              )).toList(),
              ),
            ),
          ],
        )
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

  Future<int> getXp() async{
    DocumentReference docUser = FirebaseFirestore.instance.collection("Users").doc(this.user?.email);
    var documentUser = await docUser.get();
    return documentUser.get('xp');
  }
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: ()async{
        toMainPage(context, this.user!);
        return false;
      },
      child: Scaffold(
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items:  bottomNavItems(),
          currentIndex: selectedBottomIdx,
          onTap: (int tappedIdx){
            if(selectedBottomIdx == tappedIdx)return;
            setState(() {
              selectedBottomIdx = tappedIdx;
            });
            navigateBottom(context, this.user!);
          },
        ),
        appBar: AppBar(
          title: Text('account'.tr().toString()),centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 20, 10, 15),
              child: Row(
                children: [
                  Icon(Icons.credit_card_rounded),
                  SizedBox(width: 5,),
                  Text(this.user!.credit.toString(), style: TextStyle(fontSize: 16),),
                ],
              ) 
            ),
          ],
        ),
        body: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Text(this.user!.name!, textAlign: TextAlign.center, style: TextStyle(fontSize: 48),),
              ),
              SizedBox(height: 50,),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: FutureBuilder(future: getXp(), builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot){
                  if(snapshot.hasData){
                    double xp = snapshot.data/xpPerLevel;
                    int level = xp.toInt() + 1;
                    xp -= xp.toInt(); 
                    return Stack(children: [ClipRRect(borderRadius: BorderRadius.all(Radius.circular(10)), child: LinearProgressIndicator(value: xp, color: Colors.purple, minHeight: 50)), Padding(padding: const EdgeInsets.all(4.0), child: Center(child: Text('level'.tr().toString() + level.toString(), style: TextStyle(fontSize: 32, color: Colors.white),),),)]);
                  }
                  else
                    return LinearProgressIndicator(color: Colors.purple, minHeight: 50);
                }),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(style: ElevatedButton.styleFrom(padding: EdgeInsets.all(16)),onPressed: (){
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) =>UpdatePageSend(user: this.user,)));
                }, icon: Icon(Icons.update), label: Text('update'.tr().toString(), style: TextStyle(fontSize: 30))),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(style: ElevatedButton.styleFrom(padding: EdgeInsets.all(16)), onPressed: () async{
                  return await showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: Center(child: Text("delete".tr().toString())),
                      content: Text('alertDelete'.tr().toString(), textAlign: TextAlign.center,),
                      actions: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                            child: Text('no'.tr().toString()),
                            onPressed: () => Navigator.pop(c, false),
                          ),
                          SizedBox(width: 20,),
                            ElevatedButton(
                              child: Text('yes'.tr().toString()),
                              onPressed: () async{
                                await context.read<AuthenticationServices>().delete(email: this.user!.email, password: this.user!.password);
                                FirebaseFirestore.instance.collection('Users').doc(this.user!.email).delete();
                                Navigator.of(context).push(MaterialPageRoute(builder: (context) =>InitialPageSend()));
                              },
                            ),  
                          ],
                        ),
                      ],
                  ));
                }, icon: Icon(Icons.delete), label: Text('delete'.tr().toString(), style: TextStyle(fontSize: 30))),
              ),     
              FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(style: ElevatedButton.styleFrom(padding: EdgeInsets.all(16)), onPressed: () async{
                    logout(context);
                  }, icon: Icon(Icons.logout_rounded), label: Text('logout'.tr().toString(), style: TextStyle(fontSize: 30))),
                ),
              ),       
            ],
          ),
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
      appBar: AppBar(title: Text('update'.tr().toString()), centerTitle: true,),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if(this.user?.method == 'email')
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
                  child: TextField(controller: name,
                    textAlign: TextAlign.center,
                     decoration: InputDecoration(labelText: 'id'.tr().toString(), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                  ),
              ),
                ),
              if(this.user?.method == 'email')
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    child: TextField(controller: password,
                      textAlign: TextAlign.center,
                        decoration: InputDecoration(labelText: 'pass'.tr().toString(), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                ),
            ElevatedButton(onPressed: () async{
              if(this.user?.method == 'email'){
                await context.read<AuthenticationServices>().update(email: this.user!.email, password: this.user!.password, newEmail: email.text, newPassword: password.text);
                FirebaseFirestore.instance.collection("Users").doc(this.user?.email).delete();
                this.user = new Users(email: email.text!=''?email.text:this.user?.email, password: password.text!=''?password.text:this.user?.password, name: name.text!=''?name.text:this.user?.name, language: this.user?.language, xp: this.user!.xp, credit: this.user!.credit, method: this.user?.method, settings: this.user!.settings); 
                FirebaseFirestore.instance.collection('Users').doc(this.user?.email).set({'email': this.user?.email, 'name': this.user?.name, 'password': this.user?.password, 'status': 0, 'xp': this.user?.xp, 'credit': 0, 'language': this.user?.language, 'method':this.user?.method, 'settings': this.user?.settings}); 
              }
              else if(this.user?.method == 'google'){
                this.user?.name = name.text;
                FirebaseFirestore.instance.collection("Users").doc(this.user?.email).update({'name': this.user?.name});
              } 
              ScaffoldMessenger.of(context).showSnackBar(new SnackBar(content: Text('Hesap Guncellendi', textAlign: TextAlign.center)));
              toMainPage(context, this.user!);
            }, child: Text('apply'.tr().toString()))
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
  Timer? inactiveTimer;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state)  async{
    if(state == AppLifecycleState.paused){
      DocumentReference doc = FirebaseFirestore.instance.collection("Rooms").doc(this.user?.email);
      var document = await doc.get();
      if(document.exists && document.get('status') == 'ready'){
        FirebaseFirestore.instance.collection('Rooms').doc(this.user!.email).delete();
        toMainPage(context, user!);
      }
    }
    print(state);
  }
  Color increasingColor = Colors.black38;
  Color alertColor = Colors.transparent;
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async{
        toMainPage(context, user!);
        return false;
      },
      child: Scaffold(
        bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items:  bottomNavItems(),
        currentIndex: selectedBottomIdx,
        onTap: (int tappedIdx){
          if(selectedBottomIdx == tappedIdx)return;
          setState(() {
            selectedBottomIdx = tappedIdx;
          });
          navigateBottom(context, this.user!);
        },
      ),
        appBar: AppBar(
          leading: DropdownButton<String>(
            value: options.game,
            items: ['guess', 'another'].map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value.toString()),
              );
            }).toList(),
            onChanged: (String? value) {
              setState(() {
                options.game = value!;
              });
            },
          ),
          centerTitle: true,
          title: Text("createBtn".tr().toString()),
          actions: [
            ElevatedButton.icon(onPressed: (){
              Navigator.of(context).push(MaterialPageRoute(builder: (context) =>IntroductionPageSend()));
            }, icon: Icon(Icons.help), label: Text('')),
          ],
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            CheckboxListTile(
              title: Text("multiplayer".tr().toString(), style: TextStyle(fontSize: 24)),
              value: options.multiplayer,
              onChanged: (value) {
                setState(() {
                  options.multiplayer = value!;
                });
              },
              controlAffinity: ListTileControlAffinity.trailing, 
            ),
            ListTile(
              leading: Text('time'.tr().toString(), style: TextStyle(fontSize: 24),),
              trailing: DropdownButton<int>(
              value: options.duration,
              items: [15, 30, 45, 60, 120].map<DropdownMenuItem<int>>((int value) {
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
              leading: Text('digitLength'.tr().toString(), style: TextStyle(fontSize: 24),),
              trailing: DropdownButton<int>(
                value: options.length,
                items: [2, 3, 4, 5, 6, 7, 8, 9].map<DropdownMenuItem<int>>((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(value.toString(), style:TextStyle(color:Colors.black, fontSize: 24),),
                  );
                }).toList(),
                onChanged: (int? value) {
                  setState(() {
                    options.length = value!;
                  });
                },
              ),
            ),
            ListTile(
              leading: Text('bestOf'.tr().toString(), style: TextStyle(fontSize: 24),),
              tileColor: alertColor,
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
                    if(value == 1){
                      increasingColor = Colors.black38;
                      options.increasingDiff = false;
                    }
                    else
                      increasingColor = Colors.black;
                    options.bestOf = value!;
                  });
                },
              ),
            ),
            CheckboxListTile(
              title: Text("increasingDifficulty".tr().toString(), style: TextStyle(fontSize: 24, color: increasingColor)),
              value: options.increasingDiff,
              onChanged: (value) {
                setState(() {
                  if(increasingColor != Colors.black38)
                    options.increasingDiff = value!;
                  else{                      
                    alertColor = Theme.of(context).primaryColor;
                    Future.delayed(new Duration(seconds: 1), (){       
                      setState(() {
                        alertColor = Colors.transparent;
                      });   
                    });
                  }
                });
              },
              controlAffinity: ListTileControlAffinity.trailing, 
            ),
            ElevatedButton.icon(onPressed: (){
                if(options.multiplayer){
                  FirebaseFirestore.instance.collection('Rooms').doc(this.user!.email).set({'players': this.user!.name! + ', ', 'game': options.game, 'length': options.length, 'status': 'ready', 'won': '', 'bestOf': options.bestOf, 'duration': options.duration, 'roundInserted': false, 'increasingDiff': options.increasingDiff});
                  DocumentReference doc = FirebaseFirestore.instance.collection("Rooms").doc(this.user?.email);
                  List<String> playersFound = new List.empty(growable: true);
                  showDialog(context: context,  barrierDismissible: false, builder: (BuildContext context) {
                    return StatefulBuilder(builder: (context, setState) {
                        timerPlayers = Timer.periodic(new Duration(seconds: 5), (timer) async{
                          var document = await doc.get();
                          if(document.exists && document.get('status') == 'ready')
                            setState(() {
                              playersFound = document.get('players').split(', ');       
                              btnStartColor = playersFound.length > 2?Theme.of(context).primaryColor:Colors.grey;            
                            });
                          else
                            timer.cancel();
                        });
                        return AlertDialog(
                          title: Center(child: Text("searchPlayers".tr().toString(), textAlign: TextAlign.center)),
                          content: Container(
                            height: 125,
                            child: Column(
                              children: [
                                Text((playersFound.length != 0?(playersFound.length - 2).toString():'0') + 'found'.tr().toString(), textAlign: TextAlign.center,),
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
                            }, child: Text('abort'.tr().toString())),
                            SizedBox(width: 20,),
                            ElevatedButton(onPressed: (){
                              if(btnStartColor == Colors.grey)
                                return;
                              FirebaseFirestore.instance.collection('Rooms').doc(this.user?.email).update({'status': 'playing'});
                              Navigator.of(context).push(MaterialPageRoute(builder: (context) =>GamePageSend(user, this.user?.email, options)));
                            }, style: ElevatedButton.styleFrom(primary: btnStartColor),
                            child: Text('start'.tr().toString()))
                              ],
                            )
                          ],
                      );
                    });
                  });  
                }
                else{
                  FirebaseFirestore.instance.collection("Rooms").doc(this.user?.email).set({'players': this.user!.name! + ", ",'game': options.game, 'length': options.length, 'status': 'playing', 'won': '', 'bestOf': options.bestOf, 'roundInserted': false, 'increasingDiff': options.increasingDiff});
              Navigator.of(context).push(MaterialPageRoute(builder: (context) =>GamePageSend(user, this.user?.email, this.options)));
                }   
            }, style: ElevatedButton.styleFrom(padding: EdgeInsets.all(32)), icon: Icon(Icons.play_circle), label: Text('start'.tr().toString(), style: TextStyle(fontSize: 30)))
          ],
        ),
      ),
    );
  }
}
int findRandom(int? length){
  String ret = '';
  if(length != null) {
    for(int i=0;i<length;i++){
      bool unique = true;
      int currentRandom = 1 + Random().nextInt(10 - 1);
      for(int j=0;j<i;j++)
        if(currentRandom == int.parse(ret[j])){
          unique = false;
          break;
        }
      if(!unique){
        i--;
        continue;
      }
      ret += currentRandom.toString();
    }
    print("RET " + ret);
    return int.parse(ret);
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
  int currentDuration = 0, totalDuration = 0, roundCounter = 0;
  List<String>? otherPlayers;
  bool guessEnabled = true;
  String hint = '';
  GamePage(this.user, this.room, this.options);

  Future<List<String>> findPlayers(bool withWon) async{
    List<String> ret = new List.empty(growable: true);
    DocumentReference doc = FirebaseFirestore.instance.collection("Rooms").doc(this.room);
    var document = await doc.get();
    var players = document.get('players').split(', ');
    if(withWon){
      for(int i=0;i<players.length - 1;i++)
          ret.add(players[i]+":" +"0");
      List<String> wins =document.get('won').split('-');
      String currentWins = wins[wins.length - 1];
      if(currentWins != ''){
        List<String> playersWon = currentWins.split(', ');
        for(int i=0;i<ret.length;i++){
          for(int j=0;j<playersWon.length - 1;j++){
            String player = ret[i].split(':')[0];
            if(player == playersWon[j].split(':')[0])
              ret[i] = player + ':1';
          }
        }
      }
    }
    else
      for(int i=0;i<players.length - 1;i++)
       ret.add(players[i]);   
    return ret;
  }
  void initializeNumber()async{
    DocumentReference docs = FirebaseFirestore.instance.collection('Rooms').doc(this.room);
    var document = await docs.get();
    randomNumber = document.get('number');
    hint = 'guess'.tr().toString() + ' (' + randomNumber.toString().length.toString() + ")";
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
      if(configuration?.sound == 'true'){
        AudioCache ac = new AudioCache();
        await ac.play('sounds/success.mp3');
        ac.clearAll();
      }
      int score = (((randomNumber.toString().length/4) * currentDuration/(options!.duration * entryList[0].id)) * 100).toInt();
      DocumentReference doc = FirebaseFirestore.instance.collection("Rooms").doc(this.room);
      var document = await doc.get();
      var prevWinners = document.get('won');
      FirebaseFirestore.instance.collection('Rooms').doc(this.room).update({'won': prevWinners + this.user!.name! + ':' + score.toString() + ", "});
      DocumentReference docUser = FirebaseFirestore.instance.collection("Users").doc(this.user?.email);
      var documentUser = await docUser.get();
      this.user?.xp = documentUser.get('xp') + score;
      this.user?.credit = documentUser.get('credit') + totalDuration + score;
      FirebaseFirestore.instance.collection('Users').doc(this.user?.email).update({'xp': this.user?.xp, 'credit': this.user?.credit});
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
    return Expanded(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateColor.resolveWith((states) => Colors.black12),
          columns: [
            DataColumn(label: Text('name'.tr().toString())),
            DataColumn(label: Text('score'.tr().toString())),
          ],
          rows: userScore.map<DataRow>((e) => DataRow(
            cells: [
              DataCell(Text(e['user'].toString())),
              DataCell(Text(e['score'].toString())),
            ]
          )).toList(),
        ),
      ),
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
                if(cd == 0){
                  timer.cancel();
                  cd = -1;
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
              title: Center(child: Text("endRound".tr().toString())),
              content: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Center(child: displayNumber(),), SizedBox(height: 100,), Center(child: Text('nextRound'.tr().toString() + cd.toString(), textAlign: TextAlign.center),),],),
              actions: <Widget>[
                ElevatedButton(onPressed: (){
                  leaveGame();
                  Navigator.pop(context);
                  toMainPage(context, this.user!);
                },child: Center(child: Text("leave".tr().toString()))),           
              ],
            );
          });
        });
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
      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            contentPadding: EdgeInsets.zero,
            title: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 25),
              child: Center(child: Text("results".tr().toString())),
            ),
            content: Column(children: [displayNumber(), SizedBox(height: 25,), displayResult(userScore)]),
            actions: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(onPressed: (){
                Navigator.pop(context);
              },child: (Text("back".tr().toString()))),
              SizedBox(width: 20,),
              ElevatedButton(onPressed: (){
                if(this.room == this.user?.email)
                  FirebaseFirestore.instance.collection("Rooms").doc(this.room).delete();
                else
                  leaveGame();
                toMainPage(context, user!);
              },child: Center(child: Text("leave".tr().toString()))),
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
    if(!inserted){
      FirebaseFirestore.instance.collection("Rooms").doc(this.room).update({'roundInserted': true});
      var wins = document.get('won');
      bool increasingDiff = document.get('increasingDiff');
      roundCounter = wins.split('-').length;
      await FirebaseFirestore.instance.collection("Rooms").doc(this.room).update({'number': findRandom(options?.length), 'won': wins + '-'});
      if(increasingDiff)options?.length++;
      await FirebaseFirestore.instance.collection("Rooms").doc(this.room).update({'length': options?.length});
    }
    else
      options?.length = document.get('length');
    initializeNumber();
  }
  Future<bool> allWon() async{
    DocumentReference doc = FirebaseFirestore.instance.collection("Rooms").doc(this.room);
    var document = await doc.get();
    List<String> wins = document.get('won').split('-');
    var currentWins = wins[wins.length - 1];
    if(currentWins != ''){
      List<String> players = await findPlayers(false);
      if(currentWins.split(', ').length - 1 >= players.length)
        return true;
    }
    return false;
  }
  void startTimer() async{
    timerSeconds = new Timer.periodic(Duration(seconds: 1),  (Timer timer) async {
      if(currentDuration < 1){
          timer.cancel();
          roundEnd();
      }
      else{
        bool allDone = await allWon();  
        if(allDone){
          timerPlayers?.cancel();
          timer.cancel();
          roundEnd();
        }
        else{
          setState(() {
            currentDuration--;
            totalDuration++;
          });
        }
      }  
    });
  }
  @override
  void initState(){
    insertRound();
    currentDuration = options!.duration;
    startTimer();
    super.initState();
  }
  void leaveGame() async{
    if(options!.multiplayer){
      timerPlayers?.cancel();
      DocumentReference doc = FirebaseFirestore.instance.collection("Rooms").doc(this.room);
      var document = await doc.get();
      if(document.exists){
        List<String> players = document.get('players').split(', ');
        if(this.room == this.user?.email && players.length - 1 == 1)
          FirebaseFirestore.instance.collection('Rooms').doc(this.room).delete();
        else{
          String newPlayers = "";
          for(int i=0;i<players.length - 1;i++)
            if(players[i] != this.user?.name)
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
          title: Text("alertLeave".tr().toString()),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  child: Text('no'.tr().toString()),
                  onPressed: () => Navigator.pop(context, false),
                ),
                SizedBox(width: 10,),
                ElevatedButton(
                  child: Text('yes'.tr().toString()),
                  onPressed: () async{
                    timerSeconds?.cancel();
                    leaveGame();
                    Navigator.pop(context, true);
                    toMainPage(context, user!);
                  },
                ),
              ],
            ),
          ],
        )
      ));
  }
  Future<int> buyDigit(String email, int bought) async{
    DocumentReference doc = FirebaseFirestore.instance.collection("Users").doc(email);
    var document = await doc.get();
    int transaction = document.get('credit') - bought;
    if(transaction > -1){
      this.user?.credit = transaction;
      FirebaseFirestore.instance.collection("Users").doc(email).update({'credit': transaction});
    }
    return transaction;
  }
  Widget gameScreen(){
    return WillPopScope(
        onWillPop: (() => onWillPop(context)),
          child: Scaffold(
            appBar: AppBar(
              centerTitle: true,
              title: Text(roundCounter==0?'title'.tr().toString():'Round ' + roundCounter.toString() + "/" + this.options!.bestOf.toString()),
              actions: [
                IconButton(onPressed: () async{
                  if(!guessEnabled)return;
                  int remaining = await buyDigit(this.user!.email!, 100);
                  if(remaining > -1){
                    if(configuration?.sound == 'true'){
                      AudioCache ac = new AudioCache();
                      await ac.play('sounds/coin.mp3');
                      ac.clearAll();
                    }                    
                    String tmpRandom = randomNumber.toString(); 
                    bool hinted = false;
                    String addHint = '';
                    if(entryList.length > 0){
                      for(int i=0;i<tmpRandom.length;i++){
                        if(!hinted && tmpRandom[i] != entryList[0].tahmin[i]){
                          addHint += ' ' + tmpRandom[i];
                          hinted = true;
                          continue;
                        }
                        // if(tmpRandom[i] == entryList[0].tahmin[i])
                        //   addHint += ' ' + tmpRandom[i];
                        // else
                          addHint += ' _';
                      }
                    }
                    else{
                      addHint += tmpRandom[0];
                      for(int i=0;i<tmpRandom.length - 1;i++)
                        addHint  +=  ' _';
                    }
                    setState(() {
                      hint = 'guess'.tr().toString() + ' (' + randomNumber.toString().length.toString() + ") \t" + addHint;
                    });
                  }
                  else{
                    ScaffoldMessenger.of(context).showSnackBar(new SnackBar(content: Text('alertInsufficient'.tr().toString() + (-1 * remaining).toString())));
                  }
                }, icon: Icon(Icons.money, size: 30, color: guessEnabled?Colors.white:Colors.grey))
                
              ],
            ),
            body: Column(
              children: [  
                if(options!.multiplayer)
                  Row(
                   children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 5, 20, 0),
                        child: FutureBuilder(builder: (BuildContext context, AsyncSnapshot<List<String>> snapshot){
                          return snapshot.hasData?SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Container(
                              height: 50,                                           
                              child: ListView.builder(scrollDirection: Axis.horizontal,
                              shrinkWrap: true,
                              itemBuilder: (BuildContext context, int idx){
                                var userDone = snapshot.data![idx].split(':');
                                String user = userDone[0];
                                int done = int.parse(userDone[1]);
                                if(user != this.user!.name)
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
                                    child: FittedBox(fit: BoxFit.fitHeight, child: Column(children: [done==0?Container(width: 50, child: LinearProgressIndicator()):Icon(Icons.done, color: Theme.of(context).primaryColor,), Container(width: 25, height: 25, child: Image.asset('assets/imgs/account.png')), Text(user)],)),
                                  ) ;
                                return Container();
                              }, itemCount: snapshot.data?.length),
                            ),
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
                        maxLength: randomNumber.toString().length,
                        buildCounter: (context, {required currentLength, maxLength, required isFocused}) => null,
                        autofocus: true,
                        focusNode: focused,
                        controller: entered,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[1-9]'))],
                        enabled: guessEnabled,
                        textAlign: TextAlign.center,                
                        decoration: InputDecoration(labelText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)) ),
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
                        onPressed: (){                       print(randomNumber);
                          setState(() {                          
                            processInput();
                          });
                        }, 
                      child: Text("apply".tr().toString())),
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
                            DataColumn(label: Text('guess'.tr().toString())),
                            DataColumn(label: Text('right'.tr().toString())),
                            DataColumn(label: Text('wrong'.tr().toString())),
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
