import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:sayibulmaca/league.dart';
import 'package:sayibulmaca/explore.dart';
import 'package:sayibulmaca/main.dart';
import 'package:sayibulmaca/matchup.dart';

import 'Users.dart';
import 'helpers.dart';
import 'league_page.dart';

class LeagueDetailsPageSend extends StatefulWidget {
  final Users? user;
  final League? league;
  LeagueDetailsPageSend({@required this.user, @required this.league});
  @override
  State<StatefulWidget> createState() {
    return LeagueDetailsPage(this.user, this.league);
  }
}

class LeagueDetailsPage extends State<LeagueDetailsPageSend> {
  Users? user;
  League? league;
  int _required = -1;
  LeagueDetailsPage(this.user, this.league);
  @override
  void initState() {
    _required = _closestPowerOfTwo(league!.players.length);
    super.initState();
  }

  int _closestPowerOfTwo(int length) {
    if (length == 2) return length;
    int _min = length > 1
        ? length.isEven
            ? length
            : length + 1
        : 4;
    return _min - length;
  }

  int _calculateScore(int userIdx) {
    int score = 0;
    league?.matchups.forEach((match) {
      for (int i = 0; i < match['players'].length; i++) {
        if (league!.players[userIdx] == match['players'][i] &&
            int.parse(match['scores'][i]) > 0) {
          score += int.parse(match['scores'][i]);
        }
      }
    });
    return score;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        loadLeagues(this.user!, 1);
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text('league'.tr() + ' ' + league!.name!),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(
                'players'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ListView.builder(
                  scrollDirection: Axis.vertical,
                  shrinkWrap: true,
                  itemCount: league!.players.length,
                  itemBuilder: (context, idx) {
                    var user = jsonDecode(league!.players[idx]);
                    ;
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
                      trailing: league!.matchups.isEmpty
                          ? user['email'] == league!.host
                              ? Icon(Icons.account_tree_rounded)
                              : league!.host == this.user!.email &&
                                      user['email'] != this.user!.email
                                  ? ElevatedButton.icon(
                                      onPressed: () async {
                                        league!.players = await removeFrom(
                                            user['email'],
                                            'Leagues',
                                            league!.id!,
                                            'players');
                                        setState(() {
                                          _required = _closestPowerOfTwo(
                                              league!.players.length);
                                        });
                                      },
                                      icon: Icon(Icons.block),
                                      label: Text('kickOut'.tr()))
                                  : null
                          : Text(_calculateScore(idx).toString()),
                    );
                  }),
              league!.host == user!.email
                  ? ElevatedButton.icon(
                      onPressed: () async {
                        league?.options = await popupOptions(
                            context, league!.options!, league!.id!);
                      },
                      icon: Icon(Icons.settings),
                      label: Text('settings'.tr()))
                  : Container(),
              league!.host == user!.email
                  ? Tooltip(
                      triggerMode: TooltipTriggerMode.tap,
                      message: _required == 0
                          ? ''
                          : league!.matchups == List.empty()
                              ? 'leagueStarted'.tr()
                              : _required.toString() +
                                  ' ' +
                                  'toolTipPlayers'.tr(),
                      child: ElevatedButton.icon(
                          onPressed: _required == 0 && league!.matchups.isEmpty
                              ? () async {
                                  List<Matchup> matchups =
                                      List.empty(growable: true);
                                  for (int i = 0;
                                      i < league!.players.length;
                                      i++) {
                                    for (int j = i + 1;
                                        j < league!.players.length;
                                        j++) {
                                      matchups.add(Matchup(players: [
                                        league!.players[i],
                                        league!.players[j]
                                      ], scores: [
                                        '-1',
                                        '-1'
                                      ]));
                                    }
                                  }
                                  await FirebaseFirestore.instance
                                      .collection("Leagues")
                                      .doc(this.league!.id)
                                      .update({
                                    'matchups': jsonEncode(matchups),
                                    'status': 1
                                  });
                                  league?.matchups = matchups;
                                  Navigator.of(context).push(MaterialPageRoute(
                                      builder: (context) =>
                                          SearchPageSend(user: this.user)));
                                }
                              : null,
                          icon: Icon(Icons.play_arrow),
                          label: Text('startLeague'.tr())),
                    )
                  : Container()
            ],
          ),
        ),
      ),
    );
  }
}
