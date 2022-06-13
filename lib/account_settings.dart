import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:provider/provider.dart';
import 'package:sayibulmaca/AuthenticationServices.dart';

import 'Users.dart';
import 'main.dart';

class AccountSettingsPageSend extends StatefulWidget {
  final Users? user;
  AccountSettingsPageSend({@required this.user});
  @override
  State<StatefulWidget> createState() {
    return AccountSettingsPage(this.user);
  }
}

class AccountSettingsPage extends State<AccountSettingsPageSend> {
  Users? user;
  AccountSettingsPage(this.user);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('account'.tr() + ' ' + 'settings'.tr()),
        centerTitle: true,
      ),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(padding: EdgeInsets.all(16)),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => UpdatePageSend(
                            user: this.user,
                          )));
                },
                icon: Icon(Icons.update),
                label: Text('update'.tr().toString(),
                    style: TextStyle(fontSize: 30))),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(padding: EdgeInsets.all(16)),
                onPressed: () async {
                  return await showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                            title: Center(
                                child: Text("deleteAccount".tr().toString())),
                            content: Text(
                              'alertDeleteAccount'.tr().toString(),
                              textAlign: TextAlign.center,
                            ),
                            actions: [
                              ElevatedButton(
                                child: Text('no'.tr().toString()),
                                onPressed: () => Navigator.pop(c, false),
                              ),
                              ElevatedButton(
                                  child: Text('yes'.tr().toString()),
                                  onPressed: () async {
                                    await context
                                        .read<AuthenticationServices>()
                                        .signIn(
                                            email: this.user!.email,
                                            password: this.user!.password);
                                    await FirebaseFirestore.instance
                                        .collection("Users")
                                        .get()
                                        .then((value) {
                                      value.docs.forEach((result) async {
                                        List friends =
                                            List.empty(growable: true);
                                        List requests =
                                            List.empty(growable: true);
                                        try {
                                          friends = result.get('friends');
                                          friends.removeWhere((element) =>
                                              element == user!.email!);
                                          requests = result.get('requests');
                                          requests.removeWhere((element) =>
                                              element == user!.email!);
                                          await FirebaseFirestore.instance
                                              .collection("Users")
                                              .doc(result.get('email'))
                                              .update({
                                            'friends': friends,
                                            'requests': requests
                                          });
                                        } catch (e) {}
                                      });
                                    });
                                    await FirebaseFirestore.instance
                                        .collection('Users')
                                        .doc(this.user!.email)
                                        .delete();
                                    if (this.user!.method == 'email')
                                      await context
                                          .read<AuthenticationServices>()
                                          .delete(
                                              email: this.user!.email,
                                              password: this.user!.password);
                                    else
                                      await context
                                          .read<AuthenticationServices>()
                                          .deleteProvider(this.user!.method!);
                                    signedOut = true;
                                    Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                InitialPageSend()));
                                  }),
                            ],
                            actionsAlignment: MainAxisAlignment.center,
                          ));
                },
                icon: Icon(Icons.delete),
                label: Text('deleteAccount'.tr().toString(),
                    style: TextStyle(fontSize: 30))),
          ),
        ]),
      ),
    );
  }
}
