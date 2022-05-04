import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:neat_periodic_task/neat_periodic_task.dart';
import 'package:collection/collection.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'authentication.dart';
import 'widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:intl/intl.dart';

import './blue.dart';
import './widgets.dart';

var rng = Random();

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
    appBar: AppBar(title: const Text('Main App')),
    body: Column(
      children: [
        RaisedButton(
          child: const Text('Go to Bluetooth'),
          onPressed: () {
            Navigator.pushNamed(context, '/blue');
        }),
        Consumer<ApplicationState>(
          builder: (context, appState, _) => BlueButton(() {
              appState.purgeAndCalc();
          }),
        ),
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
                  addMessage: (message) => appState.addStride(message),
                  addEmailToAllow: (email) => appState.addEmailToAllow(email),
                  addToGroup: (group) => appState.addToGroup(group),
                  messages: appState.userMessages,
                  runData: appState.runData,
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

}

/// Data from a run.
class RunData {
  RunData({required this.distance, required this.heartRate});

  int distAvg() {
    return distance.map((m) => m).average.toInt();
  }

  int hrAvg() {
    return heartRate.map((m) => m).average.toInt();
  }

  void clear() {
    distance = [];
    heartRate = [];
  }

  /// Distance traveled since last bluetooth transmission.
  List<int> distance = [];
  /// User's current heart rate from last transmission.
  List<int> heartRate = [];

  /// Convert to a string.
  String toString() {
    return 'Distance: $distance, Heart Rate: $heartRate';
  }
}

class ApplicationState extends ChangeNotifier {
  ApplicationLoginState _loginState = ApplicationLoginState.loggedOut;
  ApplicationLoginState get loginState => _loginState;

  String? _email;
  String? get email => _email;
  StreamSubscription<QuerySnapshot>? _userMessageSubscription;
  StreamSubscription<DocumentSnapshot>? _dataSubscription;
  List<UserInfoMessage> _userMessages = [];
  List<UserInfoMessage> get userMessages => _userMessages;
  List<int> runDistAvgs = [];
  List<int> heartRateAvgs = [];
  final RunData _runData = RunData(distance: [], heartRate: []);
  RunData get runData => _runData;
  ApplicationState() {
    init();
  }

  NeatPeriodicTaskScheduler? testSched;

  /// 
  Future<void> purgeAndCalc() {
    var result = FirebaseFirestore.instance
    .collection('runData')
    .doc(FirebaseAuth.instance.currentUser!.email)
    .update(<String, dynamic> {
        'distance' : [0],
        'heartRate' : [0],
        'distanceTot' : FieldValue.arrayUnion([runData.distAvg()]),
        'heartRateTot' : FieldValue.arrayUnion([runData.hrAvg()]),
    }).catchError((error) => throw Exception("Failed to add run data: $error"));
    runData.clear();
    return result;
  }

  /// Send the run data [rd] to the Firestore.
  Future<void> sendRunData(RunData rd) {
    return FirebaseFirestore.instance
    .collection('runData')
    .doc(FirebaseAuth.instance.currentUser!.email)
    .update(<String, dynamic> {
        'distance' : FieldValue.arrayUnion(rd.distance),
        'heartRate' : FieldValue.arrayUnion(rd.heartRate),
    }).catchError((error) => throw Exception("Failed to add run data: $error"));
  }

  /// Add the logged in user to [group]'s group.
  Future<void> addToGroup(String group) async {
    if (_loginState != ApplicationLoginState.loggedIn) {
      throw Exception('Must be logged in');
    }

    // If the permissions allow it, add the current user to the other user's group.
    FirebaseFirestore.instance
    .collection('userData')
    .doc(group)
    .get()
    .then((DocumentSnapshot theDoc) {
        printInfo("we got the doc from $group, and it ${theDoc.exists ? 'does' : 'does not'} exist");
        if(theDoc.exists && theDoc.get("allowedEmails").contains(FirebaseAuth.instance.currentUser!.email)) {
          FirebaseFirestore.instance
          .collection('userData')
          .doc(group)
          .update(<String, dynamic> {
              'groupMates' : FieldValue.arrayUnion([FirebaseAuth.instance.currentUser!.email])
          }).catchError((error) => throw Exception("Failed to add document: $error"));
        } else {
          printInfo("Group permission error");
          throw Exception("The group you tried to join either doesn\'t exist or has not let you in.");
        }
        // Add the other user to the current user's group.
        FirebaseFirestore.instance
        .collection('userData')
        .doc(FirebaseAuth.instance.currentUser!.email)
        .update(<String, dynamic> {
            'allowedEmails' : FieldValue.arrayUnion([group]),
            'groupMates' : FieldValue.arrayUnion([group]),
        }).catchError((error) => throw Exception("Failed to add document: $error"));
    })
    .catchError((error) {
        printInfo("Could not join the group.");
        throw Exception("Failed to get $group, could not add to group.");
    });

  }

  /// Add [email] to list of emails the user has OK'd to see their data.
  Future<void> addEmailToAllow(String newEmail) {
    if (_loginState != ApplicationLoginState.loggedIn) {
      throw Exception('Must be logged in');
    }

    return FirebaseFirestore.instance
    .collection('userData')
    .doc(FirebaseAuth.instance.currentUser!.email)
    .update(<String, dynamic> {
        'allowedEmails' : FieldValue.arrayUnion([newEmail])
    }).catchError((error) => throw Exception("Failed to add document: $error"));
  }

  Future<void> addStride(String stride) async {
    if (_loginState != ApplicationLoginState.loggedIn) {
      throw Exception('Must be logged in');
    }

    int? iStep = int.tryParse(stride);
    if(iStep == null) {
      throw Exception('Stride must be a number');
    }

    // Add metadata entry.
    return FirebaseFirestore.instance
    .collection('userData')
    .doc(FirebaseAuth.instance.currentUser!.email)
    .update(<String, dynamic> {
        'stepCM' : iStep,
    }).catchError((error) => throw Exception("Failed to add document: $error"));
  }

  Future<void> init() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseAuth.instance.userChanges().listen((user) {
        if (user != null) {
          _loginState = ApplicationLoginState.loggedIn;
          _userMessageSubscription = FirebaseFirestore.instance
          .collection('userData')
          .snapshots()
          // Get user metadata and filter by group.
          .listen((snapshot) async {
              List<String> allowedEmails = [];
              try {
                allowedEmails = List<String>.from(
                  ((await FirebaseFirestore.instance
                      .collection('userData')
                      .doc(FirebaseAuth.instance.currentUser!.email)
                      .get())
                    .get("allowedEmails") ?? []) as List<dynamic>
                );
              } catch (e) {
                printInfo("Error when making allowed emails list: $e");
              }
              _userMessages = [];
              for(final document in snapshot.docs) {
                // Exclude user messages we're not subscribed to.
                if((document.get('email') ?? "-") != FirebaseAuth.instance.currentUser!.email &&
                  !allowedEmails.contains(document.get('email') ?? "-")) {
                  continue;
                }
                userMessages.add(UserInfoMessage(
                    name: (document.get('name') ?? "") as String,
                    email: (document.get('email') ?? 0) as String,
                    numSteps: (document.get('numSteps') ?? 0) as int,
                    stepCM: (document.get('stepCM') ?? 0) as int,
                    lastUpdated: DateTime.fromMillisecondsSinceEpoch(document.get('timestamp') ?? 0 as int),
                    distanceTraveled: (document.get('distanceTraveledM') ?? 0) as int,
                    groupMates: List<String>.from((document.get('groupMates') ?? []) as List<dynamic>),
                ));
              }
              notifyListeners();
          });

          // Subscribe to our data stream.
          _dataSubscription = FirebaseFirestore.instance
          .collection('runData')
          .doc(FirebaseAuth.instance.currentUser!.email)
          .snapshots()
          .listen((snapshot) async {
              _runData.distance = List<int>.from(snapshot.get('distance') ?? [0]);
              _runData.heartRate = List<int>.from(snapshot.get('heartRate') ?? [0]);
              runDistAvgs = List<int>.from(snapshot.get('distanceTot') ?? [0]);
              heartRateAvgs = List<int>.from(snapshot.get('heartRateTot') ?? [0]);
              notifyListeners();
          });
        } else {
          _loginState = ApplicationLoginState.loggedOut;
          _userMessages = [];
          _userMessageSubscription?.cancel();
          _dataSubscription?.cancel();
        }
        notifyListeners();
    });

    testSched = NeatPeriodicTaskScheduler(
      task: () async {
        sendRunData(RunData(distance: [rng.nextInt(69), rng.nextInt(420)],
            heartRate: [rng.nextInt(69), rng.nextInt(420)]));
      },
      interval: const Duration(milliseconds: 10000),
      minCycle: const Duration(milliseconds: 10000 ~/ 2 - 1),
      name: 'bt-reader',
      timeout: const Duration(milliseconds: 10000 * 2),
    );

    testSched!.start();
  }

  void startLoginFlow() {
    _loginState = ApplicationLoginState.emailAddress;
    notifyListeners();
  }

  Future<void> verifyEmail(
    String theEmail,
    void Function(FirebaseAuthException e) errorCallback,
  ) async {
    try {
      var methods =
      await FirebaseAuth.instance.fetchSignInMethodsForEmail(theEmail);
      if (methods.contains('password')) {
        _loginState = ApplicationLoginState.password;
      } else {
        _loginState = ApplicationLoginState.register;
      }
      _email = theEmail;
      printInfo("Email set!");
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
      FirebaseFirestore.instance
      .collection('userData')
      .doc(FirebaseAuth.instance.currentUser!.email)
      .set(<String, dynamic> {
          'stepCM' : 0,
          'numSteps' : 0,
          'distanceTraveledM' : 0,
          'avgHeartRate' : 0,
          'timestamp' : DateTime.now().millisecondsSinceEpoch,
          'email': FirebaseAuth.instance.currentUser!.email,
          'name': FirebaseAuth.instance.currentUser!.displayName,
          'userId': FirebaseAuth.instance.currentUser!.uid,
          'groupMates' : [],
          'allowedEmails' : [],
      }).catchError((error) => throw Exception("Failed to add document: $error"));

      // Add rundata entry.
      return FirebaseFirestore.instance
      .collection('runData')
      .doc(FirebaseAuth.instance.currentUser!.email)
      .set(<String, dynamic> {
          'distance': [0],
          'heartRate': [0],
          'distanceTot': [0],
          'heartRateTot': [0],
      }).catchError((error) => throw Exception("Failed to add document: $error"));

    } on FirebaseAuthException catch (e) {
      errorCallback(e);
    }
  }

  void signOut() {
    FirebaseAuth.instance.signOut();
  }
}
class UserForm extends StatefulWidget {
  const UserForm({required this.addMessage, required this.addEmailToAllow,
      required this.addToGroup, required this.messages, required this.runData});
  final FutureOr<void> Function(String message) addMessage;
  final FutureOr<void> Function(String email) addEmailToAllow;
  final FutureOr<void> Function(String groupName) addToGroup;
  final List<UserInfoMessage> messages;
  final RunData runData;

