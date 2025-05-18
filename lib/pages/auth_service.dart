import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<UserCredential> signInWithGoogle() async {
    // Trigger the Google authentication flow.
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      // The user canceled the sign-in.
      throw Exception("Google sign-in canceled");
    }

    // Obtain the authentication details from the request.
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    // Create a new credential.
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Sign in to Firebase with the Google user credential.
    final userCredential = await _auth.signInWithCredential(credential);

    // Check if the signed-in user's email is authorized.
    // final String? userEmail = userCredential.user?.email;
    // if (userEmail != 'amanda.sieb10@gmail.com') {
    //   // If not authorized, sign out and throw an error.
    //   await signOut();
    //   throw Exception("This account is not authorized to access the app.");
    // }

    return userCredential;
  }

  // Optionally, you can add a sign-out function.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
