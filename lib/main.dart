import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:neat_periodic_task/neat_periodic_task.dart';


import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BLE Demo',
    theme: ThemeData(
      primarySwatch: Colors.blue,
    ),
    home: MyHomePage(title: 'Flutter BLE Demo'),
  );
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;
  final FlutterBlue flutterBlue = FlutterBlue.instance;
  final List<BluetoothDevice> devicesList = <BluetoothDevice>[];
  final Map<Guid, List<int>> readValues = <Guid, List<int>>{};

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _writeController = TextEditingController();
  BluetoothDevice? _connectedDevice;
  late List<BluetoothService> _services;

  void _addDeviceTolist(final BluetoothDevice device) {
    if (!widget.devicesList.contains(device)) {
      setState(() {
        widget.devicesList.add(device);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    widget.flutterBlue.connectedDevices
        .asStream()
        .listen((List<BluetoothDevice> devices) {
      for (BluetoothDevice device in devices) {
        _addDeviceTolist(device);
      }
    });
    widget.flutterBlue.scanResults.listen((List<ScanResult> results) {
      for (ScanResult result in results) {
        _addDeviceTolist(result.device);
      }
    });
    widget.flutterBlue.startScan();
  }

  ListView _buildListViewOfDevices() {
    List<Container> containers = <Container>[];
    for (BluetoothDevice device in widget.devicesList) {
      containers.add(
        Container(
          height: 50,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  children: <Widget>[
                    Text(device.name == '' ? '(unknown device)' : device.name),
                    Text(device.id.toString()),
                  ],
                ),
              ),
              FlatButton(
                color: Colors.blue,
                child: const Text(
                  'Connect',
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () async {
                  widget.flutterBlue.stopScan();
                  try {
                    await device.connect();
                  } catch (e) {
                    if (e.toString() != 'already_connected') {
                      rethrow;
                    }
                  } finally {
                    _services = await device.discoverServices();
                  }
                  setState(() {
                    _connectedDevice = device;
                  });
                },
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: containers.length,
      itemBuilder: (BuildContext context, int index) {
        return containers[index];
      },
    );
  }

  List<ButtonTheme> _buildReadWriteNotifyButton(
      BluetoothCharacteristic characteristic) {
    List<ButtonTheme> buttons = <ButtonTheme>[];
    if (characteristic.properties.write) {
      buttons.add(
        ButtonTheme(
          minWidth: 10,
          height: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: RaisedButton(
              child: const Text('WRITE', style: const TextStyle(color: Colors.white)),
              onPressed: () async {
                await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text("Write"),
                        content: Row(
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                controller: _writeController,
                              ),
                            ),
                          ],
                        ),
                        actions: <Widget>[
                          FlatButton(
                            child: const Text("Send"),
                            onPressed: () {
                              characteristic.write(
                                  utf8.encode(_writeController.value.text));
                              Navigator.pop(context);
                            },
                          ),
                          FlatButton(
                            child: const Text("Cancel"),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      );
                    });
              },
            ),
          ),
        ),
      );
    }
    if (characteristic.properties.notify) {
      buttons.add(
        ButtonTheme(
          minWidth: 10,
          height: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: RaisedButton(
              child: const Text('NOTIFY', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                characteristic.value.listen((value) {
                  widget.readValues[characteristic.uuid] = value;
                });
                await characteristic.setNotifyValue(true);
              },
            ),
          ),
        ),
      );
    }

    return buttons;
  }

  ListView _buildConnectDeviceView() {
    List<Container> containers = <Container>[];

    for (BluetoothService service in _services) {
      List<Widget> characteristicsWidget = <Widget>[];

      for (BluetoothCharacteristic characteristic in service.characteristics) {
        characteristicsWidget.add(
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(characteristic.uuid.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  children: <Widget>[
                    //..._buildReadWriteNotifyButton(characteristic),
                    JSONScreen(device: _connectedDevice!, characteristic: characteristic),
                  ],
                ),
                const Divider(),
              ],
            ),
          ),
        );
      }
      containers.add(
        Container(
          child: ExpansionTile(
              title: Text(service.uuid.toString()),
              children: characteristicsWidget),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: containers.length,
      itemBuilder: (BuildContext context, int index) {
        return containers[index];
      },
    );
  }

  ListView _buildView() {

    if (_connectedDevice != null) {
      return _buildConnectDeviceView();
    }
    return _buildListViewOfDevices();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
    ),
    body: Row(
      children: [
        Expanded(
            child: SizedBox(
                  height: 1200.0,
                  child: _buildView()
            ),
        ),
      ],
    ),
  );
}

