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
import 'helpers.dart';
import 'package:intl/intl.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'league.dart';
import 'league_page.dart';
import 'matchup.dart';

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
  String? accessToken;
  try {
    accessToken = document.get('accessToken');
  } catch (e) {}
  Users ret = new Users(
    email: document.get('email'),
    password: document.get('password'),
    name: document.get('name'),
    picture: document.get('picture'),
    language: document.get('language'),
    xp: document.get('xp'),
    credit: document.get('credit'),
    method: document.get('method'),
  );
  if (accessToken != null) ret.accessToken = accessToken;
  return ret;
}

void toMainPage(BuildContext context, Users user) {
  selectedBottomIdx = 0;
  Navigator.maybeOf(context)?.push(
      MaterialPageRoute(builder: (context) => SearchPageSend(user: user)));
}

void _initPrefs() async {
  prefs = await SharedPreferences.getInstance();
  if (prefs?.getBool('scanInvite') == null) prefs!.setBool('scanInvite', true);
  if (prefs?.getBool('sound') == null) prefs!.setBool('sound', false);
  if (prefs?.getBool('durationEnabled') == null)
    prefs!.setBool('durationEnabled', false);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await EasyLocalization.ensureInitialized();
  await GetStorage.init();
  _initPrefs();
  introShown.writeIfNull('displayed', false);

//ONESIGNAL Push
  OneSignal.shared.setLogLevel(OSLogLevel.verbose, OSLogLevel.none);
  OneSignal.shared.setAppId("a57bdd86-0a91-46d4-8a1b-7951fdb6650d");
  OneSignal.shared.promptUserForPushNotificationPermission().then((accepted) {
    print("Accepted permission: $accepted");
  });
  OneSignal.shared.setNotificationWillShowInForegroundHandler(
      (OSNotificationReceivedEvent event) {
    // Will be called whenever a notification is received in foreground
    // Display Notification, pass null param for not displaying the notification
    event.complete(event.notification);
  });

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
            appBarTheme:
                AppBarTheme(backgroundColor: Color.fromARGB(255, 165, 8, 60)),
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
                backgroundColor: Color.fromARGB(255, 165, 8, 60),
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
  GoogleAuthProvider google = GoogleAuthProvider();

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
              UserCredential userCredential = await context
                  .read<AuthenticationServices>()
                  .signInWithGoogle();
              if (!userCredential.additionalUserInfo!.isNewUser) {
                DocumentReference doc = FirebaseFirestore.instance
                    .collection("Users")
                    .doc(userCredential.user!.email);
                var document = await doc.get();
                try {
                  document.get('picture');
                } catch (e) {
                  FirebaseFirestore.instance
                      .collection("Users")
                      .doc(userCredential.user!.email)
                      .update({'picture': userCredential.user!.photoURL});
                }
                Users user = new Users(
                    email: userCredential.user!.email,
                    password: userCredential.user!.uid,
                    picture: userCredential.user!.photoURL,
                    name: userCredential.user!.displayName,
                    language: document.get('language'),
                    xp: document.get('xp'),
                    credit: document.get('credit'),
                    method: 'google');
                toMainPage(context, user);
              } else {
                await FirebaseFirestore.instance
                    .collection('Users')
                    .doc(userCredential.user!.email)
                    .set({
                  'email': userCredential.user!.email,
                  'name': userCredential.user!.displayName,
                  'password': userCredential.user!.uid,
                  'picture': userCredential.user!.photoURL,
                  'credit': 0,
                  'status': 0,
                  'xp': 0,
                  'language': systemLanguage,
                  'method': 'google'
                });
                Users user = new Users(
                    email: userCredential.user!.email,
                    password: userCredential.user!.uid,
                    picture: userCredential.user!.photoURL,
                    name: userCredential.user!.displayName,
                    language: systemLanguage,
                    xp: 0,
                    credit: 0,
                    method: 'google');
              }
            }),
            SignInButton(
              Buttons.FacebookNew,
              text: "loginFacebook".tr(),
              onPressed: () async {
                var results = await context
                    .read<AuthenticationServices>()
                    .signInWithFacebook();
                if (results == null) return;
                UserCredential userCredential = results['userCredential'];
                Users user = Users.token(accessToken: results['accessToken']);
                if (userCredential.additionalUserInfo!.isNewUser) {
                  await FirebaseFirestore.instance
                      .collection('Users')
                      .doc(userCredential.user!.email)
                      .set({
                    'email': userCredential.user!.email,
                    'name': userCredential.user!.displayName,
                    'password': userCredential.user!.uid,
                    'picture': userCredential.user!.photoURL,
                    'credit': 0,
                    'status': 0,
                    'xp': 0,
                    'language': systemLanguage,
                    'method': 'facebook',
                    'accessToken': user.accessToken
                  });
                  user = new Users(
                      email: userCredential.user!.email,
                      password: userCredential.user!.uid,
                      name: userCredential.user!.displayName,
                      picture: userCredential.user!.photoURL,
                      language: systemLanguage,
                      xp: 0,
                      credit: 0,
                      method: 'facebook',
                      accessToken: user.accessToken);
                } else {
                  var document = await FirebaseFirestore.instance
                      .collection('Users')
                      .doc(userCredential.user!.email)
                      .get();
                  user = new Users(
                      email: document.get('email'),
                      name: document.get('name'),
                      password: document.get('password'),
                      picture: document.get('picture'),
                      language: document.get('language'),
                      xp: document.get('xp'),
                      credit: document.get('credit'),
                      method: document.get('method'),
                      accessToken: user.accessToken);
                }
                toMainPage(context, user);
              },
            ),
            SizedBox(
              height: 20,
            ),
            SignInButton(
              Buttons.Email,
              onPressed: () async {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => RegisterPageSend()));
              },
              text: "noaccount".tr().toString(),
            ),
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
                      'picture': '',
                      'status': 0,
                      'xp': 0,
                      'credit': 0,
                      'language': selectedLanguage,
                      'method': 'email'
                    });
                    Users user = new Users(
                        email: email.text,
                        password: password.text,
                        picture: '',
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
    try {
      var document = await doc.get();
      if (document.get('status') == 'playing') {
        var document = await doc.get();
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => GamePageSend(
                user,
                foundRoom,
                new Options(
                    accessMode: document.get('accessMode'),
                    game: document.get('game'),
                    multiplayer: true,
                    duration: document.get('duration'),
                    bestOf: document.get('bestOf'),
                    increasingDiff: document.get('increasingDiff'),
                    length: document.get('length')),
                null)));
        timer.cancel();
        timerPlayers?.cancel();
      }
    } catch (e) {
      timer.cancel();
      timerPlayers?.cancel();
      Navigator.pop(context);
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
              title: Center(
                child: Text(
                  "waitingStart".tr(),
                ),
              ),
              content: Container(
                height: MediaQuery.of(context).size.height * .1,
                child: Column(
                  children: [
                    Text((playersFound.length != 0
                            ? (playersFound.length - 1).toString()
                            : '0') +
                        'found'.tr().toString()),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * .005,
                    ),
                    LinearProgressIndicator(),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                    onPressed: () async {
                      timerPlayers?.cancel();
                      var document = await doc.get();
                      if (document.exists) {
                        List pls = currentPlayers;
                        currentPlayers = List.empty(growable: true);
                        for (int i = 0; i < pls.length - 1; i++)
                          if (pls[i] != user.email) currentPlayers.add(pls[i]);
                        doc.update({'players': currentPlayers});
                      }
                      Navigator.pop(context);
                    },
                    child: Text('abort'.tr().toString())),
              ],
              actionsAlignment: MainAxisAlignment.center);
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
        ElevatedButton(
          child: Text('no'.tr().toString()),
          onPressed: () => Navigator.pop(c, false),
        ),
        ElevatedButton(
          child: Text('yes'.tr().toString()),
          onPressed: () async {
            await context.read<AuthenticationServices>().signOut();
            OneSignal.shared.removeExternalUserId();
            Navigator.pop(c, false);
            signedOut = true;
            Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => InitialPageSend()));
          },
        ),
      ],
      actionsAlignment: MainAxisAlignment.center,
    ),
  );
  return false;
}

