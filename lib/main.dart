import 'dart:convert';
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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'account_settings.dart';
import 'explore.dart';

int randomNumber = 0, xpPerLevel = 100, selectedBottomIdx = 0;
Timer? timerSeconds, timerPlayers;
GetStorage introShown = GetStorage();
String systemLanguage = Platform.localeName.split('_')[0];
SharedPreferences? prefs;
bool currentlyScanning = false, signedOut = false;
String defaultPicture = 'assets/imgs/account.png';
Future<Users> findUser(email) async {
  DocumentReference doc =
      FirebaseFirestore.instance.collection("Users").doc(email);
  var document = await doc.get();
  Users ret = new Users(
      email: document.get('email'),
      password: document.get('password'),
      name: document.get('name'),
      picture: document.get('picture'),
      language: document.get('language'),
      xp: document.get('xp'),
      credit: document.get('credit'),
      method: document.get('method'));
  return ret;
}

void toMainPage(BuildContext context, Users user) {
  selectedBottomIdx = 0;
  Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => SearchPageSend(user: user)));
}

void _initPrefs() async {
  prefs = await SharedPreferences.getInstance();
  if (prefs?.getBool('scanInvite') == null) prefs!.setBool('scanInvite', true);
  if (prefs?.getBool('sound') == null) prefs!.setBool('sound', false);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await EasyLocalization.ensureInitialized();
  await GetStorage.init();
  _initPrefs();
  introShown.writeIfNull('displayed', false);
  runApp(EasyLocalization(supportedLocales: [
    Locale('tr'),
    Locale('en'),
  ], path: 'assets/translations', child: MyApp()));
}

class MyApp extends StatelessWidget {
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
          create: (context) =>
              context.read<AuthenticationServices>().authStateChanges,
          initialData: null,
        )
      ],
      child: MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          debugShowCheckedModeBanner: false,
          title: 'Sayi Bulmaca',
          theme: ThemeData(
            brightness: SchedulerBinding.instance.window.platformBrightness,
            appBarTheme: AppBarTheme(backgroundColor: Colors.pink),
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
                backgroundColor: Colors.pink,
                selectedItemColor: Colors.tealAccent,
                unselectedItemColor: Colors.white),
            primarySwatch: Colors.pink,
          ),
          home: AuthenticationWrapper()),
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final firebaseUser = context.watch<User?>();
    if (firebaseUser != null)
      return FutureBuilder(
        future: findUser(firebaseUser.email),
        builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
          if (snapshot.hasData) {
            signedOut = false;
            return SearchPageSend(user: snapshot.data);
          } else
            return Center(child: CircularProgressIndicator());
        },
      );
    else
      return introShown.read('displayed')
          ? InitialPageSend()
          : IntroductionPageSend();
  }
}

class InitialPageSend extends StatefulWidget {
  InitialPageSend();
  @override
  State<StatefulWidget> createState() {
    return InitialPage();
  }
}

void checkNetwork(BuildContext context) async {
  var connectivityResult = await (Connectivity().checkConnectivity());
  if (connectivityResult != ConnectivityResult.mobile &&
      connectivityResult != ConnectivityResult.wifi) {
    ScaffoldMessenger.of(context).showSnackBar(
        new SnackBar(content: Text("noInternet".tr().toString())));
  }
}

class InitialPage extends State<InitialPageSend> {
  TextEditingController email = new TextEditingController();
  TextEditingController name = new TextEditingController();
  TextEditingController password = new TextEditingController();
  GoogleSignInAccount? googleAccount;
  GoogleSignIn googleSignIn = GoogleSignIn();

