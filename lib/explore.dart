import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:sayibulmaca/Options.dart';
import 'package:sayibulmaca/league_details.dart';

import 'AuthenticationServices.dart';
import 'Users.dart';
import 'helpers.dart';
import 'league.dart';
import 'main.dart';
import 'package:badges/badges.dart';
import 'package:url_launcher/url_launcher.dart';

List myRequests = List.empty(growable: true);
List myFriends = List.empty(growable: true);
List joinedLeagues = List.empty(growable: true);
Future<List> loadLeagues(Users user, int currentPage) async {
  if (currentPage != 2) return List.empty();
  List<League> leagues = List.empty(growable: true);
  try {
    await FirebaseFirestore.instance.collection("Leagues").get().then((value) {
      value.docs.forEach((element) {
        Options options = Options(
            game: 'guess',
            multiplayer: true,
            duration: element.get('duration'),
            bestOf: element.get('bestOf'),
            increasingDiff: element.get('increasingDiff'),
            length: element.get('length'));
        leagues.add(League(
            id: element.id,
            name: element.get('name'),
            host: element.get('host'),
            players: element.get('players'),
            options: options,
            matchups: []));
        if (element.get('players').contains(jsonEncode(user)))
          joinedLeagues.add(element.id);
      });
    });
  } catch (e) {
    return List.empty();
  }
  return leagues;
}

class ExplorePageSend extends StatefulWidget {
  final Users? user;
  ExplorePageSend({@required this.user});
  @override
  State<StatefulWidget> createState() {
    return ExplorePage(this.user);
  }
}

class ExplorePage extends State<ExplorePageSend> {
  Users? user;
  ExplorePage(this.user);
  TextEditingController query = TextEditingController(text: '');
  List<Users> foundUsers = List.empty(growable: true);
  List<String> alreadyRequested = List.empty(growable: true);
  int currentPage = 0;
  TextEditingController tecName = TextEditingController();
  TextEditingController tecOptions = TextEditingController();
  TextEditingController tecEndDate = TextEditingController();
  Options options = Options.empty();

  Future<int> getXp() async {
    DocumentReference docUser =
        FirebaseFirestore.instance.collection("Users").doc(this.user?.email);
    var documentUser = await docUser.get();
    return documentUser.get('xp');
  }

  void loadRequests() async {
    DocumentReference docRef =
        FirebaseFirestore.instance.collection("Users").doc(user!.email!);
    var doc = await docRef.get();
    try {
      setState(() {
        myRequests = doc.get('requests');
      });
    } catch (e) {
      print(e);
    }
  }

