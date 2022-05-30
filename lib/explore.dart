import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'AuthenticationServices.dart';
import 'Users.dart';
import 'main.dart';
import 'package:badges/badges.dart';

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
  List<String> myRequests = List.empty(growable: true);

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
    } catch (e) {}
  }

  @override
  void initState() {
    loadRequests();
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
          title: Text('explore'.tr().toString()),
          centerTitle: true,
          actions: [
            Badge(
              position: BadgePosition.topStart(),
              badgeColor: Theme.of(context).selectedRowColor,
              badgeContent: Text(''),
              child: PopupMenuButton(
                icon: Icon(Icons.account_box),
                itemBuilder: (BuildContext context) {
                  return [PopupMenuItem(child: Text('ads'))];
                },
              ),
            )
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              TextField(
                  onEditingComplete: () async {
                    await context.read<AuthenticationServices>().signIn(
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
                          String email = result.get('email').toLowerCase();
                          String name = result.get('name').toLowerCase();
                          if (email != user!.email &&
                                  email.startsWith(query.text) ||
                              name.startsWith(query.text)) {
                            Users reqUser = Users(
                                name: result.get('name'),
                                email: result.get('email'),
                                password: result.get('password'),
                                language: result.get('language'),
                                xp: result.get('xp'),
                                credit: result.get('credit'),
                                method: result.get('method'),
                                settings: result.get('settings'));
                            DocumentReference docRef = FirebaseFirestore
                                .instance
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
                                  alreadyRequested.add(foundUsers.last.email!);
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
                      labelText: 'searchUser'.tr(),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)))),
              ListView.builder(
                  shrinkWrap: true,
                  itemCount: foundUsers.length,
                  itemBuilder: (BuildContext context, int idx) {
                    DocumentReference docRef = FirebaseFirestore.instance
                        .collection("Users")
                        .doc(foundUsers[idx].email);
                    return ListTile(
                      leading: Text(foundUsers[idx].name!),
                      trailing: alreadyRequested.contains(foundUsers[idx].email)
                          ? ElevatedButton.icon(
                              onPressed: () async {
                                var document = await docRef.get();
                                List usersRequested = document.get('requests');
                                usersRequested.removeWhere(
                                    (element) => element == user!.email!);
                                await FirebaseFirestore.instance
                                    .collection("Users")
                                    .doc(foundUsers[idx].email)
                                    .update({'requests': usersRequested});
                                setState(() {
                                  alreadyRequested
                                      .remove(foundUsers[idx].email);
                                });
                              },
                              icon: Icon(Icons.stop_circle_rounded),
                              label: Text('unsendFriend'.tr()))
                          : ElevatedButton.icon(
                              onPressed: () async {
                                List reqs = List.empty(growable: true);
                                var document = await docRef.get();
                                try {
                                  reqs = document.get('requests');
                                  reqs.add(user!.email);
                                } catch (e) {
                                  reqs = List.filled(1, user!.email);
                                }
                                await FirebaseFirestore.instance
                                    .collection("Users")
                                    .doc(foundUsers[idx].email)
                                    .update({'requests': reqs});

                                setState(() {
                                  alreadyRequested.add(foundUsers[idx].email!);
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
    );
  }
}