  @override
  _UserFormState createState() => _UserFormState();
}

class _UserFormState extends State<UserForm> {
  final _strideKey = GlobalKey<FormState>(debugLabel: '_UserFormState:Stride');
  final _emailKey = GlobalKey<FormState>(debugLabel: '_UserFormState:Email');
  final _groupKey = GlobalKey<FormState>(debugLabel: '_UserFormState:Group');

  final _strideController = TextEditingController();
  final _emailController = TextEditingController();
  final _groupController = TextEditingController();

  @override
  Widget build(BuildContext context) =>
  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Form(
          key: _emailKey,
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    hintText: 'Enter an email address.',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an email address.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              StyledButton(
                onPressed: () async {
                  if (_emailKey.currentState!.validate()) {
                    await widget.addEmailToAllow(_emailController.text);
                    _emailController.clear();
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
        )
      ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Form(
          key: _groupKey,
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _groupController,
                  decoration: const InputDecoration(
                    hintText: 'Please enter an email to add to the group',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter an email to join a group.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              StyledButton(
                onPressed: () async {
                  if (_groupKey.currentState!.validate()) {
                    await widget.addToGroup(_groupController.text);
                    _groupController.clear();
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
      ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Form(
          key: _strideKey,
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _strideController,
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
                  if (_strideKey.currentState!.validate()) {
                    await widget.addMessage(_strideController.text);
                    _strideController.clear();
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
      ),
      const SizedBox(height: 8),
      for (var message in widget.messages)
        Paragraph('${message.toString()}'),
      Paragraph(widget.runData.toString()),
      const SizedBox(height: 8),
    ]
  );
}

/// User metadata to draw.
class UserInfoMessage {
  UserInfoMessage({required this.name, required this.email, required this.numSteps,
      required this.stepCM, required this.lastUpdated, required this.distanceTraveled,
      required this.groupMates});
  final String name;
  final String email;
  final int numSteps;
  final int stepCM;
  final DateTime lastUpdated;
  final int distanceTraveled;
  final List<String> groupMates;

  String toString() {
    final DateFormat formatter = DateFormat('yyyy-MM-dd:mm');
    return '$name : $email $numSteps $stepCM ${formatter.format(lastUpdated)} $distanceTraveled $groupMates';
  }
}
