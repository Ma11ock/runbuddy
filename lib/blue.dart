import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:neat_periodic_task/neat_periodic_task.dart';


import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

/// Bluetooth button. Maintains the bluetooth in global state, or whereever this
/// button is present.
class BlueButton extends FloatingActionButton {
  /// Create a bluetooth button with a default pressed function that toggles reading
  /// from the device.
  BlueButton() : super(
    onPressed: () {
      if(readTimer != null) {
        shouldRead = !shouldRead;
        if(!shouldRead) {
          printInfo("Stopping the read timer.");
          readTimer!.stop();
        } else {
          printInfo("Starting the read timer.");
          createReadTimer(characteristic!, timeIntervalMs);
        }
      } else {
        printInfo("Warn: Bluetooth not set up.");
      }
    },
    child: const Icon(Icons.bluetooth));

  /// Create a static timer that reads from [char] every [timeIntervalMs] milliseconds.
  static void createReadTimer(BluetoothCharacteristic char,
    int timeIntervalMs) {
    if(readTimer != null) {
      printInfo("Stopping the current read timer");
      readTimer!.stop().then((v) {
      });
      readTimer = null;
    }
    printInfo("Creating a new timer with duration $timeIntervalMs");
    readTimer = NeatPeriodicTaskScheduler(
      task: () async {
        printInfo("Performing a read...");
        List<int> rValue = [];
        var sub = char.value.listen((value) {
            rValue = value;
        });
        List<int> rawBtData = await char.read();
        String btData = String.fromCharCodes(rawBtData);
        // Set state function.
        Map<String, dynamic> readResponse = {};
        readValues[char.uuid] = rValue;
        printInfo("The BT data is $btData and the raw data is ${rawBtData.toString()}");
        //try {
        // Would be used in an actual app.
        //readResponse = const JsonDecoder().convert(btData);
        // Check for change in time interval.
        readResponse["time"] = {"stamp": btData};

        messageQueue.add(readResponse);
        //} on FormatException catch (_, e){
        //   readResponse["String"] = btData as dynamic;
        //}
        lastTimeRead = DateTime.now();
        sub.cancel();
      },
      interval: Duration(milliseconds: timeIntervalMs),
      minCycle: Duration(milliseconds: timeIntervalMs ~/ 2 - 1),
      name: 'bt-reader',
      timeout: Duration(milliseconds: timeIntervalMs * 2),
    );

    // Wait until some time has passed to start reading.
    Timer(Duration(milliseconds: timeIntervalMs), () {
        readTimer?.start();
    });

    // Set global state for tracking.
    characteristic = char;
    BlueButton.timeIntervalMs = timeIntervalMs;
  }

  /// Set the characteristic to read. Resets the timer.
  static void setCharacteristic(BluetoothCharacteristic btc) {
    characteristic = btc;
    createReadTimer(btc, timeIntervalMs);
  }

  static void unsetCharacteristic() {
    characteristic = null;
    if(readTimer != null) {
      readTimer!.stop();
      readTimer = null;
    }
  }

  /// Toggle the read state. If shouldRead is now true, start the timer. If it is
  /// now false, stop it.
  static void toggleRead() {
    shouldRead = !shouldRead;
    if(readTimer != null) {
      if(shouldRead && characteristic != null) {
        createReadTimer(characteristic!, timeIntervalMs);
      } else {
        readTimer!.stop();
        readTimer = null;
      }
    }
  }

  /// Get the read value fromt the read vector.
  static List<int>? getRValue() {
    return readValues[characteristic!.uuid];
  }

  /// Time interval in milliseconds to read from bluetooth.
  static int timeIntervalMs = 1000;
  /// If true, should read from the bluetooth device. If false, stop reading.
  static bool shouldRead = false;
  /// The characteristic to read from.
  static BluetoothCharacteristic? characteristic;
  /// The read timer. Reads the bluetooth device.
  static NeatPeriodicTaskScheduler? readTimer;
  // The last time the bluetooth device was read from.
  static DateTime lastTimeRead = DateTime.now();
  // Time interval between reads (milliseconds).
  static bool isReading = false;
  /// Queue of messages from the bluetooth device.
  static final Queue<Map<String, dynamic>> messageQueue = Queue();
  /// Variable for testing. If true, do not render the JSON recieved from the device.
  static bool testDoNotMakeTree = false;
  /// The FlutterBlue instance.
  static final FlutterBlue flutterBlue = FlutterBlue.instance;
  /// Read values from the bluetooth device.
  static final Map<Guid, List<int>> readValues = <Guid, List<int>>{};
}

/// Flutter window area. 
class BlueWidget extends StatelessWidget {
  const BlueWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BLE Demo',
    theme: ThemeData(
      primarySwatch: Colors.blue,
    ),
    home: BlueHomePage(title: 'Flutter BLE Demo'),
  );
}

/// Flutter window state.
class BlueHomePage extends StatefulWidget {
  BlueHomePage({Key? key, required this.title}) : super(key: key);

  /// Title of the window.
  final String title;
  /// List of potential Bluetooth devices.
  final List<BluetoothDevice> devicesList = <BluetoothDevice>[];
  /// Read values from the GUID devices.
  final Map<Guid, List<int>> readValues = <Guid, List<int>>{};

