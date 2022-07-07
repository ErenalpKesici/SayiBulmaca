import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sayibulmaca/main.dart';
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
  List players = List.empty(growable: true);

  @override
  void initState() {
    league!.players.forEach((element) {
      players.add({'player': element, 'totalScore': 0, 'alerted': false});
    });
    league?.matchups.forEach((matchup) {
      for (int i = 0; i < matchup['players'].length; i++) {
        int score = int.parse(matchup['scores'][i]);
        if (score > 0)
          players[players.indexWhere(
                  (element) => element['player'] == matchup['players'][i])]
              ['totalScore'] += score;
      }
    });
    players.sort((a, b) => b['totalScore'].compareTo(a['totalScore']));
    setLeagueStatus(league!.id, players);
    for (int i = 0; i < players.length; i++) players[i]['num'] = i + 1;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => SearchPageSend(user: user)));
        return false;
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            bottom: TabBar(tabs: [
              Tab(
                icon: Icon(Icons.gamepad_outlined),
                text: 'matchups'.tr(),
              ),
              Tab(
                icon: Icon(Icons.format_list_bulleted_outlined),
                text: 'standings'.tr(),
              ),
            ]),
            centerTitle: true,
            title: Text((league!.status == -1 ? 'over'.tr() : 'ongoing'.tr()) +
                ' ' +
                'league'.tr() +
                ' ' +
                league!.name!),
          ),
          body: TabBarView(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Card(
                    elevation: 1,
                    child: ListView.separated(
                        separatorBuilder: (context, idx) => Divider(),
                        shrinkWrap: true,
                        itemCount: league!.matchups.length,
                        itemBuilder: (context, idx) {
                          List players = league!.matchups[idx]['players'];
                          List scores = league!.matchups[idx]['scores'];
                          players = [
                            jsonDecode(players.first),
                            jsonDecode(players.last)
                          ];
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ListTile(
                              title: Text(players[0]['name'] +
                                  ' vs ' +
                                  players[1]['name']),
                              trailing: scores.every(
                                      (element) => int.parse(element) > -1)
                                  ? Text(scores
                                      .toString()
                                      .split('[')[1]
                                      .split(']')[0])
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
                          );
                        }),
                  )
                ],
              ),
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                DataTable(
                  showBottomBorder: true,
                  columns: [
                    DataColumn(label: Text('#')),
                    DataColumn(label: Text('name'.tr())),
                    DataColumn(label: Text('score'.tr())),
                  ],
                  rows: players
                      .map<DataRow>((e) => DataRow(
                              color: league?.status == -1
                                  ? MaterialStateColor.resolveWith(
                                      (states) => e['num'] == 1
                                          ? Colors.yellow
                                          : e['num'] == 2
                                              ? Colors.black12
                                              : e['num'] == 3
                                                  ? Colors.amber
                                                  : Colors.transparent)
                                  : null,
                              cells: [
                                DataCell(Text(e['num'].toString())),
                                DataCell(Text(jsonDecode(e['player'])['name'])),
                                DataCell(Text(e['totalScore'].toString())),
                              ]))
                      .toList(),
                ),
              ])
            ],
          ),
        ),
      ),
    );
  }
}