  Future<void> _fbLogin() async {
    final LoginResult result = await FacebookAuth.instance.login();
    if (result.status == LoginStatus.success) {
      final userData = await FacebookAuth.instance.getUserData();
      final authResult = await context.read<AuthenticationServices>().signIn(
            email: userData['email'],
            password: userData['id'],
          );
      print(userData['picture']['data']['url']);
      Users user;
      if (authResult == 0) {
        await context.read<AuthenticationServices>().signUp(
              email: userData['email'],
              password: userData['id'],
            );
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(userData['email'])
            .set({
          'email': userData['email'],
          'name': userData['name'],
          'password': userData['id'],
          'picture': userData['picture']['data']['url'],
          'credit': 0,
          'status': 0,
          'xp': 0,
          'language': systemLanguage,
          'method': 'facebook'
        });
        user = new Users(
            email: userData['email'],
            password: userData['id'],
            name: userData['name'],
            picture: userData['picture']['data']['url'],
            language: systemLanguage,
            xp: 0,
            credit: 0,
            method: 'facebook');
      } else {
        var document = await FirebaseFirestore.instance
            .collection('Users')
            .doc(userData['email'])
            .get();
        user = new Users(
            email: document.get('email'),
            name: document.get('name'),
            password: document.get('password'),
            picture: document.get('picture'),
            language: document.get('language'),
            xp: document.get('xp'),
            credit: document.get('credit'),
            method: document.get('method'));
      }
    } else {
      print(result.status);
      print(result.message);
    }
  }

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      String locale = Platform.localeName.split('_')[0];
      if (EasyLocalization.of(context)!.locale != Locale(locale))
        EasyLocalization.of(context)!.setLocale(Locale(locale));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
          leading: Container(),
          title: Text("title".tr().toString()),
          centerTitle: true),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Image.asset(
                'assets/imgs/logo.png',
                height: 100,
                fit: BoxFit.contain,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                child: TextField(
                  controller: email,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                child: TextField(
                  controller: password,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                      labelText: 'pass'.tr().toString(),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ),
            ElevatedButton.icon(
                onPressed: () async {
                  if (email.text != "" && password.text != "") {
                    FocusScope.of(context).unfocus();
                    email.text = email.text.trim();
                    password.text = password.text.trim();
                    int result =
                        await context.read<AuthenticationServices>().signIn(
                              email: email.text,
                              password: password.text,
                            );
                    if (result == 1) {
                      DocumentReference doc = FirebaseFirestore.instance
                          .collection("Users")
                          .doc(email.text);
                      var document = await doc.get();
                      if (!document.exists) {
                        await FirebaseFirestore.instance
                            .collection('Users')
                            .doc(googleAccount!.email)
                            .set({
                          'email': document.get('email'),
                          'name': document.get('name'),
                          'password': document.get('password'),
                          'picture': document.get('picture'),
                          'credit': 0,
                          'status': 0,
                          'xp': 0,
                          'language': systemLanguage,
                          'method': 'google',
                        });
                        Users user = new Users(
                            email: document.get('email'),
                            password: document.get('password'),
                            name: document.get('name'),
                            picture: document.get('picture'),
                            language: systemLanguage,
                            xp: 0,
                            credit: 0,
                            method: 'email');
                        toMainPage(context, user);
                        return;
                      }
                      if (document.get('email') == email.text &&
                          document.get('password') == password.text) {
                        String picture = '';
                        try {
                          picture = document.get('picture');
                        } catch (e) {
                          await FirebaseFirestore.instance
                              .collection('Users')
                              .doc(document.get('email'))
                              .update({'picture': picture});
                        }
                        Users user = new Users(
                            email: document.get('email'),
                            name: document.get('name'),
                            password: document.get('password'),
                            picture: picture,
                            language: document.get('language'),
                            xp: document.get('xp'),
                            credit: document.get('credit'),
                            method: document.get('method'));
                        toMainPage(context, user);
                      } else
                        ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
                            content: Text('alertWrong'.tr().toString())));
                    } else
                      ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
                          content: Text('alertNotFound'.tr().toString())));
                  } else
                    ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
                        content: Text('alertFill'.tr().toString())));
                },
                label: Text('login'.tr().toString()),
                icon: Icon(Icons.login)),
            SizedBox(
              height: MediaQuery.of(context).size.height * .05,
            ),
            SignInButton(Buttons.Google, text: 'loginGoogle.'.tr(),
                onPressed: () async {
              var result;
              await googleSignIn.signIn().then((userData) async {
                result = await context.read<AuthenticationServices>().signIn(
                      email: userData!.email,
                      password: userData.id,
                    );
                googleAccount = userData;
              });
              int read = await result;
              print(read);
              if (read == 1) {
                DocumentReference doc = FirebaseFirestore.instance
                    .collection("Users")
                    .doc(googleAccount!.email);
                var document = await doc.get();
                if (!document.exists) return;
                Users user = new Users(
                    email: googleAccount!.email,
                    password: googleAccount!.id,
                    picture: googleAccount!.photoUrl,
                    name: googleAccount!.displayName,
                    language: document.get('language'),
                    xp: document.get('xp'),
                    credit: document.get('credit'),
                    method: document.get('method'));
                toMainPage(context, user);
              } else if (read == 0) {
                await googleSignIn.signIn().then((userData) async {
                  result = await context.read<AuthenticationServices>().signUp(
                        email: userData?.email,
                        password: userData?.id,
                      );
                  googleAccount = userData;
                });
                await FirebaseFirestore.instance
                    .collection('Users')
                    .doc(googleAccount!.email)
                    .set({
                  'email': googleAccount!.email,
                  'name': googleAccount!.displayName,
                  'password': googleAccount!.id,
                  'picture': googleAccount!.photoUrl,
                  'credit': 0,
                  'status': 0,
                  'xp': 0,
                  'language': systemLanguage,
                  'method': 'google'
                });
                Users user = new Users(
                    email: googleAccount!.email,
                    password: googleAccount!.id,
                    picture: googleAccount!.photoUrl,
                    name: googleAccount!.displayName,
                    language: systemLanguage,
                    xp: 0,
                    credit: 0,
                    method: 'google');
                toMainPage(context, user);
              }
            }),
            SignInButton(
              Buttons.Facebook,
              text: "loginFacebook".tr(),
              onPressed: () async {
                await _fbLogin();
              },
            ),
            SizedBox(
              height: 20,
            ),
            ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => RegisterPageSend()));
                },
                icon: Icon(Icons.create_sharp),
                label: Text(
                  "noaccount".tr().toString(),
                )),
            SizedBox(
              height: 25,
            ),
            ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => IntroductionPageSend()));
                },
                icon: Icon(Icons.info_rounded),
                label: Text(
                  "help".tr().toString(),
                )),
          ],
        ),
      ),
    );
  }
}

List<BottomNavigationBarItem> bottomNavItems() {
  return [
    BottomNavigationBarItem(
      icon: Icon(Icons.search),
      label: 'joinBtmBtn'.tr().toString(),
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.create),
      label: 'createBtn'.tr().toString(),
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.people_alt),
      label: 'explore'.tr().toString(),
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

void navigateBottom(BuildContext context, Users user) {
  switch (selectedBottomIdx) {
    case 0:
      Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => SearchPageSend(user: user)));
      break;
    case 1:
      Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => SetupPageSend(user: user)));
      break;
    case 2:
      Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => ExplorePageSend(user: user)));
      break;
    case 3:
      Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => AccountPageSend(user: user)));
      break;
    case 4:
      Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => SettingsPageSend(user: user)));
      break;
  }
}

ButtonStyle btnStyle(BuildContext context, Color color) {
  return ElevatedButton.styleFrom(
      minimumSize: Size(MediaQuery.of(context).size.width / 4,
          (MediaQuery.of(context).size.height / 4)),
      primary: color,
      elevation: color == Colors.white ? 50 : 0,
      shadowColor: Colors.black);
}

class RegisterPageSend extends StatefulWidget {
  RegisterPageSend();
  @override
  State<StatefulWidget> createState() {
    return RegisterPage();
  }
}

class RegisterPage extends State<RegisterPageSend> {
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
      appBar: AppBar(
        title: Text("signup".tr().toString()),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                child: TextField(
                  controller: email,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                child: TextField(
                  controller: name,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                      labelText: "id".tr().toString(),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                child: TextField(
                  controller: password,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                      labelText: "pass".tr().toString(),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                email.text = email.text.trim();
                name.text = name.text.trim();
                password.text = password.text.trim();
                if (email.text != '' &&
                    name.text != '' &&
                    password.text != '') {
                  int result =
                      await context.read<AuthenticationServices>().signUp(
                            email: email.text,
                            password: password.text,
                          );
                  if (result == 1) {
                    FirebaseFirestore.instance
                        .collection('Users')
                        .doc(email.text)
                        .set({
                      'email': email.text,
                      'name': name.text,
                      'password': password.text,
                      'status': 0,
                      'xp': 0,
                      'credit': 0,
                      'language': selectedLanguage,
                      'method': 'email'
                    });
                    Users user = new Users(
                        email: email.text,
                        password: password.text,
                        name: name.text,
                        language: selectedLanguage,
                        xp: 0,
                        credit: 0,
                        method: 'email');
                    toMainPage(context, user);
                    ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
                        content: Text('welcome'.tr().toString() + name.text)));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
                        content: Text('alertFormat'.tr().toString())));
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      new SnackBar(content: Text('alertFill'.tr().toString())));
                }
              },
              label: Text('signup'.tr().toString()),
              icon: Icon(Icons.add_circle_outlined),
            ),
            SizedBox(
              height: 50,
            ),
            ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => IntroductionPageSend()));
                },
                icon: Icon(Icons.info_rounded),
                label: Text(
                  "help".tr().toString(),
                )),
          ],
        ),
      ),
    );
  }
}

