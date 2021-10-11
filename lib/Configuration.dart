import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:sayibulmaca/main.dart';
import 'Users.dart';

class Configuration {
  String? sound;
  Configuration(String settings){
    List<String> sets = settings.split(', ');
    for(int i=0;i<sets.length - 1;i++){
      sound = sets[i].split(':')[1];
    }
  }
}

class SettingsPageSend extends StatefulWidget {
  final Users? user;
  SettingsPageSend({@required this.user});
  @override
  State<StatefulWidget> createState() {
    return SettingsPage(this.user);
  }
}
class SettingsPage extends State<SettingsPageSend>{
  Users? user;
  String? lang;
  bool? sound;
  SettingsPage(this.user);
  List<Color?>? languageColor = List.empty(growable: true);
  @override
  void initState() {
    print(configuration?.sound);
    sound = configuration?.sound=='true'?true:false;
    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    if(languageColor!.isEmpty){
      if(this.user?.language == 'tr'){
        languageColor!.add(Theme.of(context).primaryColor);
        languageColor!.add(Colors.pink[100]);
      }
      else if(this.user?.language == 'en'){
        languageColor!.add(Colors.pink[100]);
        languageColor!.add(Theme.of(context).primaryColor);
      }
    }
    return WillPopScope(
      onWillPop: () async{
        toMainPage(context, user!);
        return true;
      },
      child: Scaffold(
        bottomNavigationBar: BottomNavigationBar(
      type: BottomNavigationBarType.fixed,  
      items:  bottomNavItems(),
      currentIndex: selectedBottomIdx,
      onTap: (int tappedIdx){
        if(selectedBottomIdx == tappedIdx)return;
        setState(() {
          selectedBottomIdx = tappedIdx;
        });
        navigateBottom(context, this.user!);
      },
    ),
        appBar: AppBar(leading: Container(), title: Text('settings'.tr().toString()), centerTitle: true, 
          actions: [
            Container(
              color: languageColor?[0],
              child: IconButton(
                onPressed: () {
                  setState(() {
                    languageColor?[1] = Theme.of(context).primaryColor;
                    languageColor?[0] = Colors.pink[100];
                    this.user?.language = 'en';
                    FirebaseFirestore.instance.collection('Users').doc(this.user?.email).update({'language': this.user?.language});
                    EasyLocalization.of(context)!.setLocale(Locale(this.user!.language!));
                  });
                },
                icon: Image.asset("assets/imgs/en.png"),),
            ),
            Container(
                color: languageColor?[1],
              child: IconButton(
                onPressed: () {
                  setState(() {
                    languageColor?[0] = Theme.of(context).primaryColor;
                    languageColor?[1] = Colors.pink[100];
                    this.user?.language = 'tr';
                    FirebaseFirestore.instance.collection('Users').doc(this.user?.email).update({'language': this.user?.language});
                    EasyLocalization.of(context)!.setLocale(Locale(this.user!.language!));
                  });
                },
                icon: Image.asset("assets/imgs/tr.png"),),
            ),
          ],
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CheckboxListTile(
                title: Text('soundEffects'.tr().toString(), style: TextStyle(fontSize: 24)),
                value: sound,
                onChanged: (value) {
                  setState(() {
                    sound = value!;
                  });
                  configuration?.sound = sound.toString();
                  print(configuration?.sound);
                  FirebaseFirestore.instance.collection('Users').doc(this.user?.email).update({'settings': 'sound:' + sound.toString()+ ", "});
                },
                controlAffinity: ListTileControlAffinity.trailing, 
              ),
            // ListTile(
            //   leading: Text('soundEffects'.tr().toString(), style: TextStyle(fontSize: 24),),
            //   trailing: DropdownButton<String>(
            //   value: lang,
            //   items: ['en', 'tr'].map<DropdownMenuItem<String>>((String value) {
            //     return DropdownMenuItem<String>(
            //       value: value,
            //       child: Text(value.toString(), style:TextStyle(color:Colors.black, fontSize: 24),),
            //     );
            //   }).toList(),
            //     onChanged: (String? value) {
            //       setState(() {
            //         lang = value!;
            //         FirebaseFirestore.instance.collection('Users').doc(this.user?.email).update({'language': lang});
            //       });
            //     },
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}