import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:neat_periodic_task/neat_periodic_task.dart';

import 'package:firebase_auth/firebase_auth.dart'; // new
import 'package:firebase_core/firebase_core.dart'; // new
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';           // new

import 'firebase_options.dart';                    // new
import 'authentication.dart';                  // new
import 'widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';  // new

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

import './blue.dart';
import './widgets.dart';

void main() => runApp(ChangeNotifierProvider(
    create: (context) => ApplicationState(),
    builder: (context, _) => const Runbuddy(),
));

class Runbuddy extends StatelessWidget {
  const Runbuddy({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Runbuddy',
    routes: <String, WidgetBuilder> {
      '/': (BuildContext context) => const MainHomePage(),
      '/blue': (BuildContext context) => BlueHomePage(title: 'Flutter BLE Demo')
    },
    theme: ThemeData(
      primarySwatch: Colors.blue,
    ),
    // Add from here
    // to here
  );
}

class MainHomePage extends StatefulWidget {
  const MainHomePage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => MainHomePageState();
}

class MainHomePageState extends State<MainHomePage> {
  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: BlueButton(),
    appBar: AppBar(title: const Text('Main App')),
    body: Column(
      children: [
        const Text('This is some test text'),
        RaisedButton(
          child: const Text('Go to Bluetooth'),
          onPressed: () {
            Navigator.pushNamed(context, '/blue');
        }),
        Consumer<ApplicationState>(
          builder: (context, appState, _) => Authentication(
            email: appState.email,
            loginState: appState.loginState,
            startLoginFlow: appState.startLoginFlow,
            verifyEmail: appState.verifyEmail,
            signInWithEmailAndPassword: appState.signInWithEmailAndPassword,
            cancelRegistration: appState.cancelRegistration,
            registerAccount: appState.registerAccount,
            signOut: appState.signOut,
          ),
        ),
      ],
    ),
  );

}

class ApplicationState extends ChangeNotifier {
  ApplicationState() {
    init();
  }

  // Add from here
  Future<DocumentReference> addMessageToGuestBook(List<double> data, Duration avgStep) {
    if (_loginState != ApplicationLoginState.loggedIn) {
      throw Exception('Must be logged in');
    }

    return FirebaseFirestore.instance
    .collection('run-data')
    .add(<String, dynamic>{
        'data': data,
        'stepMS' : avgStep.inMilliseconds,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'name': FirebaseAuth.instance.currentUser!.displayName,
        'userId': FirebaseAuth.instance.currentUser!.uid,
    });
  }

  Future<void> init() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseAuth.instance.userChanges().listen((user) {
        if (user != null) {
          _loginState = ApplicationLoginState.loggedIn;
        } else {
          _loginState = ApplicationLoginState.loggedOut;
        }
        notifyListeners();
    });
  }

  ApplicationLoginState _loginState = ApplicationLoginState.loggedOut;
  ApplicationLoginState get loginState => _loginState;

  String? _email;
  String? get email => _email;

  void startLoginFlow() {
    _loginState = ApplicationLoginState.emailAddress;
    notifyListeners();
  }

  Future<void> verifyEmail(
    String email,
    void Function(FirebaseAuthException e) errorCallback,
  ) async {
    try {
      var methods =
      await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      if (methods.contains('password')) {
        _loginState = ApplicationLoginState.password;
      } else {
        _loginState = ApplicationLoginState.register;
      }
      _email = email;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      errorCallback(e);
    }
  }

  Future<void> signInWithEmailAndPassword(
    String email,
    String password,
    void Function(FirebaseAuthException e) errorCallback,
  ) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      errorCallback(e);
    }
  }

  void cancelRegistration() {
    _loginState = ApplicationLoginState.emailAddress;
    notifyListeners();
  }

  Future<void> registerAccount(
    String email,
    String displayName,
    String password,
    void Function(FirebaseAuthException e) errorCallback) async {
    try {
      var credential = await FirebaseAuth.instance
      .createUserWithEmailAndPassword(email: email, password: password);
      await credential.user!.updateDisplayName(displayName);
    } on FirebaseAuthException catch (e) {
      errorCallback(e);
    }
  }

  void signOut() {
    FirebaseAuth.instance.signOut();
  }
}
