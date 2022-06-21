import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart';
import 'package:sayibulmaca/matchup.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'Users.dart';
import 'helpers.dart';
import 'league.dart';

class LeaguePageSend extends StatefulWidget {
  final Users? user;
  final League? league;
  LeaguePageSend({@required this.user, @required this.league});
  @override
  State<StatefulWidget> createState() {
    return LeaguePage(this.user, this.league);
  }
}

class LeaguePage extends State<LeaguePageSend> {
  Users? user;
  League? league;
  LeaguePage(this.user, this.league);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('league'.tr() + ' ' + league!.name!),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'matchups'.tr(),
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ListView.builder(
              shrinkWrap: true,
              itemCount: league!.matchups.length,
              itemBuilder: (context, idx) {
                league!.matchups
                    .sort((a, b) => a['scores'][0].compareTo(b['scores'][0]));
                List players = league!.matchups[idx]['players'];
                List scores = league!.matchups[idx]['scores'];
                players = [jsonDecode(players.first), jsonDecode(players.last)];
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Card(
                    elevation: 1,
                    child: ListTile(
                      title: Text(
                          players[0]['name'] + ' vs ' + players[1]['name']),
                      trailing:
                          scores.every((element) => int.parse(element) > -1)
                              ? Text(scores.toString())
                              : players.any((element) =>
                                      element['email'] == this.user!.email)
                                  ? ElevatedButton.icon(
                                      onPressed: () async {
                                        int matchIdx = players.indexWhere(
                                            (element) =>
                                                element['email'] !=
                                                this.user!.email);
                                        await pushInvite(this.user!,
                                            players[matchIdx]['email'], {
                                          'leagueId': league!.id,
                                          'matchIdx': idx
                                        });
                                        await startGame(context, this.user!,
                                            league!.options!, null, {
                                          'leagueId': league!.id,
                                          'matchupIdx': idx.toString()
                                        });
                                      },
                                      icon: Icon(Icons.play_arrow_sharp),
                                      label: Text('start'.tr()))
                                  : null,
                    ),
                  ),
                );
              })
        ],
      ),
    );
  }
}