  @override
  _BlueHomePageState createState() => _BlueHomePageState();
}

/// State of the window widget.
class _BlueHomePageState extends State<BlueHomePage> {
  /// For displaying the JSON response.
  final _writeController = TextEditingController();
  /// Current connected device.
  BluetoothDevice? _connectedDevice;
  /// Services offered by the current device.
  late List<BluetoothService> _services;

  /// Add a device to the screen upon discovery.
  void _addDeviceTolist(final BluetoothDevice device) {
    if (!widget.devicesList.contains(device)) {
      setState(() {
          widget.devicesList.add(device);
      });
    }
  }

  /// Initialize the state of the window.
  @override
  void initState() {
    super.initState();
    // Get all nearby devies.
    BlueButton.flutterBlue.connectedDevices
    .asStream()
    .listen((List<BluetoothDevice> devices) {
        for (BluetoothDevice device in devices) {
          _addDeviceTolist(device);
        }
    });
    // Display everything.
    BlueButton.flutterBlue.scanResults.listen((List<ScanResult> results) {
        for (ScanResult result in results) {
          _addDeviceTolist(result.device);
        }
    });
    BlueButton.flutterBlue.startScan();
  }

  /// Build the view of the devices.
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
                  BlueButton.flutterBlue.stopScan();
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

  /// Build the button used to read.
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

  /// Show list of the connected deive and the services it offers.
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

  /// Build the window.
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

/// Helper function used to print stand-out [text].
void printInfo(String text) {
  print('\x1B[33m$text\x1B[0m');
}

/// Display the JSON response.
class JSONScreen extends StatefulWidget {
  /// The device currently being displayed.
  final BluetoothDevice device;
  /// The read values from the device.
  final Map<Guid, List<int>> readValues = <Guid, List<int>>{};
  /// Current characteristic being read.
  final BluetoothCharacteristic characteristic;
  JSONScreen({Key? key, required this.device,
      required this.characteristic}) :
  super(key: key);

  @override
  JSONScreenState createState() => JSONScreenState();
}

class JSONScreenState extends State<JSONScreen> {
  /// Time interval we should update the screen.
  static int timeIntervalMs = 1000;
  /// True if we should update the screen.
  static bool shouldUpdate = false;
  /// Timer for updating the screen.
  late NeatPeriodicTaskScheduler readTimer;

  /// Create the update screen timer for this JSON window.
  void initTimer() {
    printInfo("Creating read timer");
    readTimer = NeatPeriodicTaskScheduler(
      task: () async {
        printInfo("Setting the task");
        // Reset the state, reads from BlueButton.
        if (shouldUpdate) {
          setState(() {});
        }
      },
      timeout: const Duration(seconds: 1 * 2),
      minCycle: const Duration(milliseconds: 500),
      interval: const Duration(milliseconds: 1001),
      name: 'test-schedular',
    );
    readTimer.start();
  }

  /// Build the JSON text widget.
  Widget jsonResponseTree() {
    if(!shouldUpdate) {
      return const Text("Nothing for now...");
    }
    Map<String, dynamic> readResponse = {};
    if(BlueButton.messageQueue.isNotEmpty) {
      readResponse = BlueButton.messageQueue.removeFirst();
    }
    // Check if the bt module is trying to change the delta time.
    if(readResponse.containsKey("deltaTime")) {
      int newTimeMS = readResponse["deltaTime"] as int;
      printInfo("Changing timer from $BlueButton.timeIntervalMs to ${timeIntervalMs += newTimeMS}");
      if(timeIntervalMs > 0)  {
        BlueButton.createReadTimer(widget.characteristic, timeIntervalMs);
      } else {
        BlueButton.readTimer!.stop();
        BlueButton.readTimer = null;
        printInfo("Stopping timer.");
      }
      return Text("Setting time by: $newTimeMS");
    }

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

    printInfo("Response");
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
                shouldUpdate = true;
                initTimer();
                BlueButton.createReadTimer(widget.characteristic,
                  timeIntervalMs);
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
                  printInfo("Increasing the timer by 1000ms.");
                  timeIntervalMs += 1000;
                  BlueButton.createReadTimer(widget.characteristic,
                    timeIntervalMs);
                },
                child: const Icon(Icons.exposure_plus_1),
              ),
              RaisedButton(
                onPressed: () {
                  printInfo("Decrementing the timer by 1000ms.");
                  timeIntervalMs = max(1000, timeIntervalMs - 1000);
                  BlueButton.createReadTimer(widget.characteristic,
                    timeIntervalMs);
                },
                child: const Icon(Icons.exposure_neg_1),
              ),
              RaisedButton(
                onPressed: () {
                  shouldUpdate = !shouldUpdate;
                  printInfo("Toggling rendering the next message");
                },
                child: const Icon(Icons.stop_circle_outlined),
              ),
              Text('${BlueButton.lastTimeRead.hour.toString()}:${BlueButton.lastTimeRead.minute.toString()}:${BlueButton.lastTimeRead.second.toString()}'),
            ],
          ),
          jsonResponseTree(),
    ]));
  }
}
