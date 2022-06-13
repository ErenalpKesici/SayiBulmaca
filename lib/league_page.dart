import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:sayibulmaca/matchup.dart';

import 'Users.dart';
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
          ListView.builder(
              shrinkWrap: true,
              itemCount: league!.matchups.length,
              itemBuilder: (context, idx) {
                List players = league!.matchups[idx]['players'];
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Card(
                    elevation: 1,
                    child: ListTile(
                      title: Text(jsonDecode(players[0])['name'] +
                          ' vs ' +
                          jsonDecode(players[1])['name']),
                      trailing: players.any((element) =>
                              jsonDecode(element)['email'] == this.user!.email)
                          ? ElevatedButton.icon(
                              onPressed: () {},
                              icon: Icon(Icons.abc),
                              label: Text('a'))
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
