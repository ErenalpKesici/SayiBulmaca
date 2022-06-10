import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:sayibulmaca/Options.dart';

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

Future<Options?> popupOptions(
    BuildContext context, Options? paramOptions) async {
  Options options = paramOptions ?? Options.empty();
  print(jsonEncode(options));
  showDialog(
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
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('next'.tr()))
              ],
            );
          },
        );
      });
  return options == Options.empty() ? paramOptions : options;
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

void _nameFromMail(mail) async {
  DocumentReference ref =
      FirebaseFirestore.instance.collection('Rooms').doc(mail);
  var doc = await ref.get();
  return doc.get('name');
}