  void loadFriends() async {
    DocumentReference docRef =
        FirebaseFirestore.instance.collection("Users").doc(user!.email!);
    var doc = await docRef.get();
    try {
      setState(() {
        myFriends = doc.get('friends');
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  void initState() {
    loadRequests();
    loadFriends();
    super.initState();
  }

  void popRequest(String element) async {
    DocumentReference docRef =
        FirebaseFirestore.instance.collection("Users").doc(user!.email!);
    var doc = await docRef.get();
    List reqs = doc.get('requests');
    reqs.removeWhere((inElement) => element == inElement);
    FirebaseFirestore.instance
        .collection("Users")
        .doc(user!.email!)
        .update({'requests': reqs});
    setState(() {
      myRequests = reqs;
    });
  }

  void popFriend(String element) async {
    DocumentReference docRef =
        FirebaseFirestore.instance.collection("Users").doc(user!.email!);
    var doc = await docRef.get();
    List fs = doc.get('friends');
    fs.removeWhere((inElement) => element == inElement);
    FirebaseFirestore.instance
        .collection("Users")
        .doc(user!.email!)
        .update({'friends': fs});
    DocumentReference fDocRef =
        FirebaseFirestore.instance.collection("Users").doc(element);
    doc = await docRef.get();
    List fFs = doc.get('friends');
    fFs.removeWhere((inElement) => element == user!.email!);
    FirebaseFirestore.instance
        .collection("Users")
        .doc(element)
        .update({'friends': fFs});
    setState(() {
      myFriends = fs;
    });
  }

  Widget _getLeagueTile(snapshot, index) {
    return Container(
      width: MediaQuery.of(context).size.width * .5,
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Card(
          elevation: 1,
          child: ListTile(
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => LeagueDetailsPageSend(
                        league: snapshot.data[index],
                        user: this.user,
                      )));
            },
            tileColor: Theme.of(context).cardColor,
            title: Text(snapshot.data[index].name),
            subtitle: Text(snapshot.data[index].players.length.toString() +
                ' ' +
                'players'.tr()),
            trailing: snapshot.data[index].host == this.user!.email
                ? ElevatedButton.icon(
                    onPressed: () async {
                      showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                                actionsAlignment: MainAxisAlignment.center,
                                title: Text('alertDeleteLeague'.tr()),
                                actions: [
                                  ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      child: Text('no'.tr())),
                                  ElevatedButton(
                                      onPressed: () async {
                                        await FirebaseFirestore.instance
                                            .collection("Leagues")
                                            .doc(snapshot.data[index].id)
                                            .delete();
                                        Navigator.pop(context);
                                        setState(() {});
                                      },
                                      child: Text('yes'.tr())),
                                ],
                              ));
                    },
                    icon: Icon(Icons.delete),
                    label: Text('delete'.tr()))
                : joinedLeagues.contains(snapshot.data[index].id)
                    ? ElevatedButton.icon(
                        onPressed: () async {
                          await removeFrom(this.user!.email, 'Leagues',
                              snapshot.data[index].id, 'players');
                          setState(() {
                            joinedLeagues.removeWhere((element) =>
                                element == snapshot.data[index].id);
                          });
                        },
                        icon: Icon(Icons.exit_to_app),
                        label: Text('leave'.tr()))
                    : ElevatedButton.icon(
                        onPressed: () async {
                          DocumentReference documentReference =
                              FirebaseFirestore.instance
                                  .collection("Leagues")
                                  .doc(snapshot.data[index].id);
                          var doc = await documentReference.get();
                          List players = doc.get('players');
                          players.add(jsonEncode(this.user));
                          FirebaseFirestore.instance
                              .collection("Leagues")
                              .doc(snapshot.data[index].id)
                              .update({'players': players});
                          setState(() {
                            joinedLeagues.add(snapshot.data[index].id);
                          });
                        },
                        icon: Icon(Icons.start),
                        label: Text('join'.tr())),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        toMainPage(context, this.user!);
        return false;
      },
      child: DefaultTabController(
        length: 3,
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
            title: Text('explore'.tr().toString()),
            centerTitle: true,
            bottom: TabBar(
              onTap: (idx) {
                setState(() {
                  currentPage = idx;
                });
              },
              tabs: [
                Tab(
                  icon: Icon(Icons.find_in_page),
                  text: 'searchUser'.tr(),
                ),
                Tab(
                  icon: Icon(Icons.people_outlined),
                  text: 'friends'.tr(),
                ),
                Tab(
                  icon: Icon(Icons.leaderboard_outlined),
                  text: 'leagues'.tr(),
                ),
              ],
            ),
            actions: [
              Badge(
                showBadge: myRequests.isNotEmpty,
                position: BadgePosition.topStart(),
                badgeColor: Theme.of(context).selectedRowColor,
                badgeContent: Text(myRequests.length.toString()),
                child: PopupMenuButton(
                  icon: Icon(Icons.account_box),
                  itemBuilder: (BuildContext context) {
                    List<PopupMenuEntry> requests = List.empty(growable: true);
                    requests.add(PopupMenuItem(
                      enabled: false,
                      child: Center(child: Text('friendRequests'.tr())),
                    ));
                    myRequests.forEach((element) {
                      requests.add(PopupMenuItem(
                        child: ListTile(
                          leading: Text(element.split('@').first),
                          trailing: SizedBox(
                              width: MediaQuery.of(context).size.width * .3,
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    ),
                                    onPressed: () async {
                                      DocumentReference docRef =
                                          FirebaseFirestore.instance
                                              .collection("Users")
                                              .doc(user!.email!);
                                      DocumentReference fDocRef =
                                          FirebaseFirestore.instance
                                              .collection("Users")
                                              .doc(element);
                                      var mDoc = await docRef.get();
                                      var fDoc = await fDocRef.get();
                                      List mFriends =
                                          List.empty(growable: true);
                                      List fFriends =
                                          List.empty(growable: true);
                                      try {
                                        myFriends = mDoc.get('friends');
                                        fFriends = fDoc.get('friends');
                                      } catch (e) {}
                                      mFriends.add(element);
                                      fFriends.add(user!.email!);
                                      FirebaseFirestore.instance
                                          .collection("Users")
                                          .doc(user!.email!)
                                          .update({'friends': mFriends});
                                      FirebaseFirestore.instance
                                          .collection("Users")
                                          .doc(element)
                                          .update({'friends': fFriends});
                                      popRequest(element);
                                      setState(() {
                                        myFriends = mFriends;
                                      });
                                      Navigator.pop(context);
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.block,
                                      color: Colors.red,
                                    ),
                                    onPressed: () async {
                                      popRequest(element);
                                      Navigator.pop(context);
                                    },
                                  )
                                ],
                              )),
                        ),
                      ));
                      loadRequests();
                    });
                    return requests;
                  },
                ),
              )
            ],
          ),
          body: TabBarView(children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * .5,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          // IconButton(
                          //     onPressed: () {
                          //       launchUrl(
                          //           Uri.parse(
                          //               "https://fb.gg/me/friendfinder/682728652813701"),
                          //           mode: LaunchMode.externalApplication);
                          //     },
                          //     icon: Icon(Icons.launch)),
                          TextField(
                              onEditingComplete: () async {
                                await context
                                    .read<AuthenticationServices>()
                                    .signIn(
                                      email: user?.email,
                                      password: user?.password,
                                    );
                                foundUsers = List.empty(growable: true);
                                await FirebaseFirestore.instance
                                    .collection("Users")
                                    .get()
                                    .then((value) {
                                  value.docs.forEach((result) async {
                                    if (query.text != '') {
                                      query.text = query.text.toLowerCase();
                                      String email =
                                          result.get('email').toLowerCase();
                                      String name =
                                          result.get('name').toLowerCase();
                                      if (email != user!.email &&
                                          (!myFriends.contains(email)) &&
                                          (email.startsWith(query.text) ||
                                              name.startsWith(query.text))) {
                                        Users reqUser = Users(
                                            name: result.get('name'),
                                            email: result.get('email'),
                                            password: result.get('password'),
                                            language: result.get('language'),
                                            xp: result.get('xp'),
                                            credit: result.get('credit'),
                                            method: result.get('method'));
                                        DocumentReference docRef =
                                            FirebaseFirestore.instance
                                                .collection("Users")
                                                .doc(reqUser.email);
                                        var document = await docRef.get();
                                        setState(() {
                                          foundUsers.add(reqUser);
                                          var reqs;
                                          try {
                                            reqs = document.get('requests');
                                            if (reqs != '' &&
                                                document
                                                    .get('requests')
                                                    .split(', ')
                                                    .contains(user!.email)) {
                                              alreadyRequested
                                                  .add(foundUsers.last.email!);
                                            }
                                          } catch (e) {}
                                        });
                                      }
                                    }
                                  });
                                });
                              },
                              controller: query,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                  labelText: 'searchUserHolder'.tr(),
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)))),
                          ListView.builder(
                              shrinkWrap: true,
                              itemCount: foundUsers.length,
                              itemBuilder: (BuildContext context, int idx) {
                                if (foundUsers.isEmpty)
                                  return Center(
                                    child: Text('noUser'.tr()),
                                  );
                                DocumentReference docRef = FirebaseFirestore
                                    .instance
                                    .collection("Users")
                                    .doc(foundUsers[idx].email);
                                return ListTile(
                                  leading: Text(foundUsers[idx].name!),
                                  trailing: alreadyRequested
                                          .contains(foundUsers[idx].email)
                                      ? ElevatedButton.icon(
                                          onPressed: () async {
                                            var document = await docRef.get();
                                            List usersRequested =
                                                document.get('requests');
                                            usersRequested.removeWhere(
                                                (element) =>
                                                    element == user!.email!);
                                            await FirebaseFirestore.instance
                                                .collection("Users")
                                                .doc(foundUsers[idx].email)
                                                .update({
                                              'requests': usersRequested
                                            });
                                            setState(() {
                                              alreadyRequested.remove(
                                                  foundUsers[idx].email);
                                            });
                                          },
                                          icon: Icon(Icons.stop_circle_rounded),
                                          label: Text('unsendFriend'.tr()))
                                      : ElevatedButton.icon(
                                          onPressed: () async {
                                            List reqs =
                                                List.empty(growable: true);
                                            var document = await docRef.get();
                                            try {
                                              reqs = document.get('requests');
                                              reqs.add(user!.email);
                                            } catch (e) {
                                              reqs =
                                                  List.filled(1, user!.email);
                                            }
                                            await FirebaseFirestore.instance
                                                .collection("Users")
                                                .doc(foundUsers[idx].email)
                                                .update({'requests': reqs});

                                            setState(() {
                                              alreadyRequested
                                                  .add(foundUsers[idx].email!);
                                            });
                                          },
                                          icon: Icon(Icons.send),
                                          label: Text('sendFriend'.tr())),
                                );
                              })
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            myFriends.isEmpty
                ? Center(
                    child: Text('noUser'.tr()),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: myFriends.length,
                    itemBuilder: (BuildContext context, int idx) {
                      return Card(
                        elevation: 1,
                        child: ListTile(
                          title: Text(myFriends[idx]),
                          trailing: ElevatedButton.icon(
                            icon: Icon(Icons.no_accounts_outlined),
                            label: Text('unfriend'.tr()),
                            onPressed: () async {
                              popFriend(myFriends[idx]);
                            },
                          ),
                        ),
                      );
                    }),
            FutureBuilder(
              future: loadLeagues(this.user!, currentPage),
              builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                if (snapshot.hasData) {
                  if (snapshot.data.isNotEmpty)
                    return ListView.builder(
                      itemCount: snapshot.data.length,
                      itemBuilder: (BuildContext context, int index) {
                        return _getLeagueTile(snapshot, index);
                      },
                    );
                  else if (snapshot.data.isEmpty)
                    return Center(
                      child: Text('noLeagues'.tr()),
                    );
                  else
                    return Center(child: CircularProgressIndicator());
                } else
                  return Center(child: CircularProgressIndicator());
              },
            )
          ]),
          floatingActionButton: currentPage == 2
              ? FloatingActionButton.extended(
                  label: Text('createLeague'.tr()),
                  icon: Icon(Icons.add),
                  onPressed: () async {
                    DateTime? date;
                    showDialog(
                        barrierDismissible: false,
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            actionsAlignment: MainAxisAlignment.center,
                            title: Text(
                              'createLeague'.tr(),
                              textAlign: TextAlign.center,
                            ),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  TextField(
                                    controller: tecName,
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                        labelText: 'name'.tr(),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10))),
                                  ),
                                  TextField(
                                    controller: tecEndDate,
                                    onTap: () async {
                                      date = await showDatePicker(
                                              context: context,
                                              initialDate: DateTime.now(),
                                              firstDate: DateTime.now(),
                                              lastDate: DateTime(
                                                  DateTime.now().year + 1)) ??
                                          date;
                                      tecEndDate.text = date == null
                                          ? ''
                                          : DateFormat('yyyy/MM/dd')
                                              .format(date!);
                                    },
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                        labelText: 'duration'.tr(),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10))),
                                  ),
                                  ElevatedButton.icon(
                                      icon: Icon(Icons.settings),
                                      label: Text('settings'.tr()),
                                      onPressed: () async {
                                        options = await popupOptions(
                                            context, options, '');
                                      }),
                                ],
                              ),
                            ),
                            actions: [
                              ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text('back'.tr())),
                              ElevatedButton(
                                  onPressed: () async {
                                    if (tecName.text != '') {
                                      if (!await exists(
                                          tecName.text, 'Leagues', 'name')) {
                                        await FirebaseFirestore.instance
                                            .collection('Leagues')
                                            .doc()
                                            .set({
                                          'name': tecName.text,
                                          'host': this.user?.email,
                                          'players': List.filled(
                                              1, jsonEncode(this.user)),
                                          'length': options.length,
                                          'duration': options.duration,
                                          'endDate': tecEndDate.text,
                                          'bestOf': options.bestOf,
                                          'increasingDiff':
                                              options.increasingDiff
                                        });
                                        ScaffoldMessenger.maybeOf(context)
                                            ?.showSnackBar(SnackBar(
                                                content: Text(tecName.text +
                                                    ' ' +
                                                    'leagueCreated'.tr())));
                                        Navigator.pop(context);
                                        setState(() {});
                                      } else
                                        ScaffoldMessenger.maybeOf(context)
                                            ?.showSnackBar(SnackBar(
                                                content: Text(
                                                    'alertExistsLeague'.tr())));
                                    } else
                                      ScaffoldMessenger.maybeOf(context)
                                          ?.showSnackBar(SnackBar(
                                              content: Text('alertFill'.tr())));
                                  },
                                  child: Text('create'.tr()))
                            ],
                          );
                        });
                  })
              : null,
        ),
      ),
    );
  }
}
