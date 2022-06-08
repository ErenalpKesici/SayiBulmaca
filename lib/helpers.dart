import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

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

void _nameFromMail(mail) async {
  DocumentReference ref =
      FirebaseFirestore.instance.collection('Rooms').doc(mail);
  var doc = await ref.get();
  return doc.get('name');
}
