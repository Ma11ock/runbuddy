import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:neat_periodic_task/neat_periodic_task.dart';


import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

import './blue.dart';

void main() => runApp(const Runbuddy());

class Runbuddy extends StatelessWidget {
  const Runbuddy({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => MaterialApp(
    routes: <String, WidgetBuilder> {
      '/': (BuildContext context) => MainHomePage(),
      '/blue': (BuildContext context) => BlueHomePage(title: 'Flutter BLE Demo')
    },
    theme: ThemeData(
      primarySwatch: Colors.blue,
    ),
  );
}

class MainHomePage extends StatefulWidget {
  MainHomePage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => MainHomePageState();
}

class MainHomePageState extends State<MainHomePage> {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Main App')),
    body: Row(
        children: [
          const Text('This is some test text'),
          RaisedButton(
            child: const Text('Go to Bluetooth'),
            onPressed: () {
              Navigator.pushNamed(context, '/blue');
           }),
        ],
    ),
  );

}