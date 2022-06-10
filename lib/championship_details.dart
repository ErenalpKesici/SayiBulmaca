import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:sayibulmaca/championship.dart';
import 'package:sayibulmaca/explore.dart';

import 'Users.dart';
import 'helpers.dart';

class ChampionshipDetailsPageSend extends StatefulWidget {
  final Users? user;
  final Championship? championship;
  ChampionshipDetailsPageSend(
      {@required this.user, @required this.championship});
  @override
  State<StatefulWidget> createState() {
    return ChampionshipDetailsPage(this.user, this.championship);
  }
}

class ChampionshipDetailsPage extends State<ChampionshipDetailsPageSend> {
  Users? user;
  Championship? championship;
  int _required = -1;
  ChampionshipDetailsPage(this.user, this.championship);
  @override
  void initState() {
    _required = _closestPowerOfTwo(championship!.players.length);
    super.initState();
  }

  int _closestPowerOfTwo(int length) {
    int _min = length > 1
        ? length.isEven
            ? length
            : length + 1
        : 4;
    return _min - length;
  }

  Future<void> saveChampionship() async {}
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        loadChampionships(this.user!, 2);

        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text('championship'.tr() + ' ' + championship!.name!),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Text(
                'players'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ListView.builder(
                  scrollDirection: Axis.vertical,
                  shrinkWrap: true,
                  itemCount: championship!.players.length,
                  itemBuilder: (context, idx) {
                    var user = jsonDecode(championship!.players[idx]);
                    return ListTile(
                      leading: Container(
                          width: 25,
                          height: 25,
                          child: user['picture'] != ''
                              ? Image.network(
                                  user['picture'],
                                )
                              : null),
                      title: Text(user['name']),
                      trailing: championship!.host == this.user!.email &&
                              user['email'] != this.user!.email
                          ? ElevatedButton.icon(
                              onPressed: () async {
                                championship!.players = await removeFrom(
                                    user['email'],
                                    'Championships',
                                    championship!.id!,
                                    'players');
                                setState(() {
                                  _required = _closestPowerOfTwo(
                                      championship!.players.length);
                                });
                              },
                              icon: Icon(Icons.block),
                              label: Text('kickOut'.tr()))
                          : null,
                    );
                  }),
              ElevatedButton.icon(
                  onPressed: () async {
                    championship?.options =
                        await popupOptions(context, championship?.options);
                  },
                  icon: Icon(Icons.settings),
                  label: Text('settings'.tr())),
              championship!.host == user!.email
                  ? Tooltip(
                      triggerMode: TooltipTriggerMode.tap,
                      message: _required == 0
                          ? ''
                          : _required.toString() + ' ' + 'toolTipPlayers'.tr(),
                      child: ElevatedButton.icon(
                          onPressed: _required == 0 ? () {} : null,
                          icon: Icon(Icons.play_arrow),
                          label: Text('startChampionship'.tr())),
                    )
                  : Container()
            ],
          ),
        ),
      ),
    );
  }
}