class SearchPageSend extends StatefulWidget {
  final Users? user;
  SearchPageSend({@required this.user});
  @override
  State<StatefulWidget> createState() {
    OneSignal.shared.setExternalUserId(this.user!.email!);
    return SearchPage(this.user);
  }
}

class SearchPage extends State<SearchPageSend> {
  Users? user;
  Timer? searchTimer;
  int selectedIdx = 0;
  Matchup? matchup;
  SearchPage(this.user);
  @override
  void initState() {
    checkNetwork(context);
    pushInviteReceived();
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (EasyLocalization.of(context)!.locale != Locale(this.user!.language!))
        EasyLocalization.of(context)!.setLocale(Locale(this.user!.language!));
    });
  }

  void pushInviteReceived() {
    OneSignal.shared.setNotificationOpenedHandler(
        (OSNotificationOpenedResult result) async {
      if (result.action?.type == OSNotificationActionType.actionTaken) {
        List<String> btn = result.action!.actionId!.split('_');
        if (result.action?.type == OSNotificationActionType.opened ||
            btn[0] == 'join') {
          DocumentReference documentReference =
              FirebaseFirestore.instance.collection("Rooms").doc(btn[1]);
          var doc = await documentReference.get();
          List players = doc.get('players');
          players.add(jsonEncode(this.user));
          await FirebaseFirestore.instance
              .collection("Rooms")
              .doc(btn[1])
              .update({
            'players': players,
            'scores': List.filled(players.length, '')
          });
          Timer.periodic(new Duration(seconds: 1), (timer) async {
            doc = await documentReference.get();
            String? status;
            try {
              status = doc.get('status');
            } catch (e) {
              timer.cancel();
              toMainPage(context, this.user!);
              return;
            }
            if (status == 'playing') {
              print(btn.toString());
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => GamePageSend(
                      user,
                      btn[1],
                      new Options(
                          accessMode: doc.get('accessMode'),
                          game: doc.get('game'),
                          multiplayer: true,
                          duration: doc.get('duration'),
                          bestOf: doc.get('bestOf'),
                          increasingDiff: doc.get('increasingDiff'),
                          length: doc.get('length')),
                      btn.length > 2
                          ? {'leagueId': btn[2], 'matchupIdx': btn[3]}
                          : null)));
              timer.cancel();
            }
          });
          showDialog(
              barrierDismissible: false,
              context: context,
              builder: (context) {
                return AlertDialog(
                    title: Center(child: Text("waitingStart".tr().toString())),
                    content: LinearProgressIndicator(),
                    actionsAlignment: MainAxisAlignment.center,
                    actions: [
                      ElevatedButton.icon(
                          onPressed: () async {
                            players.removeWhere((element) =>
                                jsonDecode(element)['email'] ==
                                this.user!.email);
                            try {
                              FirebaseFirestore.instance
                                  .collection("Rooms")
                                  .doc(btn.last);
                            } catch (e) {
                              return;
                            }
                            await FirebaseFirestore.instance
                                .collection("Rooms")
                                .doc(btn.last)
                                .update({'players': players});
                            Navigator.pop(context);
                          },
                          icon: Icon(Icons.close),
                          label: Text('close'.tr()))
                    ]);
              });
        } else if (result.action!.actionId == 'ignore') {}
      }
    });
  }

  Future searchLeagueStarted() async {
    var ret;
    try {
      await FirebaseFirestore.instance
          .collection('Leagues')
          .get()
          .then((value) => value.docs.forEach((element) {
                jsonDecode(element.get('matchups')).forEach((match) {
                  List players = match['players'];
                  if (players.any((element) =>
                      jsonDecode(element)['email'] == this.user!.email)) {
                    var league = element.data();
                    ret = {
                      'league': League(
                          host: league['host'],
                          id: element.id,
                          name: league['name'],
                          options: Options(
                              accessMode: 'private',
                              bestOf: league['bestOf'],
                              duration: league['duration'],
                              game: '',
                              increasingDiff: league['increasingDiff'],
                              length: league['length'],
                              multiplayer: true),
                          players: league['players'],
                          matchups: jsonDecode(league['matchups'])),
                      'matchup': Matchup(
                          players: match['players'], scores: match['scores'])
                    };
                  }
                });
              }));
    } catch (e) {
      print(e);
    }
    return ret;
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
                            if (result.get('accessMode') == 'public' &&
                                result.get('status') == 'ready') {
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
                                          LinearProgressIndicator(),
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
                    label: Text('gameQuickJoin'.tr(),
                        style: TextStyle(fontSize: 30))),
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * .1,
              ),
              ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => JoinGamePageSend(
                              user: this.user,
                            )));
                  },
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.all(16)),
                  icon: Icon(Icons.list),
                  label: Text('gameList'.tr().toString(),
                      style: TextStyle(fontSize: 30))),
              FutureBuilder(
                  future: searchLeagueStarted(),
                  builder:
                      (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                    if (snapshot.hasData)
                      return Column(
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * .1,
                          ),
                          ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) => LeaguePageSend(
                                        user: this.user,
                                        league: snapshot.data['league'])));
                              },
                              style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.all(16)),
                              icon: Icon(Icons.leaderboard),
                              label: Text('leagueStarted'.tr(),
                                  style: TextStyle(fontSize: 30))),
                        ],
                      );
                    return SizedBox.shrink();
                  })
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
          if (result.get('accessMode') == 'public' &&
              result.get('status') == 'ready') {
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
                    DataColumn(label: Text('players'.tr().toString())),
                    DataColumn(label: Text('duration'.tr().toString())),
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
            user!.picture != ''
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
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Stack(children: [
                        ClipRRect(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            child: LinearProgressIndicator(
                                value: xp, minHeight: 50)),
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Center(
                            child: Text(
                              'level'.tr().toString() + level.toString(),
                              style:
                                  TextStyle(fontSize: 32, color: Colors.white),
                            ),
                          ),
                        )
                      ]),
                    );
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
  bool? durationEnabled;
  List<String> invited = List.empty(growable: true);
  List friends = List.empty(growable: true);
  SetupPage(this.user);
  Future<void> _loadFriends() async {
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
    durationEnabled = (prefs?.getBool('durationEnabled') == null
        ? durationEnabled
        : prefs?.getBool('durationEnabled')!);
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.swap_horizontal_circle),
                  Text("multiplayer".tr().toString(),
                      style: TextStyle(fontSize: 24)),
                  ElevatedButton.icon(
                    // color: Theme.of(context).primaryColor,
                    icon: options.accessMode == 'private'
                        ? Icon(Icons.lock)
                        : Icon(Icons.public),
                    onPressed: !options.multiplayer
                        ? null
                        : () {
                            setState(() {
                              if (options.accessMode == 'private')
                                options.accessMode = 'public';
                              else
                                options.accessMode = 'private';
                            });
                          },
                    label: Text(options.accessMode.tr()),
                  )
                ],
              ),
              value: options.multiplayer,
              onChanged: (value) {
                setState(() {
                  options.multiplayer = value!;
                });
              },
            ),
            ListTile(
              leading: Icon(Icons.height),
              title: Text(
                'digitLength'.tr().toString(),
                style: TextStyle(fontSize: 24),
              ),
              trailing: DropdownButton<int>(
                value: options.length,
                items: [3, 4, 5, 6, 7, 8, 9]
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
            CheckboxListTile(
              value: durationEnabled ?? false,
              onChanged: (bool? active) {
                setState(() {
                  durationEnabled = active!;
                  print(durationEnabled);
                });
              },
              title: ListTile(
                subtitle: Text('(' + 'seconds'.tr() + ')'),
                enabled: durationEnabled ?? false,
                leading: Icon(Icons.timelapse),
                title: Text(
                  'duration'.tr(),
                  style: TextStyle(fontSize: 24),
                ),
                trailing: DropdownButton<dynamic>(
                  value: options.duration == -1 ? 15 : options.duration,
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
                  onChanged: durationEnabled == null || durationEnabled == false
                      ? null
                      : (value) {
                          print(value);
                          setState(() {
                            options.duration = value!;
                          });
                        },
                ),
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
                controlAffinity: ListTileControlAffinity.leading,
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
                  if (durationEnabled == false || durationEnabled == null)
                    options.duration = -1;
                  prefs?.setBool('multiplayer', options.multiplayer);
                  prefs?.setBool('durationEnabled', options.duration != -1);
                  prefs?.setInt('duration',
                      options.duration == -1 ? 60 : options.duration);
                  prefs?.setInt('length', options.length);
                  prefs?.setInt('bestOf', options.bestOf);
                  prefs?.setBool('increasingDiff', options.increasingDiff);
                  await _loadFriends();
                  await startGame(context, this.user!, options, friends, null);
                },
                style: ElevatedButton.styleFrom(padding: EdgeInsets.all(16)),
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
  final Object? ifLeagueInfo;
  GamePageSend(this.user, this.room, this.options, this.ifLeagueInfo);
  State<StatefulWidget> createState() {
    return GamePage(this.user, this.room, this.options, this.ifLeagueInfo);
  }
}

class GamePage extends State<GamePageSend> {
  Users? user;
  String? room;
  Options? options;
  var ifLeagueInfo;
  TextEditingController entered = new TextEditingController();
  List<Entry> entryList = new List.empty(growable: true);
  Color? btnApplyColor;
  FocusNode focused = FocusNode();
  int currentDuration = 0, totalDuration = 0, roundCounter = 0;
  List<String>? otherPlayers;
  bool guessEnabled = true, hintAvailable = true, alertHint = false;
  String _lblText = '';
  GamePage(this.user, this.room, this.options, this.ifLeagueInfo);

  Future<List> _getPlayers(bool _getStatus, bool _getSum) async {
    DocumentReference doc =
        FirebaseFirestore.instance.collection("Rooms").doc(this.room);
    var document = await doc.get();
    List players = document.get('players');
    if (_getStatus) {
      List scores = await _getScores(
          document.get('scores'), document.get('players'), true);
      List statusList = List.empty(growable: true);
      int idx = 0;
      scores.forEach((element) {
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
    _lblText =
        randomNumber.toString().length.toString() + ' ' + 'digit'.tr() + ': ';
  }

  void processInput() async {
    print(randomNumber);
    if (btnApplyColor == Theme.of(context).disabledColor) return;
    String rndNumber = randomNumber.toString();
    String tmpEntered = entered.text;
    int dogru = 0, yanlis = 0;
    for (int i = 0; i < rndNumber.length; i++) {
      if (rndNumber[i] == tmpEntered[i]) {
        if (!_lblText.split(':').last.contains(rndNumber[i])) {
          setState(() {
            hintAvailable = true;
          });
        }
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
      if (ifLeagueInfo != null) {
        List matchups = jsonDecode(
            await getField('Leagues', ifLeagueInfo['leagueId'], 'matchups'));
        int userIdx = matchups[int.parse(ifLeagueInfo!['matchupIdx'])]
                ['players']
            .indexWhere(
                (player) => jsonDecode(player)['email'] == this.user!.email);
        matchups[int.parse(ifLeagueInfo!['matchupIdx'])]['scores'][userIdx] =
            score.toString();
        FirebaseFirestore.instance
            .collection('Leagues')
            .doc(ifLeagueInfo['leagueId'])
            .update({'matchups': jsonEncode(matchups)});
      }
      DocumentReference doc =
          FirebaseFirestore.instance.collection("Rooms").doc(this.room);
      var document = await doc.get();
      List prevScores = document.get('scores');
      List players = List.empty(growable: true);
      document.get('players').forEach((element) {
        players.add(jsonDecode(element));
      });
      prevScores[players.indexWhere(
              (element) => element['email'] == this.user!.email!)] +=
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
    return Column(
      children: [
        Text('revealNumber'.tr()),
        Text(randomNumber.toString(),
            style: TextStyle(fontSize: 32, color: Colors.green)),
      ],
    );
  }

  Widget displayResults(List userScore) {
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

  Future<List> _getScores(List scores, List players, bool latestOnly) async {
    int idx = 0;
    List userScore = List.empty(growable: true);
    scores.forEach((score) {
      if (!latestOnly) {
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
    setState(() {
      guessEnabled = false;
    });
    DocumentReference doc =
        FirebaseFirestore.instance.collection("Rooms").doc(this.room);
    var document = await doc.get();
    List scores = document.get('scores');
    FirebaseFirestore.instance
        .collection("Rooms")
        .doc(this.room!)
        .update({'scores': scores});
    int cd = 3;
    if (this.options!.bestOf >= scores.first.split('-').length) {
      bool _cdStarted = false;
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return StatefulBuilder(builder: (context, setState) {
              if (!_cdStarted && cd != 0) {
                Timer.periodic(new Duration(seconds: 1), (timer) {
                  _cdStarted = true;
                  if (cd < 1) {
                    _cdStarted = false;
                    timer.cancel();
                    cd = -1;
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => GamePageSend(
                            user, this.room, this.options, this.ifLeagueInfo)));
                  } else
                    setState(() {
                      cd--;
                      print(cd);
                    });
                });
              }
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
                //       child: Center(child: Text("leaveGame".tr().toString()))),
                // ],
              );
            });
          });
    } else {
      List userScores =
          await _getScores(scores, document.get('players'), false);
      userScores.sort(
        (a, b) => b.values.first.compareTo(a.values.first),
      );
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
              content: displayResults(userScores),
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
                        child:
                            Center(child: Text("leaveGame".tr().toString()))),
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
    bool inserted = document.get('roundInserted');
    var scores = document.get('scores');
    if (!inserted) {
      await FirebaseFirestore.instance
          .collection("Rooms")
          .doc(this.room)
          .update({
        'roundInserted': true,
      });
      roundCounter = scores.first.split('-').length;
      bool increasingDiff = document.get('increasingDiff');
      if (roundCounter != 1 && increasingDiff) options?.length++;
      for (int i = 0; i < scores.length; i++) {
        scores[i] += '-';
      }

      await FirebaseFirestore.instance
          .collection("Rooms")
          .doc(this.room)
          .update({
        'length': options?.length,
        'number': findRandom(options?.length),
        'scores': scores
      });
    } else {
      roundCounter = scores.first.split('-').length - 1;
      options?.length = document.get('length');
    }
    initializeNumber();
  }

  Future<bool> allFinished() async {
    DocumentReference doc =
        FirebaseFirestore.instance.collection("Rooms").doc(this.room);
    var document = await doc.get();
    List scores = document.get('scores');
    return scores.every((element) {
      return element.split('-').length - 1 <= options!.bestOf &&
          element.length > 1 &&
          !element.endsWith('-');
    });
  }

  void startTimer() async {
    timerSeconds =
        new Timer.periodic(Duration(seconds: 1), (Timer timer) async {
      if (currentDuration == 0) {
        timer.cancel();
        roundEnd();
      } else {
        if (await allFinished()) {
          timerPlayers?.cancel();
          timer.cancel();
          roundEnd();
        } else {
          setState(() {
            if (currentDuration != -1) currentDuration--;
            totalDuration++;
          });
        }
      }
    });
  }

  void _digitCanBeBought() async {
    int remaining = await _buyDigit(this.user!.email!, 100, true);
    setState(() {
      if (remaining < 0) hintAvailable = false;
    });
  }

  @override
  void initState() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      btnApplyColor = Theme.of(context).disabledColor;
      _digitCanBeBought();
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
                  title: Text("alertLeaveGame".tr()),
                  actions: [
                    ElevatedButton(
                      child: Text('no'.tr().toString()),
                      onPressed: () => Navigator.pop(context, false),
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
                  actionsAlignment: MainAxisAlignment.center,
                )) ??
        false);
  }

  Future<int> _buyDigit(String email, int bought, bool resultOnly) async {
    DocumentReference doc =
        FirebaseFirestore.instance.collection("Users").doc(email);
    var document = await doc.get();
    int transaction = document.get('credit') - bought;
    if (!resultOnly && transaction > -1) {
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
                onPressed: !hintAvailable || entryList.isEmpty
                    ? null
                    : () async {
                        int remaining =
                            await _buyDigit(this.user!.email!, 100, true);
                        if (remaining > -1) {
                          _lblText = randomNumber.toString().length.toString() +
                              ' ' +
                              'digit'.tr() +
                              ': ';
                          if (prefs?.get('sound') == 'true') {
                            AudioCache ac = new AudioCache();
                            await ac.play('sounds/coin.mp3');
                            ac.clearAll();
                          }
                          String tmpRandom = randomNumber.toString();
                          String _hint = '';
                          bool hinted = false;
                          for (int i = 0; i < tmpRandom.length; i++) {
                            if (!hinted &&
                                tmpRandom[i] != entryList[0].tahmin[i] &&
                                !_lblText
                                    .split(':')
                                    .last
                                    .contains(tmpRandom[i])) {
                              hinted = true;
                              _hint += tmpRandom[i];
                              setState(() {
                                hintAvailable = false;
                                return;
                              });
                            } else {
                              _hint += ' _';
                            }
                          }
                          if (!hinted) _hint = _hint.split(':').first + ':';
                          await _buyDigit(this.user!.email!, 100, false);
                          setState(() {
                            _lblText += _hint;
                            alertHint = true;
                          });
                        } else {
                          setState(() {
                            hintAvailable = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                              new SnackBar(
                                  content: Text(
                                      'alertInsufficient'.tr().toString() +
                                          (-1 * remaining).toString())));
                        }
                      },
                icon: Icon(Icons.money))
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
                                  height: 75,
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
                                          return Container(
                                            width: 75,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      5, 0, 5, 0),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  score == ''
                                                      ? Flexible(
                                                          child:
                                                              LinearProgressIndicator())
                                                      : Flexible(
                                                          child: Icon(
                                                            Icons.done,
                                                            color: Theme.of(
                                                                    context)
                                                                .primaryColor,
                                                          ),
                                                        ),
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .fromLTRB(0, 8.0, 0, 0),
                                                    child: Container(
                                                        width: 30,
                                                        height: 30,
                                                        child: userDecoded[
                                                                        'picture'] !=
                                                                    '' &&
                                                                userDecoded[
                                                                        'picture'] !=
                                                                    null
                                                            ? Image.network(
                                                                userDecoded[
                                                                    'picture'])
                                                            : Image.asset(
                                                                'assets/imgs/account.png')),
                                                  ),
                                                  Flexible(
                                                      child: Text(
                                                          userDecoded['name']))
                                                ],
                                              ),
                                            ),
                                          );
                                        return Container();
                                      },
                                      itemCount: snapshot.data?.length),
                                ),
                              )
                            : Container();
                      },
                      future: _getPlayers(true, false),
                    ),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 10, 0),
              child: Row(
                children: [
                  currentDuration > 0
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(0, 0, 20, 0),
                          child: Text(
                            currentDuration.toString(),
                            style: TextStyle(fontSize: 24),
                          ),
                        )
                      : Container(),
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
                          label: AnimatedDefaultTextStyle(
                            onEnd: () {
                              setState(() {
                                alertHint = false;
                              });
                            },
                            duration: Duration(seconds: 1),
                            style: alertHint
                                ? TextStyle(
                                    color: Theme.of(context)
                                        .appBarTheme
                                        .backgroundColor,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold)
                                : TextStyle(
                                    color: Theme.of(context)
                                        .appBarTheme
                                        .backgroundColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.normal),
                            child: Text(_lblText),
                          ),
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
                      dataTextStyle: TextStyle(
                        shadows: <Shadow>[
                          Shadow(
                            offset: Offset(3, 1),
                            blurRadius: 10.0,
                            color: Colors.black,
                          ),
                          Shadow(
                            offset: Offset(1, 2),
                            blurRadius: 2.0,
                            color: Colors.black,
                          ),
                        ],
                      ),
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
                                      (states) => Color.fromARGB(
                                          255,
                                          180,
                                          (e.dogru / e.tahmin.length * 255)
                                              .toInt(),
                                          60)),
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
