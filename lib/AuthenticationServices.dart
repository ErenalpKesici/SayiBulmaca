import 'package:firebase_auth/firebase_auth.dart';

class AuthenticationServices{
  final FirebaseAuth fbAuth;
  AuthenticationServices(this.fbAuth);
  Stream<User?> get authStateChanges => fbAuth.authStateChanges();
  Future<String> signIn({String? email, String? password}) async{
    try{
      await fbAuth.signInWithEmailAndPassword(email: email!, password: password!);
      return "Signed in";
    }on FirebaseAuthException catch(e){
      return e.message!;
    }
  }
  Future<void> signOut() async{
    await fbAuth.signOut();
  }
  Future<String> update({String? email, String? password, String? newEmail, String? newPassword}) async{
    try{
      await fbAuth.signInWithEmailAndPassword(email: email!, password: password!).then((value) => value.user?.updateEmail(newEmail!));
      return "Updated";
    }on FirebaseAuthException catch(e){
      return e.message!;
    }
  }
  Future<String> forgetPassword({String? email}) async{
    try {
      await fbAuth.sendPasswordResetEmail(email: email!);
      return "Sent new password";
    }on FirebaseAuthException catch(e){
      return e.message!;
    }
  }
  // Future<void> delete({String? email, String? password}) async{
  //   try {
  //     await fbAuth.signInWithEmailAndPassword(email: email!, password: password!)
  //         .then((value) => value.user?.delete());
  //     return "Deleted";
  //   }on FirebaseAuthException catch(e){
  //     return e.message;
  //   }
  // }
  Future<String> signUp({String? email, String? password}) async{
    try{
      await fbAuth.createUserWithEmailAndPassword(email: email!, password: password!);
      return "Signed up";
    }on FirebaseAuthException catch(e){
      return e.message!;
    }
  }
}