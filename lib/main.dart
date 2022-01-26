import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);
  final FlutterBlue flutterBlue = FlutterBlue.instance;
  final List<BluetoothDevice> devicesList = <BluetoothDevice>[];
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  ListView buildBluetoothDeviceView() {
    List<Container> containers = <Container>[];
    for(BluetoothDevice device in widget.devicesList) {
      containers.add(
        Container(
          height: 50,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  children: <Widget>[
                    Text(device.name == '' ? '(unkown device)' : device.name),
                    Text(device.id.toString()),
                  ],
                )
              ),
              FlatButton(
                color:Colors.blue,
                onPressed: () {  },
                child: const Text(
                  'Connect',
                style: TextStyle(color: Colors.white)),
              ),
            ],
          )
        )
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: <Widget>[
        ...containers
      ]
    );
  }

  // Add bluetooth device to list.
  void addToDeviceList(final BluetoothDevice device) {
    if (!widget.devicesList.contains(device)) {
      setState(() {
        widget.devicesList.add(device);
      });
    }
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  // Initialize the state of the bluetooth list. Scan for devices.
  @override
  void initState() {
    super.initState();
    widget.flutterBlue.connectedDevices.asStream()
    .listen((List<BluetoothDevice> devices) {
      for(BluetoothDevice device in devices) {
        addToDeviceList(device);
      }
    });
    widget.flutterBlue.scanResults.listen((List<ScanResult> results) {
      for(ScanResult result in results) {
        addToDeviceList(result.device);
      }
    });
    widget.flutterBlue.startScan();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: buildBluetoothDeviceView(),
    );
}