void joinDialog(BuildContext context, String foundRoom, List currentPlayers,
    Users user) async {
  List playersFound = new List.empty(growable: true);
  DocumentReference doc =
      FirebaseFirestore.instance.collection("Rooms").doc(foundRoom);
  Timer.periodic(new Duration(seconds: 1), (timer) async {
    var document = await doc.get();
    if (!document.exists) {
      timer.cancel();
      return;
    }
    if (document.get('status') == 'playing') {
      var document = await doc.get();
      Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => GamePageSend(
              user,
              foundRoom,
              new Options(
                  game: document.get('game'),
                  multiplayer: true,
                  duration: document.get('duration'),
                  bestOf: document.get('bestOf'),
                  increasingDiff: document.get('increasingDiff'),
                  length: document.get('length')))));
      timer.cancel();
      timerPlayers?.cancel();
    }
  });
  currentPlayers.add(jsonEncode(user));
  FirebaseFirestore.instance.collection('Rooms').doc(foundRoom).update({
    'players': currentPlayers,
    'scores': List.filled(currentPlayers.length, '')
  });
  showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setState) {
          timerPlayers =
              Timer.periodic(new Duration(seconds: 1), (timer) async {
            var document = await doc.get();
            if (document.exists && document.get('status') == 'ready')
              setState(() {
                playersFound = document.get('players');
              });
          });
          return AlertDialog(
            title: Center(child: Text("waitingStart".tr().toString())),
            content: Container(
              height: 125,
              child: Column(
                children: [
                  Text((playersFound.length != 0
                          ? (playersFound.length - 1).toString()
                          : '0') +
                      'found'.tr().toString()),
                  SizedBox(
                    height: 50,
                  ),
                  CircularProgressIndicator(),
                ],
              ),
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                      onPressed: () async {
                        timerPlayers?.cancel();
                        var document = await doc.get();
                        if (document.exists) {
                          List pls = currentPlayers;
                          currentPlayers = List.empty(growable: true);
                          for (int i = 0; i < pls.length - 1; i++)
                            if (pls[i] != user.email)
                              currentPlayers.add(pls[i]);
                          doc.update({'players': currentPlayers});
                        }
                        Navigator.pop(context);
                      },
                      child: Text('abort'.tr().toString())),
                ],
              )
            ],
          );
        });
      });
}

Future<bool> logout(BuildContext context) async {
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
            SizedBox(
              width: 10,
            ),
            ElevatedButton(
              child: Text('yes'.tr().toString()),
              onPressed: () async {
                await context.read<AuthenticationServices>().signOut();
                Navigator.pop(c, false);
                signedOut = true;
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => InitialPageSend()));
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
    scanInvites(this.user, context);
    super.initState();
    print(user!);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (EasyLocalization.of(context)!.locale != Locale(this.user!.language!))
        EasyLocalization.of(context)!.setLocale(Locale(this.user!.language!));
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return logout(context);
      },
      child: Scaffold(
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: bottomNavItems(),
          currentIndex: selectedBottomIdx,
          onTap: (int tappedIdx) {
            if (selectedBottomIdx == tappedIdx) return;
            setState(() {
              selectedBottomIdx = tappedIdx;
            });
            navigateBottom(context, this.user!);
          },
        ),
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Text('title'.tr().toString()),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => IntroductionPageSend()));
              },
              icon: Icon(Icons.help),
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                child: ElevatedButton.icon(
                    onPressed: () async {
                      bool searching = false;
                      var foundRoom, currentPlayers;
                      searchTimer = Timer.periodic(new Duration(seconds: 1),
                          (timer) async {
                        await FirebaseFirestore.instance
                            .collection("Rooms")
                            .get()
                            .then((value) {
                          value.docs.forEach((result) {
                            if (result.get('status') == 'ready') {
                              timer.cancel();
                              foundRoom = result.id;
                              currentPlayers = result.get('players');
                            }
                          });
                        });
                        if (foundRoom != null)
                          joinDialog(
                              context, foundRoom, currentPlayers, this.user!);
                        else if (!searching) {
                          searching = true;
                          showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (BuildContext context) {
                                return StatefulBuilder(
                                    builder: (context, setState) {
                                  return AlertDialog(
                                    title: Center(
                                        child: Text(
                                      "search".tr().toString(),
                                    )),
                                    content: Container(
                                      height: 125,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      ElevatedButton(
                                          onPressed: () async {
                                            searchTimer?.cancel();
                                            Navigator.pop(context);
                                          },
                                          child: Center(
                                              child: Text(
                                                  'abort'.tr().toString()))),
                                    ],
                                  );
                                });
                              });
                        }
                      });
                    },
                    style:
                        ElevatedButton.styleFrom(padding: EdgeInsets.all(16)),
                    icon: Icon(Icons.speed_rounded),
                    label: Text('quickJoinBtn'.tr().toString(),
                        style: TextStyle(fontSize: 30))),
              ),
              SizedBox(
                height: 25,
              ),
              ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => JoinGamePageSend(
                              user: this.user,
                            )));
                  },
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.all(16)),
                  icon: Icon(Icons.search),
                  label: Text('joinBtn'.tr().toString(),
                      style: TextStyle(fontSize: 30))),
              SizedBox(
                height: 25,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class JoinGamePageSend extends StatefulWidget {
  final Users? user;
  JoinGamePageSend({@required this.user});
  @override
  State<StatefulWidget> createState() {
    return JoinGamePage(this.user);
  }
}

class Room {
  String creator;
  List currentPlayers;
  int? time, digit, bestOf;
  Room(
      {required this.creator,
      required this.currentPlayers,
      required this.time,
      required this.digit,
      required this.bestOf});
}

class JoinGamePage extends State<JoinGamePageSend> {
  Users? user;
  List<Room> roomsFound = List.empty(growable: true);
  Timer? searchTimer;
  JoinGamePage(this.user);
  @override
  void initState() {
    searchTimer = Timer.periodic(new Duration(seconds: 3), (timer) async {
      List<Room> tmp = List.empty(growable: true);
      roomsFound = List.empty(growable: true);
      await FirebaseFirestore.instance.collection("Rooms").get().then((value) {
        value.docs.forEach((result) async {
          if (result.get('status') == 'ready') {
            tmp.add(new Room(
                creator: result.id,
                currentPlayers: result.get('players'),
                time: result.get('duration'),
                digit: result.get('length'),
                bestOf: result.get('bestOf')));
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
      onWillPop: () async {
        searchTimer?.cancel();
        return true;
      },
      child: Scaffold(
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            items: bottomNavItems(),
            currentIndex: selectedBottomIdx,
            onTap: (int tappedIdx) {
              if (selectedBottomIdx == tappedIdx) return;
              setState(() {
                selectedBottomIdx = tappedIdx;
              });
              navigateBottom(context, this.user!);
            },
          ),
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            title: Text('search'.tr().toString()),
            centerTitle: true,
          ),
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
                  rows: roomsFound
                      .map<DataRow>((e) => DataRow(
                              onSelectChanged: (selected) {
                                searchTimer?.cancel();
                                joinDialog(context, e.creator, e.currentPlayers,
                                    this.user!);
                              },
                              cells: [
                                DataCell(Text(
                                  jsonDecode(e.currentPlayers.first)['name'],
                                  textAlign: TextAlign.center,
                                )),
                                DataCell(Text(
                                  (e.currentPlayers.length).toString(),
                                  textAlign: TextAlign.center,
                                )),
                                DataCell(Text(
                                  e.time.toString(),
                                  textAlign: TextAlign.center,
                                )),
                                DataCell(Text(
                                  e.digit.toString(),
                                  textAlign: TextAlign.center,
                                )),
                                DataCell(Text(
                                  e.bestOf.toString(),
                                  textAlign: TextAlign.center,
                                )),
                              ]))
                      .toList(),
                ),
              ),
            ],
          )),
    );
  }
}

class AccountPageSend extends StatefulWidget {
  final Users? user;
  AccountPageSend({@required this.user});
  @override
  State<StatefulWidget> createState() {
    return AccountPage(this.user);
  }
}

class AccountPage extends State<AccountPageSend> {
  Users? user;
  AccountPage(this.user);

  Future<int> getXp() async {
    try {
      DocumentReference docUser =
          FirebaseFirestore.instance.collection("Users").doc(this.user?.email);
      var documentUser = await docUser.get();
      return documentUser.get('xp');
    } catch (e) {
      return -1;
    }
  }

  @override
  void initState() {
    print(user);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        toMainPage(context, this.user!);
        return false;
      },
      child: Scaffold(
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: bottomNavItems(),
          currentIndex: selectedBottomIdx,
          onTap: (int tappedIdx) {
            if (selectedBottomIdx == tappedIdx) return;
            setState(() {
              selectedBottomIdx = tappedIdx;
            });
            navigateBottom(context, this.user!);
          },
        ),
        appBar: AppBar(
          title: Text('account'.tr().toString()),
          centerTitle: true,
          actions: [
            Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 10, 15),
                child: Row(
                  children: [
                    Icon(Icons.credit_card_rounded),
                    SizedBox(
                      width: 5,
                    ),
                    Text(
                      this.user!.credit.toString(),
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                )),
          ],
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            user!.picture! != ''
                ? Image.network(
                    user!.picture!,
                    width: 100,
                  )
                : Container(),
            Text(
              this.user!.name!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 48),
            ),
            FutureBuilder(
                future: getXp(),
                builder:
                    (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                  if (snapshot.hasData) {
                    double xp = snapshot.data / xpPerLevel;
                    int level = xp.toInt() + 1;
                    xp -= xp.toInt();
                    return Stack(children: [
                      ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          child: LinearProgressIndicator(
                              value: xp, minHeight: 50)),
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Center(
                          child: Text(
                            'level'.tr().toString() + level.toString(),
                            style: TextStyle(fontSize: 32, color: Colors.white),
                          ),
                        ),
                      )
                    ]);
                  } else
                    return LinearProgressIndicator(
                        color: Colors.purple, minHeight: 50);
                }),
            FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                    style:
                        ElevatedButton.styleFrom(padding: EdgeInsets.all(16)),
                    onPressed: () async {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) =>
                              AccountSettingsPageSend(user: user)));
                    },
                    icon: Icon(Icons.settings_applications),
                    label: Text('account'.tr() + ' ' + 'settings'.tr(),
                        style: TextStyle(fontSize: 30))),
              ),
            ),
            FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                    style:
                        ElevatedButton.styleFrom(padding: EdgeInsets.all(16)),
                    onPressed: () async {
                      logout(context);
                    },
                    icon: Icon(Icons.logout_rounded),
                    label: Text('logout'.tr().toString(),
                        style: TextStyle(fontSize: 30))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UpdatePageSend extends StatefulWidget {
  final Users? user;
  UpdatePageSend({@required this.user});
  @override
  State<StatefulWidget> createState() {
    return UpdatePage(this.user);
  }
}

