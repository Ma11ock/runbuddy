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
      '/blue': (BuildContext context) => BlueHomePage(title: 'Bluetooth Devices')
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
        // Modify from here
        Consumer<ApplicationState>(
          builder: (context, appState, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (appState.loginState == ApplicationLoginState.loggedIn) ...[
                const Header('User Info'),
                UserForm(
                  addMessage: (message) =>
                  appState.addMessageToUserForm(message),
                ),
              ],
            ],
          ),
        ),
        // To here.
      ],
    ),
  );

}

class ApplicationState extends ChangeNotifier {
  ApplicationLoginState _loginState = ApplicationLoginState.loggedOut;
  ApplicationLoginState get loginState => _loginState;

  String? _email;
  String? get email => _email;

  // Add from here
  StreamSubscription<QuerySnapshot>? _userMessageSubscription;
  List<UserInfoMessage> _userMessages = [];
  List<UserInfoMessage> get userMessages => _userMessages;
  // to here.
  ApplicationState() {
    init();
  }

  // Add from here
  Future<DocumentReference> addMessageToUserForm(String stride) {
    if (_loginState != ApplicationLoginState.loggedIn) {
      throw Exception('Must be logged in');
    }

    int? iStep = int.tryParse(stride);
    if(iStep == null) {
      throw Exception('Stride must be a number');
    }

    return FirebaseFirestore.instance
    .collection('run-data')
    .add(<String, dynamic>{
        'step' : iStep!,
        'email': FirebaseAuth.instance.currentUser!.email,
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
          // Add from here
          _userMessageSubscription = FirebaseFirestore.instance
          .collection('guestbook')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((snapshot) {
              _userMessages = [];
              for (final document in snapshot.docs) {
                _userMessages.add(
                  UserInfoMessage(
                    name: document.data()['name'] as String,
                    message: document.data()['text'] as String,
                  ),
                );
              }
              notifyListeners();
          });
        } else {
          _loginState = ApplicationLoginState.loggedOut;
          _userMessages = [];
          _userMessageSubscription?.cancel();
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
class UserForm extends StatefulWidget {
  const UserForm({required this.addMessage, required this.messages});
  final FutureOr<void> Function(String message) addMessage;
  final List<UserInfoMessage> messages;

  @override
  _UserFormState createState() => _UserFormState();
}

class _UserFormState extends State<UserForm> {
  final _formKey = GlobalKey<FormState>(debugLabel: '_UserFormState');
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Form(
        key: _formKey,
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Please enter your walking stride.',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter your stride';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            StyledButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  await widget.addMessage(_controller.text);
                  _controller.clear();
                }
              },
              child: Row(
                children: const [
                  Icon(Icons.send),
                  SizedBox(width: 4),
                  Text('SEND'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UserInfoMessage {
  UserInfoMessage({required this.name, required this.message});
  final String name;
  final String message;
}