void printInfo(String text) {
  print('\x1B[33m$text\x1B[0m');
}

class JSONScreen extends StatefulWidget {
  final BluetoothDevice device;
  final BluetoothCharacteristic characteristic;
  final Map<Guid, List<int>> readValues = <Guid, List<int>>{};
  JSONScreen({Key? key, required this.device,
    required this.characteristic}) :
        super(key: key);

  @override
  JSONScreenState createState() => JSONScreenState();
}

class JSONScreenState extends State<JSONScreen> {
  NeatPeriodicTaskScheduler? readTimer;
  // The last time the bluetooth device was read from.
  DateTime lastTimeRead = DateTime.now();
  // Time interval between reads (milliseconds).
  int timeIntervalMs = 1000;
  bool isReading = false;
  Map<String, dynamic> readResponse = {};

  Widget jsonResponseTree() {
    if(
    //readResponse.containsKey("battery") &&
       readResponse.containsKey("time")) {
      // Runbuddy JSON.
      // String json.
      String jsonString = const JsonEncoder().convert(readResponse);
      return Column(
        children: [
     //     Text(readResponse["battery"]["percent"]),
          Text('{\n\t${readResponse["time"].toString()}\n}'),
        ],
      );
    }

    if(readResponse.isEmpty) {
      return const Text("No response yet.");
    }
    // "String" is a generic key not found in the runbuddy normal result.
    // For valid results that are not runbuddy JSON.
    else if(!readResponse.containsKey("String")) {
      readResponse["String"] = "Unknown response";
    }

    String jsonResponse = const JsonEncoder().convert(readResponse);
    return Text(jsonResponse);
  }

  NeatPeriodicTaskScheduler createReadTimer(Duration d) {

    return NeatPeriodicTaskScheduler(
      task: () async {
          printInfo("I am reading.");
          List<int> rValue = [];
          var sub = widget.characteristic.value.listen((value) {
            rValue = value;
          });
          List<int> rawBtData = await widget.characteristic.read();
          String btData = String.fromCharCodes(rawBtData);
          setState(() {
            widget.readValues[widget.characteristic.uuid] = rValue;
            // Try to treat result as JSON. If we cannot, just output raw result.
            printInfo("The BT data is $btData and the raw data is ${rawBtData.toString()}");
            //try {
              // Would be used in an actual app.
              //readResponse = const JsonDecoder().convert(btData);
            readResponse["time"] = {"stamp" : btData};
            //} on FormatException catch (_, e){
           //   readResponse["String"] = btData as dynamic;
            //}
            lastTimeRead = DateTime.now();
          });
          sub.cancel();
        },
      interval: const Duration(seconds: 5),
      minCycle: d, name: 'bt-reader',
      timeout: const Duration(seconds: 5),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<ButtonTheme> buttons = [];
    if (widget.characteristic.properties.read) {
      buttons.add(
        ButtonTheme(
          minWidth: 10,
          height: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: RaisedButton(
              color: Colors.blue,
              child: const Text('READ', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                readTimer = createReadTimer(Duration(milliseconds: timeIntervalMs));
                readTimer?.start();
              },
            ),
          ),
        ),
      );
    }
    return Container(
    child:
      Row(
     children: [
       Column (
       children: <Widget>[
       ...buttons,
        RaisedButton(
        onPressed: () {
          timeIntervalMs += 1000;
          if(readTimer != null) {
            readTimer?.stop();
            readTimer = createReadTimer(Duration(milliseconds: timeIntervalMs));
          }
        },
        child: const Icon(Icons.exposure_plus_1),
      ),
      RaisedButton(
        onPressed: () {
          timeIntervalMs = max(1000, timeIntervalMs - 1000);
          if(readTimer != null) {
            readTimer?.stop();
            readTimer = createReadTimer(Duration(milliseconds: timeIntervalMs));
          }
        },
        child: const Icon(Icons.exposure_neg_1),
      ),
         Text('${lastTimeRead.hour.toString()}:${lastTimeRead.minute.toString()}:${lastTimeRead.second.toString()}'),
       ],
    ),
       jsonResponseTree(),
     ]));
  }
}