class UpdatePage extends State<UpdatePageSend> {
  Users? user;
  var email = TextEditingController();
  var name = TextEditingController();
  var password = TextEditingController();
  UpdatePage(this.user);
  @override
  Widget build(BuildContext context) {
    return Center(
        child: Scaffold(
      appBar: AppBar(
        title: Text('update'.tr().toString()),
        centerTitle: true,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (this.user?.method == 'email')
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      child: TextField(
                        controller: email,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10))),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    child: TextField(
                      controller: name,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                          labelText: 'id'.tr().toString(),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                ),
                if (this.user?.method == 'email')
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      child: TextField(
                        controller: password,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                            labelText: 'pass'.tr().toString(),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10))),
                      ),
                    ),
                  ),
                ElevatedButton(
                    onPressed: () async {
                      if (this.user?.method == 'email') {
                        await context.read<AuthenticationServices>().update(
                            email: this.user!.email,
                            password: this.user!.password,
                            newEmail: email.text,
                            newPassword: password.text);
                        FirebaseFirestore.instance
                            .collection("Users")
                            .doc(this.user?.email)
                            .delete();
                        this.user = new Users(
                            email: email.text != ''
                                ? email.text
                                : this.user?.email,
                            password: password.text != ''
                                ? password.text
                                : this.user?.password,
                            name: name.text != '' ? name.text : this.user?.name,
                            language: this.user?.language,
                            xp: this.user!.xp,
                            credit: this.user!.credit,
                            method: this.user?.method);
                        FirebaseFirestore.instance
                            .collection('Users')
                            .doc(this.user?.email)
                            .set({
                          'email': this.user?.email,
                          'name': this.user?.name,
                          'password': this.user?.password,
                          'status': 0,
                          'xp': this.user?.xp,
                          'credit': 0,
                          'language': this.user?.language,
                          'method': this.user?.method,
                        });
                      } else if (this.user?.method == 'google') {
                        this.user?.name = name.text;
                        FirebaseFirestore.instance
                            .collection("Users")
                            .doc(this.user?.email)
                            .update({'name': this.user?.name});
                      }
                      ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
                          content: Text('Hesap Guncellendi',
                              textAlign: TextAlign.center)));
                      toMainPage(context, this.user!);
                    },
                    child: Text('apply'.tr().toString()))
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

