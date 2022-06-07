import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class AuthenticationServices {
  final FirebaseAuth fbAuth;
  AuthenticationServices(this.fbAuth);
  Stream<User?> get authStateChanges => fbAuth.authStateChanges();
  Future<int> signIn({String? email, String? password}) async {
    try {
      await fbAuth.signInWithEmailAndPassword(
          email: email!, password: password!);
      return 1;
    } on FirebaseAuthException {
      return 0;
    }
  }

  Future<void> signOut() async {
    await fbAuth.signOut();
  }

  Future<String> update(
      {String? email,
      String? password,
      String? newEmail,
      String? newPassword}) async {
    try {
      if (newEmail != null)
        await fbAuth
            .signInWithEmailAndPassword(email: email!, password: password!)
            .then((value) => value.user?.updateEmail(newEmail));
      if (newPassword != null)
        await fbAuth
            .signInWithEmailAndPassword(email: email!, password: password!)
            .then((value) => value.user?.updatePassword(newPassword));
      return "Updated";
    } on FirebaseAuthException catch (e) {
      return e.message!;
    }
  }

  Future<String> forgetPassword({String? email}) async {
    try {
      await fbAuth.sendPasswordResetEmail(email: email!);
      return "Sent new password";
    } on FirebaseAuthException catch (e) {
      return e.message!;
    }
  }

  Future<void> delete({String? email, String? password}) async {
    await fbAuth
        .signInWithEmailAndPassword(email: email!, password: password!)
        .then((value) => value.user?.delete());
  }

  Future<int> signUp({String? email, String? password}) async {
    try {
      await fbAuth.createUserWithEmailAndPassword(
          email: email!, password: password!);
      return 1;
    } on FirebaseAuthException {
      return 0;
    }
  }

  Future<void> deleteProvider(String method) async {
    if (method == 'google')
      await signInWithGoogle();
    else if (method == 'facebook') await signInWithFacebook();
    await FirebaseAuth.instance.currentUser?.delete();
  }

  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    final GoogleSignInAuthentication? googleAuth =
        await googleUser?.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth?.accessToken,
      idToken: googleAuth?.idToken,
    );
    return await FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<UserCredential> signInWithFacebook() async {
    final LoginResult loginResult = await FacebookAuth.instance.login();
    final OAuthCredential facebookAuthCredential =
        FacebookAuthProvider.credential(loginResult.accessToken!.token);
    return FirebaseAuth.instance.signInWithCredential(facebookAuthCredential);
  }
}
