import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sayibulmaca/Options.dart';

import 'package:http/http.dart';
import 'package:sayibulmaca/league.dart';
import 'Users.dart';
import 'package:share_plus/share_plus.dart';
import 'main.dart';

// Container getGradient(BuildContext context) {
//   return Container(
//     decoration: BoxDecoration(
//         gradient: LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//             colors: <Color>[
//           Theme.of(context).primaryColor,
//           Theme.of(context).hintColor
//         ])),
//   );
// }

Future getField(String collection, String doc, String field) async {
  DocumentReference docUser =
      FirebaseFirestore.instance.collection(collection).doc(doc);
  var documentUser = await docUser.get();
  return documentUser.get(field);
}

List<BottomNavigationBarItem> bottomNavItems() {
  return [
    BottomNavigationBarItem(
      icon: Icon(Icons.search),
      label: 'joinBtmBtn'.tr(),
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.create),
      label: 'create'.tr(),
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.explore),
      label: 'explore'.tr(),
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.account_box_rounded),
      label: 'account'.tr(),
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.settings),
      label: 'settings'.tr(),
    ),
  ];
}

Future<Options> popupOptions(
    BuildContext context, Options options, String idIfExists) async {
  await showDialog(
      context: context,
      builder: (context) {
        var durationEnabled;
        return StatefulBuilder(
          builder:
              (BuildContext context, void Function(void Function()) setState) {
            return AlertDialog(
              title: Text('settings'.tr()),
              content: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ListTile(
                    title: Text(
                      'digitLength'.tr().toString(),
                    ),
                    trailing: DropdownButton<int>(
                      value: options.length,
                      items: [3, 4, 5, 6, 7, 8, 9]
                          .map<DropdownMenuItem<int>>((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text(
                            value.toString(),
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
                      title: Text(
                        'duration'.tr(),
                      ),
                      trailing: DropdownButton<dynamic>(
                        value: options.duration == -1 ? 15 : options.duration,
                        items: [15, 30, 45, 60, 120]
                            .map<DropdownMenuItem<int>>((int value) {
                          return DropdownMenuItem<int>(
                            value: value,
                            child: Text(
                              value.toString(),
                            ),
                          );
                        }).toList(),
                        onChanged:
                            durationEnabled == null || durationEnabled == false
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
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'bestOf'.tr().toString(),
                        ),
                        DropdownButton<int>(
                          value: options.bestOf,
                          items:
                              [1, 3, 5].map<DropdownMenuItem<int>>((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(
                                value.toString(),
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
                ],
              ),
              actions: [
                ElevatedButton(
                    onPressed: () async {
                      if (idIfExists != '') {
                        await FirebaseFirestore.instance
                            .collection('Leagues')
                            .doc(idIfExists)
                            .update({
                          'length': options.length,
                          'duration': options.duration,
                          // 'endDate': tecEndDate.text,
                          'bestOf': options.bestOf,
                          'increasingDiff': options.increasingDiff
                        });
                      }
                      Navigator.pop(context);
                    },
                    child: Text('next'.tr()))
              ],
            );
          },
        );
      });
  return options;
}

Future<bool> exists(String item, String collection, String field) async {
  return await FirebaseFirestore.instance
      .collection(collection)
      .get()
      .then((value) => value.docs.any((element) => element[field] == item));
}

Future<List> removeFrom(
    toRemove, String collection, String documentId, String field) async {
  DocumentReference documentReference =
      FirebaseFirestore.instance.collection(collection).doc(documentId);
  var doc = await documentReference.get();
  List fieldList = doc.get(field);
  fieldList.removeWhere((element) => jsonDecode(element)['email'] == toRemove);
  await FirebaseFirestore.instance
      .collection(collection)
      .doc(documentId)
      .update({field: fieldList});
  return fieldList;
}

List invites = List.empty(growable: true);

Future<void> gameInvite(BuildContext context, Users user, friend) async {
  DocumentReference docRef =
      FirebaseFirestore.instance.collection("Users").doc(friend);
  var doc = await docRef.get();
  try {
    invites = doc.get('invite');
  } catch (e) {}
  invites.add(user.email!);
  FirebaseFirestore.instance
      .collection("Users")
      .doc(friend)
      .update({'invite': invites});
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('sentInvite'.tr() + ': ' + friend)));
}

Future<Response> pushInvite(Users user, String inviting, ifLeagueInfo) async {
  return await post(Uri.parse('https://onesignal.com/api/v1/notifications'),
      headers: {
        'Accept': 'application/json',
        'Authorization':
            'Basic ZTZiOGNlYTMtZDU5Ni00YWI4LWE2YjQtZTQ3MmU2OTliOWEx',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        'include_external_user_ids': [inviting],
        'name': 'INTERNAL_CAMPAIGN_NAME',
        'app_id': 'a57bdd86-0a91-46d4-8a1b-7951fdb6650d',
        'headings': {
          'en': ifLeagueInfo != null
              ? ('league'.tr() + ' ')
              : '' + 'invitation'.tr()
        },
        'contents': {'en': user.name! + ' ' + 'inviting'.tr()},
        'android_channel_id': '81667261-8f01-415c-add7-6c89c1149917',
        'buttons': [
          {'id': 'ignore_', 'text': 'close'.tr()},
          {
            'id': 'join_' +
                user.email! +
                (ifLeagueInfo != null
                    ? '_' +
                        ifLeagueInfo['leagueId'] +
                        '_' +
                        ifLeagueInfo['matchIdx'].toString()
                    : ''),
            'text': 'join'.tr()
          }
        ]
      }));
}

Future<void> startGame(BuildContext context, Users user, Options options,
    List? friends, ifLeagueInfo) async {
  Timer timerPlayers;
  if (options.multiplayer) {
    FirebaseFirestore.instance.collection('Rooms').doc(user.email).set({
      'accessMode': options.accessMode,
      'players': List.filled(1, jsonEncode(user)),
      'game': options.game,
      'length': options.length,
      'status': 'ready',
      'bestOf': options.bestOf,
      'scores': List.filled(1, ''),
      'duration': options.duration,
      'roundInserted': false,
      'increasingDiff': options.increasingDiff
    });
    DocumentReference doc =
        FirebaseFirestore.instance.collection("Rooms").doc(user.email);
    List playersFound = new List.empty(growable: true);
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return StatefulBuilder(builder: (context, setInnerState) {
            timerPlayers =
                Timer.periodic(new Duration(seconds: 5), (timer) async {
              var document = await doc.get();
              if (document.exists && document.get('status') == 'ready')
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
                height: MediaQuery.of(context).size.height * .2,
                child: Column(
                  children: [
                    Text(
                      (playersFound.length != 0
                              ? (playersFound.length - 1).toString()
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
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ElevatedButton(
                          onPressed: () {
                            timerPlayers.cancel();
                            FirebaseFirestore.instance
                                .collection('Rooms')
                                .doc(user.email)
                                .delete();
                            Navigator.pop(context);
                          },
                          child: Text('abort'.tr().toString())),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                        child: friends == null || friends.isEmpty
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
                                            textAlign: TextAlign.center,
                                          ),
                                          content: SizedBox(
                                            height: MediaQuery.of(context)
                                                    .size
                                                    .height *
                                                .3,
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                .7,
                                            child: StatefulBuilder(
                                              builder: (BuildContext context,
                                                  void Function(void Function())
                                                      setState) {
                                                return ListView.builder(
                                                    shrinkWrap: true,
                                                    itemCount: friends.length,
                                                    itemBuilder:
                                                        (BuildContext context,
                                                            int idx) {
                                                      return ListTile(
                                                        title: Text(friends[idx]
                                                            .split('@')
                                                            .first),
                                                        trailing:
                                                            ElevatedButton.icon(
                                                          icon: Icon(Icons
                                                              .send_outlined),
                                                          label: Text(
                                                              'invite'.tr()),
                                                          onPressed: () async {
                                                            await pushInvite(
                                                                user,
                                                                friends[idx],
                                                                null);
                                                            Navigator.pop(
                                                                context);
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
                              ? () async {
                                  FirebaseFirestore.instance
                                      .collection('Rooms')
                                      .doc(user.email)
                                      .update({'status': 'playing'});
                                  if (ifLeagueInfo != null) {
                                    List matchups = jsonDecode(await getField(
                                        'Leagues',
                                        ifLeagueInfo['leagueId'],
                                        'matchups'));
                                    matchups[int.parse(
                                            ifLeagueInfo['matchupIdx'])]
                                        ['scores'] = List.filled(2, '-1');
                                    await FirebaseFirestore.instance
                                        .collection('Leagues')
                                        .doc(ifLeagueInfo['leagueId'])
                                        .update(
                                            {'matchups': jsonEncode(matchups)});
                                  }
                                  Navigator.of(context).push(MaterialPageRoute(
                                      builder: (context) => GamePageSend(user,
                                          user.email, options, ifLeagueInfo)));
                                }
                              : null,
                          child: Text('start'.tr().toString()))
                    ],
                  ),
                )
              ],
            );
          });
        });
  } else {
    FirebaseFirestore.instance.collection("Rooms").doc(user.email).set({
      'accessMode': 'none',
      'players': List.filled(1, jsonEncode(user)),
      'game': options.game,
      'length': options.length,
      'status': 'playing',
      'scores': List.filled(1, ''),
      'bestOf': options.bestOf,
      'roundInserted': false,
      'increasingDiff': options.increasingDiff
    });
    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => GamePageSend(user, user.email, options, null)));
  }
}

List decodeList(List list) {
  List ret = List.empty(growable: true);
  list.forEach((element) {
    ret.add(jsonDecode(element));
  });
  return ret;
}

Future<void> alertLeagueOver(
    BuildContext context, Users user, league, results, int resultIdx) async {
  confettiController.play();
  results[resultIdx]['alerted'] = true;
  FirebaseFirestore.instance
      .collection('Leagues')
      .doc(league.id)
      .update({'results': results});
  return await showDialog(
      context: context,
      builder: (context) {
        int place = -1;
        String player = '';
        league.results.forEach((result) {
          if (jsonDecode(result['player'])['email'] == user.email) {
            player = jsonDecode(result['player'])['name'];
            place = result['num'];
          }
        });
        return AlertDialog(
          alignment: Alignment.center,
          actionsAlignment: MainAxisAlignment.center,
          title: Text(
            league.name + ' ' + 'league'.tr() + " " + 'results'.tr(),
            textAlign: TextAlign.center,
          ),
          content: Container(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('congrats'.tr() + ' ' + player),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("place".tr() + ': ' + place.toString()),
                )
              ],
            ),
          ),
          actions: [
            ElevatedButton.icon(
                onPressed: () {
                  Share.share('I placed ' +
                      place.toString() +
                      ' in a league in the game Sayı Bulmaca');
                },
                icon: Icon(Icons.share),
                label: Text('share'.tr()))
          ],
        );
      });
}

void setLeagueStatus(leagueId, players) async {
  DocumentReference documentReference =
      FirebaseFirestore.instance.collection("Leagues").doc(leagueId);
  var doc = await documentReference.get();
  bool setFinished = false;
  if (doc.get('status') != -1) {
    if (doc.get('endDate') != '') {
      DateTime end = DateTime.parse(doc.get('endDate'));
      if (DateTime.now().compareTo(end) > -1) setFinished = true;
    }
    if (!setFinished) {
      List matches = jsonDecode(doc.get('matchups'));
      if (matches.every((match) => match['scores'][0] != '-1'))
        setFinished = true;
    }
    if (setFinished)
      FirebaseFirestore.instance
          .collection("Leagues")
          .doc(leagueId)
          .update({'status': -1, 'results': players});
  }
}