class SetupPage extends State<SetupPageSend> with WidgetsBindingObserver {
  Users? user;
  Color btnStartColor = Colors.grey;
  Options options = new Options.empty();
  List<String> invited = List.empty(growable: true);
  List friends = List.empty(growable: true);
  SetupPage(this.user);
  void _loadFriends() async {
    DocumentReference docRef =
        FirebaseFirestore.instance.collection("Users").doc(user!.email!);
    var doc = await docRef.get();
    friends = List.empty(growable: true);
    try {
      friends = doc.get('friends');
    } catch (e) {
      return null;
    }
  }

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    options.multiplayer = (prefs?.getBool('multiplayer') == null
        ? options.multiplayer
        : prefs?.getBool('multiplayer')!)!;
    options.duration = (prefs?.getInt('duration') == null
        ? options.duration
        : prefs?.getInt('duration')!)!;
    options.length = (prefs?.getInt('length') == null
        ? options.length
        : prefs?.getInt('length')!)!;
    options.bestOf = (prefs?.getInt('bestOf') == null
        ? options.bestOf
        : prefs?.getInt('bestOf')!)!;
    options.increasingDiff = (prefs?.getBool('increasingDiff') == null
        ? options.increasingDiff
        : prefs?.getBool('increasingDiff')!)!;
    _loadFriends();
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Timer? inactiveTimer;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      final authResult = await context.read<AuthenticationServices>().signIn(
            email: this.user?.email,
            password: this.user?.password,
          );
      if (authResult == 1) {
        DocumentReference doc = FirebaseFirestore.instance
            .collection("Rooms")
            .doc(this.user?.email);
        var document = await doc.get();
        if (document.exists && document.get('status') == 'ready') {
          FirebaseFirestore.instance
              .collection('Rooms')
              .doc(this.user!.email)
              .delete();
          toMainPage(context, user!);
        }
      }
    }
    print(state);
  }

  void popInvites() async {
    invited.forEach((element) async {
      DocumentReference docRef =
          FirebaseFirestore.instance.collection("Users").doc(element);
      var doc = await docRef.get();
      List ins = doc.get('invite');
      ins.removeWhere((element) => element == user!.email!);
      FirebaseFirestore.instance
          .collection("Users")
          .doc(element)
          .update({'invite': ins});
    });
    invited = List.empty(growable: true);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        toMainPage(context, user!);
        return false;
      },
      child: Scaffold(
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: bottomNavItems(),
          currentIndex: selectedBottomIdx,
          onTap: (int tappedIdx) {
            if (selectedBottomIdx == tappedIdx) return;
            setState(() {
              selectedBottomIdx = tappedIdx;
            });
            navigateBottom(context, this.user!);
          },
        ),
        appBar: AppBar(
          centerTitle: true,
          title: Text("setup".tr().toString()),
          actions: [
            IconButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => IntroductionPageSend()));
              },
              icon: Icon(Icons.help),
            ),
          ],
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            CheckboxListTile(
              title: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 20, 0),
                    child: Icon(Icons.swap_horizontal_circle),
                  ),
                  Text("multiplayer".tr().toString(),
                      style: TextStyle(fontSize: 24))
                ],
              ),
              value: options.multiplayer,
              onChanged: (value) {
                setState(() {
                  options.multiplayer = value!;
                });
              },
              controlAffinity: ListTileControlAffinity.trailing,
            ),
            ListTile(
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(Icons.timelapse),
              ),
              title: Text(
                'time'.tr().toString(),
                style: TextStyle(fontSize: 24),
              ),
              trailing: DropdownButton<int>(
                value: options.duration,
                items: [15, 30, 45, 60, 120]
                    .map<DropdownMenuItem<int>>((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(
                      value.toString(),
                      style: TextStyle(fontSize: 24),
                    ),
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
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(Icons.height),
              ),
              title: Text(
                'digitLength'.tr().toString(),
                style: TextStyle(fontSize: 24),
              ),
              trailing: DropdownButton<int>(
                value: options.length,
                items: [2, 3, 4, 5, 6, 7, 8, 9]
                    .map<DropdownMenuItem<int>>((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(
                      value.toString(),
                      style: TextStyle(fontSize: 24),
                    ),
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
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                child: Icon(Icons.numbers_rounded),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'bestOf'.tr().toString(),
                    style: TextStyle(fontSize: 24),
                  ),
                  DropdownButton<int>(
                    value: options.bestOf,
                    items: [1, 3, 5].map<DropdownMenuItem<int>>((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text(
                          value.toString(),
                          style: TextStyle(fontSize: 24),
                        ),
                      );
                    }).toList(),
                    onChanged: (int? value) {
                      setState(() {
                        if (value == 1) {
                          options.increasingDiff = false;
                        }
                        options.bestOf = value!;
                      });
                    },
                  ),
                ],
              ),
              subtitle: CheckboxListTile(
                title: Text("increasingDifficulty".tr()),
                value: options.increasingDiff,
                onChanged: options.bestOf < 2
                    ? null
                    : (value) {
                        setState(() {
                          options.increasingDiff = value!;
                        });
                      },
              ),
            ),
            ElevatedButton.icon(
                onPressed: () async {
                  if (options.multiplayer) {
                    FirebaseFirestore.instance
                        .collection('Rooms')
                        .doc(this.user!.email)
                        .set({
                      'players': List.filled(1, jsonEncode(this.user)),
                      'game': options.game,
                      'length': options.length,
                      'status': 'ready',
                      'bestOf': options.bestOf,
                      'scores': List.filled(1, ''),
                      'duration': options.duration,
                      'roundInserted': false,
                      'increasingDiff': options.increasingDiff
                    });
                    DocumentReference doc = FirebaseFirestore.instance
                        .collection("Rooms")
                        .doc(this.user?.email);
                    List playersFound = new List.empty(growable: true);
                    showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext context) {
                          return StatefulBuilder(
                              builder: (context, setInnerState) {
                            timerPlayers = Timer.periodic(
                                new Duration(seconds: 5), (timer) async {
                              var document = await doc.get();
                              if (document.exists &&
                                  document.get('status') == 'ready')
                                setInnerState(() {
                                  playersFound = document.get('players');
                                });
                              else
                                timer.cancel();
                            });
                            return AlertDialog(
                              title: Center(
                                  child: Text("searchPlayers".tr().toString(),
                                      textAlign: TextAlign.center)),
                              content: Container(
                                height: 125,
                                child: Column(
                                  children: [
                                    Text(
                                      (playersFound.length != 0
                                              ? (playersFound.length - 1)
                                                  .toString()
                                              : '0') +
                                          'found'.tr().toString(),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(
                                      height: 50,
                                    ),
                                    CircularProgressIndicator(),
                                  ],
                                ),
                              ),
                              actions: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton(
                                        onPressed: () {
                                          timerPlayers?.cancel();
                                          FirebaseFirestore.instance
                                              .collection('Rooms')
                                              .doc(this.user!.email)
                                              .delete();
                                          Navigator.pop(context);
                                          popInvites();
                                        },
                                        child: Text('abort'.tr().toString())),
                                    Padding(
                                      padding:
                                          const EdgeInsets.fromLTRB(4, 0, 4, 0),
                                      child: friends.isEmpty
                                          ? null
                                          : ElevatedButton(
                                              onPressed: () async {
                                                showDialog(
                                                    context: context,
                                                    builder: (context) {
                                                      return AlertDialog(
                                                        title: Text(
                                                          'friends'.tr() +
                                                              " " +
                                                              'invite'.tr(),
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                        content: SizedBox(
                                                          height: MediaQuery.of(
                                                                      context)
                                                                  .size
                                                                  .height *
                                                              .3,
                                                          width: MediaQuery.of(
                                                                      context)
                                                                  .size
                                                                  .width *
                                                              .7,
                                                          child:
                                                              StatefulBuilder(
                                                            builder: (BuildContext
                                                                    context,
                                                                void Function(
                                                                        void
                                                                            Function())
                                                                    setState) {
                                                              return ListView
                                                                  .builder(
                                                                      shrinkWrap:
                                                                          true,
                                                                      itemCount:
                                                                          friends
                                                                              .length,
                                                                      itemBuilder:
                                                                          (BuildContext context,
                                                                              int idx) {
                                                                        return ListTile(
                                                                          title: Text(friends[idx]
                                                                              .split('@')
                                                                              .first),
                                                                          trailing:
                                                                              ElevatedButton.icon(
                                                                            icon:
                                                                                Icon(Icons.send_outlined),
                                                                            label:
                                                                                Text('invite'.tr()),
                                                                            onPressed:
                                                                                () async {
                                                                              List invites = List.empty(growable: true);
                                                                              DocumentReference docRef = FirebaseFirestore.instance.collection("Users").doc(friends[idx]);
                                                                              var doc = await docRef.get();
                                                                              try {
                                                                                invites = doc.get('invite');
                                                                              } catch (e) {}
                                                                              invites.add(user!.email!);
                                                                              FirebaseFirestore.instance.collection("Users").doc(friends[idx]).update({
                                                                                'invite': invites
                                                                              });
                                                                              setState(() {
                                                                                invited.add(friends[idx]);
                                                                              });
                                                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('sentInvite'.tr() + ': ' + friends[idx])));
                                                                              Navigator.pop(context);
                                                                            },
                                                                          ),
                                                                        );
                                                                      });
                                                            },
                                                          ),
                                                        ),
                                                      );
                                                    });
                                              },
                                              child: Text('invite'.tr())),
                                    ),
                                    ElevatedButton(
                                        onPressed: playersFound.length > 1
                                            ? () {
                                                FirebaseFirestore.instance
                                                    .collection('Rooms')
                                                    .doc(this.user?.email)
                                                    .update(
                                                        {'status': 'playing'});
                                                Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                        builder: (context) =>
                                                            GamePageSend(
                                                                user,
                                                                this
                                                                    .user
                                                                    ?.email,
                                                                options)));
                                                popInvites();
                                              }
                                            : null,
                                        child: Text('start'.tr().toString()))
                                  ],
                                )
                              ],
                            );
                          });
                        });
                  } else {
                    FirebaseFirestore.instance
                        .collection("Rooms")
                        .doc(this.user?.email)
                        .set({
                      'players': List.filled(1, jsonEncode(this.user)),
                      'game': options.game,
                      'length': options.length,
                      'status': 'playing',
                      'scores': List.filled(1, ''),
                      'bestOf': options.bestOf,
                      'roundInserted': false,
                      'increasingDiff': options.increasingDiff
                    });
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => GamePageSend(
                            user, this.user?.email, this.options)));
                  }
                  prefs?.setBool('multiplayer', options.multiplayer);
                  prefs?.setInt('duration', options.duration);
                  prefs?.setInt('length', options.length);
                  prefs?.setInt('bestOf', options.bestOf);
                  prefs?.setBool('increasingDiff', options.increasingDiff);
                },
                style: ElevatedButton.styleFrom(padding: EdgeInsets.all(32)),
                icon: Icon(Icons.play_circle),
                label: Text('start'.tr().toString(),
                    style: TextStyle(fontSize: 30)))
          ],
        ),
      ),
    );
  }
}

