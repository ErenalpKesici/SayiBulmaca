import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get_storage/get_storage.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:sayibulmaca/main.dart';


class IntroductionPageSend extends StatefulWidget {
  IntroductionPageSend();
  @override
  State<StatefulWidget> createState() {
    return IntroductionPage();
  }
}
class IntroductionPage extends State<IntroductionPageSend>{
  final GetStorage  introShown = GetStorage();
  void closeIntro(BuildContext context){
    introShown.write('displayed', true);
    print(Navigator.canPop(context));
    if(!Navigator.canPop(context)){
      Navigator.pop(context); 
      Navigator.of(context).push(MaterialPageRoute(builder: (context) =>InitialPageSend()));
    }
    else
      Navigator.pop(context); 
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IntroductionScreen(
        showNextButton: true,
        showSkipButton: true,
        showDoneButton: true,
        next: Text("next".tr().toString()),
        skip: Text("skip".tr().toString()),
        done: Text("done".tr().toString()),
        onDone: () {
          closeIntro(context);
        },
        onSkip: (){
          closeIntro(context);
        },
        dotsDecorator: DotsDecorator(color: Colors.grey, activeColor: Theme.of(context).primaryColor),
        pages: [
          PageViewModel(
            titleWidget: Padding(
              padding: const EdgeInsets.fromLTRB(0, 64, 0, 0),
              child: Text('helpScreenTitle0'.tr().toString(), style: TextStyle(fontWeight: FontWeight.bold, wordSpacing: 8, fontSize: 24 ), textAlign: TextAlign.center,),
            ),
            image: Padding(
              padding: const EdgeInsets.fromLTRB(0, 64, 0, 0),
              child: Image.asset("helpScreenImg0".tr().toString(), width: 400,),
            ),
            body: 'helpScreenInfo0'.tr().toString()
          ),
          PageViewModel(
            title: 'helpScreenTitle1'.tr().toString(),
            image: Image.asset("helpScreenImg1".tr().toString(), width: 200,),
            body: 'helpScreenInfo1'.tr().toString(),
          ),
          PageViewModel(
            image:  Image.asset("helpScreenImg2".tr().toString(), width: 150),
            title: 'helpScreenTitle2'.tr().toString(),
            body: 'helpScreenInfo2'.tr().toString()
          ),
          PageViewModel(
            title: 'helpScreenTitle3'.tr().toString(),
            image: Image.asset("helpScreenImg3".tr().toString(), width: 300,),
            body: 'helpScreenInfo3'.tr().toString()
          ),
        ],
      ),
    );
  }

}