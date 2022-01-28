import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'dart:convert';

// Wrapper around flutterblue.instance.
class RunbuddyBlue {
  final FlutterBlue flutterBlue = FlutterBlue.instance;
  BluetoothDevice? connectedDevice;
}

class RunbuddyBloc {
}