int findRandom(int? length) {
  String ret = '';
  if (length != null) {
    for (int i = 0; i < length; i++) {
      bool unique = true;
      int currentRandom = 1 + Random().nextInt(10 - 1);
      for (int j = 0; j < i; j++)
        if (currentRandom == int.parse(ret[j])) {
          unique = false;
          break;
        }
      if (!unique) {
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
  Color? btnApplyColor;
  FocusNode focused = FocusNode();
  int currentDuration = 0, totalDuration = 0, roundCounter = 0;
  List<String>? otherPlayers;
  bool guessEnabled = true;
  String hint = '';
  GamePage(this.user, this.room, this.options);

  Future<List> findPlayers(bool _getStatus) async {
    DocumentReference doc =
        FirebaseFirestore.instance.collection("Rooms").doc(this.room);
    var document = await doc.get();
    List players = document.get('players');
    if (_getStatus) {
      List totalScores = await _sumScores(
          document.get('scores'), document.get('players'), true);
      List statusList = List.empty(growable: true);
      int idx = 0;
      totalScores.forEach((element) {
        statusList
            .add({'score': element.values.first, 'player': players[idx++]});
      });
      return statusList;
    }
    return players;
  }

  void initializeNumber() async {
    DocumentReference docs =
        FirebaseFirestore.instance.collection('Rooms').doc(this.room);
    var document = await docs.get();
    randomNumber = document.get('number');
    hint = 'guess'.tr().toString() +
        ' (' +
        randomNumber.toString().length.toString() +
        " " +
        "digit".tr().toLowerCase() +
        ")";
  }

  void processInput() async {
    print(randomNumber);
    if (btnApplyColor == Theme.of(context).disabledColor) return;
    String rndNumber = randomNumber.toString();
    String tmpEntered = entered.text;
    int dogru = 0, yanlis = 0;
    for (int i = 0; i < rndNumber.length; i++) {
      if (rndNumber[i] == tmpEntered[i]) {
        dogru++;
        rndNumber = rndNumber.substring(0, i) + rndNumber.substring(i + 1);
        tmpEntered = tmpEntered.substring(0, i) + tmpEntered.substring(i + 1);
        i--;
      }
    }
    bool kazandi = false;
    if (dogru == randomNumber.toString().length) kazandi = true;
    if (!kazandi)
      for (int i = 0; i < tmpEntered.length; i++)
        for (int j = 0; j < rndNumber.length; j++)
          if (tmpEntered[i] == rndNumber[j]) {
            yanlis++;
            break;
          }
    if (entryList.length > 0)
      entryList.insert(0,
          new Entry(entryList[0].id + 1, entered.text, dogru, yanlis, kazandi));
    else
      entryList.insert(0, new Entry(1, entered.text, dogru, yanlis, kazandi));
    if (kazandi) {
      if (prefs?.get('sound') == 'true') {
        AudioCache ac = new AudioCache();
        await ac.play('sounds/success.mp3');
        ac.clearAll();
      }
      int score = (((randomNumber.toString().length / 4) *
                  currentDuration /
                  (options!.duration * entryList[0].id)) *
              100)
          .toInt();
      DocumentReference doc =
          FirebaseFirestore.instance.collection("Rooms").doc(this.room);
      var document = await doc.get();
      List prevScores = document.get('scores');
      List players = document.get('players');
      prevScores[players.indexWhere((element) =>
              jsonDecode(element)['email'] == this.user!.email!)] +=
          score.toString();
      FirebaseFirestore.instance
          .collection('Rooms')
          .doc(this.room)
          .update({'scores': prevScores});
      DocumentReference docUser =
          FirebaseFirestore.instance.collection("Users").doc(this.user?.email);
      var documentUser = await docUser.get();
      this.user?.xp = documentUser.get('xp') + score;
      this.user?.credit = documentUser.get('credit') + totalDuration + score;
      FirebaseFirestore.instance
          .collection('Users')
          .doc(this.user?.email)
          .update({'xp': this.user?.xp, 'credit': this.user?.credit});
      setState(() {
        guessEnabled = false;
      });
      kazandi = true;
    }
    entered.clear();
    btnApplyColor = Theme.of(context).disabledColor;
  }

  Widget displayNumber() {
    return Text(randomNumber.toString(),
        style: TextStyle(fontSize: 32, color: Colors.green));
  }

  Widget displayResult(List userScore) {
    return Center(
      heightFactor: 1,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 16,
          headingRowColor:
              MaterialStateColor.resolveWith((states) => Colors.black12),
          columns: [
            DataColumn(
                label: Text(
              'name'.tr().toString(),
              textAlign: TextAlign.center,
            )),
            DataColumn(
                label:
                    Text('score'.tr().toString(), textAlign: TextAlign.center)),
          ],
          rows: userScore
              .map<DataRow>((e) => DataRow(cells: [
                    DataCell(Text(e.keys.first)),
                    DataCell(Text(e.values.first.toString())),
                  ]))
              .toList(),
        ),
      ),
    );
  }

  Future<List> _sumScores(List scores, List players, bool latestOnly) async {
    int idx = 0;
    List userScore = List.empty(growable: true);
    scores.forEach((score) {
      if (latestOnly) {
        List roundScores = score.split('-');
        int totalScore = 0;
        roundScores.forEach((element) {
          if (element != '') totalScore += int.parse(element);
        });
        userScore.add({jsonDecode(players[idx++])['name']: totalScore});
      } else {
        userScore
            .add({jsonDecode(players[idx++])['name']: score.split('-').last});
      }
    });
    return userScore;
  }

  roundEnd() async {
    print("END");
    setState(() {
      guessEnabled = false;
    });
    DocumentReference doc =
        FirebaseFirestore.instance.collection("Rooms").doc(this.room);
    var document = await doc.get();
    List players = document.get('players');
    List scores = document.get('scores');
    // for(int i=0;i<scores.length;i++){
    //   if(!scores[i].endsWith('-'))
    //   scores[i] += '-';
    // }
    // scores[players.indexWhere(
    //     (element) => jsonDecode(element)['email'] == this.user!.email!)] += '-';
    FirebaseFirestore.instance
        .collection("Rooms")
        .doc(this.room!)
        .update({'scores': scores});
    int cd = 3;
    if (this.options!.bestOf >= scores.first.split('-').length)
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return StatefulBuilder(builder: (context, setState) {
              if (cd != 0)
                Timer.periodic(new Duration(seconds: 1), (timer) {
                  if (cd == 0) {
                    timer.cancel();
                    cd = -1;
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) =>
                            GamePageSend(user, this.room, this.options)));
                  } else if (cd < 0)
                    timer.cancel();
                  else
                    setState(() {
                      cd--;
                    });
                });
              return AlertDialog(
                title: Center(
                  child: displayNumber(),
                ),
                content: Text(
                    'nextRound'.tr().toString() + ': ' + cd.toString(),
                    textAlign: TextAlign.center),
                // actions: <Widget>[
                //   ElevatedButton(
                //       onPressed: () {
                //         leaveGame();
                //         Navigator.pop(context);
                //         toMainPage(context, this.user!);
                //       },
                //       child: Center(child: Text("leave".tr().toString()))),
                // ],
              );
            });
          });
    else {
      var userScores = await _sumScores(scores, document.get('players'), false);
      showDialog(
          barrierDismissible: false,
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              contentPadding: EdgeInsets.zero,
              title: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 25),
                child: Center(child: displayNumber()),
              ),
              content: displayResult(userScores),
              actions: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: (Text("back".tr().toString()))),
                    SizedBox(
                      width: 20,
                    ),
                    ElevatedButton(
                        onPressed: () {
                          if (this.room == this.user?.email)
                            FirebaseFirestore.instance
                                .collection("Rooms")
                                .doc(this.room)
                                .delete();
                          else
                            leaveGame();
                          toMainPage(context, user!);
                        },
                        child: Center(child: Text("leave".tr().toString()))),
                  ],
                )
              ],
            );
          });
    }
    FirebaseFirestore.instance
        .collection("Rooms")
        .doc(this.room)
        .update({'roundInserted': false});
  }

  void insertRound() async {
    DocumentReference doc =
        FirebaseFirestore.instance.collection("Rooms").doc(this.room);
    var document = await doc.get();
    if (!document.exists) return;
    bool inserted = false;
      inserted = document.get('roundInserted');
    if (!inserted) {
      FirebaseFirestore.instance
          .collection("Rooms")
          .doc(this.room)
          .update({'roundInserted': true});
      var scores = document.get('scores');
      bool increasingDiff = document.get('increasingDiff');
      roundCounter = scores.first.split('-').length;
      if (increasingDiff) options?.length++;
      for(int i=0;i<scores.length;i++){
        scores[i] += '-';
      }
      await FirebaseFirestore.instance
          .collection("Rooms")
          .doc(this.room)
          .update({'length': options?.length, 'number': findRandom(options?.length), 'scores': scores});
    } else
      options?.length = document.get('length');
    initializeNumber();
  }

  Future<bool> allFinished() async {
    DocumentReference doc =
        FirebaseFirestore.instance.collection("Rooms").doc(this.room);
    var document = await doc.get();
    List scores = document.get('scores');
    return scores.every((element) {
       return element.split('-').length - 1 <= options!.bestOf && element.length > 1 && !element.endsWith('-');});
  }

  void startTimer() async {
    timerSeconds =
        new Timer.periodic(Duration(seconds: 1), (Timer timer) async {
      if (currentDuration < 1) {
        timer.cancel();
        roundEnd();
      } else {
        if (await allFinished()) {
          timerPlayers?.cancel();
          timer.cancel();
          roundEnd();
        } else {
          setState(() {
            currentDuration--;
            totalDuration++;
          });
        }
      }
    });
  }

  @override
  void initState() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      btnApplyColor = Theme.of(context).disabledColor;
    });
    insertRound();
    currentDuration = options!.duration;
    startTimer();
    super.initState();
  }

  void leaveGame() async {
    if (options!.multiplayer) {
      timerPlayers?.cancel();
      DocumentReference doc =
          FirebaseFirestore.instance.collection("Rooms").doc(this.room);
      var document = await doc.get();
      if (document.exists) {
        List players = document.get('players');
        if (this.room == this.user?.email && players.length == 1)
          FirebaseFirestore.instance
              .collection('Rooms')
              .doc(this.room)
              .delete();
        else {
          players.removeWhere((element) => element == this.user?.name);
          FirebaseFirestore.instance
              .collection('Rooms')
              .doc(this.room)
              .update({'players': players});
        }
      }
    } else
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
                    SizedBox(
                      width: 10,
                    ),
                    ElevatedButton(
                      child: Text('yes'.tr().toString()),
                      onPressed: () async {
                        timerSeconds?.cancel();
                        leaveGame();
                        Navigator.pop(context, true);
                        toMainPage(context, user!);
                      },
                    ),
                  ],
                ),
              ],
            )));
  }

  Future<int> buyDigit(String email, int bought) async {
    DocumentReference doc =
        FirebaseFirestore.instance.collection("Users").doc(email);
    var document = await doc.get();
    int transaction = document.get('credit') - bought;
    if (transaction > -1) {
      this.user?.credit = transaction;
      FirebaseFirestore.instance
          .collection("Users")
          .doc(email)
          .update({'credit': transaction});
    }
    return transaction;
  }

  Widget gameScreen() {
    String title = 'title'.tr().toString();
    if (options!.bestOf > 1)
      title += ' - ' +
          roundCounter.toString() +
          "/" +
          this.options!.bestOf.toString();
    return WillPopScope(
      onWillPop: (() => onWillPop(context)),
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(title),
          actions: [
            IconButton(
                onPressed: () async {
                  if (!guessEnabled) return;
                  int remaining = await buyDigit(this.user!.email!, 100);
                  if (remaining > -1) {
                    if (prefs?.get('sound') == 'true') {
                      AudioCache ac = new AudioCache();
                      await ac.play('sounds/coin.mp3');
                      ac.clearAll();
                    }
                    String tmpRandom = randomNumber.toString();
                    bool hinted = false;
                    String addHint = '';
                    if (entryList.length > 0) {
                      for (int i = 0; i < tmpRandom.length; i++) {
                        if (!hinted && tmpRandom[i] != entryList[0].tahmin[i]) {
                          addHint += ' ' + tmpRandom[i];
                          hinted = true;
                          continue;
                        }
                        addHint += ' _';
                      }
                    } else {
                      addHint += tmpRandom[0];
                      for (int i = 0; i < tmpRandom.length - 1; i++)
                        addHint += ' _';
                    }
                    setState(() {
                      hint = 'guess'.tr().toString() +
                          ' (' +
                          randomNumber.toString().length.toString() +
                          ") \t" +
                          addHint;
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
                        content: Text('alertInsufficient'.tr().toString() +
                            (-1 * remaining).toString())));
                  }
                },
                icon: Icon(Icons.money,
                    size: 30, color: guessEnabled ? Colors.white : Colors.grey))
          ],
        ),
        body: Column(
          children: [
            if (options!.multiplayer)
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 5, 20, 0),
                    child: FutureBuilder(
                      builder:
                          (BuildContext context, AsyncSnapshot<List> snapshot) {
                        return snapshot.hasData
                            ? SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Container(
                                  height: 50,
                                  child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      shrinkWrap: true,
                                      itemBuilder:
                                          (BuildContext context, int idx) {
                                        var score =
                                            snapshot.data?[idx]['score'];
                                        var userDecoded = jsonDecode(
                                            snapshot.data?[idx]['player']);
                                        if (userDecoded['name'] !=
                                            this.user!.name)
                                          return Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                5, 0, 5, 0),
                                            child: FittedBox(
                                                fit: BoxFit.fitHeight,
                                                child: Column(
                                                  children: [
                                                    score == 0
                                                        ? Container(
                                                            width: 50,
                                                            child:
                                                                LinearProgressIndicator())
                                                        : Icon(
                                                            Icons.done,
                                                            color: Theme.of(
                                                                    context)
                                                                .primaryColor,
                                                          ),
                                                    Container(
                                                        width: 25,
                                                        height: 25,
                                                        child: userDecoded[
                                                                    'picture'] !=
                                                                '' && userDecoded['picture'] != null
                                                            ? Image.network(
                                                                userDecoded[
                                                                    'picture'])
                                                            : Image.asset(
                                                                'assets/imgs/account.png')),
                                                    Text(userDecoded['name'])
                                                  ],
                                                )),
                                          );
                                        return Container();
                                      },
                                      itemCount: snapshot.data?.length),
                                ),
                              )
                            : Container();
                      },
                      future: findPlayers(true),
                    ),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 10, 0),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 20, 0),
                    child: Text(
                      currentDuration.toString(),
                      style: TextStyle(fontSize: 24),
                    ),
                  ),
                  Flexible(
                    child: TextField(
                      maxLength: randomNumber.toString().length,
                      buildCounter: (context,
                              {required currentLength,
                              maxLength,
                              required isFocused}) =>
                          null,
                      autofocus: true,
                      focusNode: focused,
                      controller: entered,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[1-9]'))
                      ],
                      enabled: guessEnabled,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                          labelText: hint,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10))),
                      keyboardType: TextInputType.number,
                      onChanged: (String changed) {
                        setState(() {
                          if (entered.text.length == 1 &&
                              entered.text[0] == '0') entered.clear();
                          if (randomNumber.toString().length !=
                              entered.text.length)
                            btnApplyColor = Theme.of(context).disabledColor;
                          else
                            btnApplyColor =
                                Theme.of(context).appBarTheme.backgroundColor;
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
                    child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            minimumSize: Size(60, 60), primary: btnApplyColor),
                        onPressed: () {
                          print(randomNumber);
                          setState(() {
                            processInput();
                          });
                        },
                        child: Text("apply".tr().toString())),
                  )
                ],
              ),
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
                      headingRowColor: MaterialStateColor.resolveWith(
                          (states) => Colors.black12),
                      headingRowHeight: 32,
                      columns: [
                        DataColumn(label: Text('#')),
                        DataColumn(label: Text('guess'.tr().toString())),
                        DataColumn(label: Text('right'.tr().toString())),
                        DataColumn(label: Text('wrong'.tr().toString())),
                      ],
                      rows: entryList
                          .map<DataRow>((e) => DataRow(
                                  color: MaterialStateColor.resolveWith(
                                      (states) => e.kazandi
                                          ? Colors.green
                                          : Colors.grey),
                                  cells: [
                                    DataCell(Text(e.id.toString())),
                                    DataCell(Text(e.tahmin)),
                                    DataCell(Text('+' + e.dogru.toString())),
                                    DataCell(Text('-' + e.yanlis.toString())),
                                  ]))
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return gameScreen();
  }
}
