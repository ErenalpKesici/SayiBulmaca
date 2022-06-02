import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:sayibulmaca/main.dart';
import 'Users.dart';

class SettingsPageSend extends StatefulWidget {
  final Users? user;
  SettingsPageSend({@required this.user});
  @override
  State<StatefulWidget> createState() {
    return SettingsPage(this.user);
  }
}

class SettingsPage extends State<SettingsPageSend> {
  Users? user;
  String? lang;
  bool? sound;
  bool? scanInvite;
  SettingsPage(this.user);
  List<Color?>? languageColor = List.empty(growable: true);
  @override
  Widget build(BuildContext context) {
    if (languageColor!.isEmpty) {
      if (this.user?.language == 'tr') {
        languageColor!.add(Theme.of(context).primaryColor);
        languageColor!.add(Colors.pink[100]);
      } else if (this.user?.language == 'en') {
        languageColor!.add(Colors.pink[100]);
        languageColor!.add(Theme.of(context).primaryColor);
      }
    }
    return WillPopScope(
      onWillPop: () async {
        toMainPage(context, user!);
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
        appBar: AppBar(
          leading: Container(),
          title: Text('settings'.tr().toString()),
          centerTitle: true,
          actions: [
            Container(
              color: languageColor?[0],
              child: IconButton(
                onPressed: () {
                  setState(() {
                    languageColor?[1] = Theme.of(context).primaryColor;
                    languageColor?[0] = Colors.pink[100];
                    this.user?.language = 'en';
                    FirebaseFirestore.instance
                        .collection('Users')
                        .doc(this.user?.email)
                        .update({'language': this.user?.language});
                    EasyLocalization.of(context)!
                        .setLocale(Locale(this.user!.language!));
                  });
                },
                icon: Image.asset("assets/imgs/en.png"),
              ),
            ),
            Container(
              color: languageColor?[1],
              child: IconButton(
                onPressed: () {
                  setState(() {
                    languageColor?[0] = Theme.of(context).primaryColor;
                    languageColor?[1] = Colors.pink[100];
                    this.user?.language = 'tr';
                    FirebaseFirestore.instance
                        .collection('Users')
                        .doc(this.user?.email)
                        .update({'language': this.user?.language});
                    EasyLocalization.of(context)!
                        .setLocale(Locale(this.user!.language!));
                  });
                },
                icon: Image.asset("assets/imgs/tr.png"),
              ),
            ),
          ],
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CheckboxListTile(
              title: Text('soundEffects'.tr().toString()),
              value: prefs?.getBool('sound') ?? false,
              onChanged: (value) {
                setState(() {
                  prefs?.setBool('sound', value!);
                });
              },
              controlAffinity: ListTileControlAffinity.trailing,
            ),
            CheckboxListTile(
                title: Text('showInvite'.tr()),
                value: prefs?.getBool('scanInvite') ?? true,
                onChanged: (val) {
                  setState(() {
                    prefs?.setBool('scanInvite', val!);
                  });
                  if (prefs?.getBool('scanInvite') == true)
                    scanInvites(this.user, context);
                  print(prefs?.getBool('scanInvite'));
                }),
          ],
        ),
      ),
    );
  }
}

void scanInvites(Users? user, BuildContext context) async {
  if (currentlyScanning == false) {
    currentlyScanning = true;
    Timer.periodic(Duration(seconds: 5), (timer) async {
      if (signedOut == true ||
          prefs?.getBool('scanInvite') == null ||
          prefs?.getBool('scanInvite') == false) {
        currentlyScanning = false;
        timer.cancel();
        return;
      }
      DocumentReference? docRef;
      try {
        docRef =
            FirebaseFirestore.instance.collection("Users").doc(user!.email!);
      } catch (e) {
        timer.cancel();
      }
      var doc = await docRef!.get();
      try {
        List invites = doc.get('invite');
        if (invites.isNotEmpty) {
          String invite = invites.removeLast();
          FirebaseFirestore.instance
              .collection("Users")
              .doc(user!.email!)
              .update({'invite': invites});
          showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: Text('incomingInvite'.tr()),
                  content: Text(invite),
                  actions: [
                    Center(
                      child: ElevatedButton.icon(
                          onPressed: () async {
                            DocumentReference ref = FirebaseFirestore.instance
                                .collection('Rooms')
                                .doc(invite);
                            var doc = await ref.get();
                            List players = doc.get('players');
                            joinDialog(context, invite, players, user);
                          },
                          icon: Icon(Icons.check_circle),
                          label: Text('join'.tr())),
                    )
                  ],
                );
              });
        }
      } catch (e) {}
    });
  }
}
