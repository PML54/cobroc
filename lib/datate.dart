import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class ConfigBrocante extends StatefulWidget {
  const ConfigBrocante({super.key});

  @override
  _ConfigBrocanteState createState() => _ConfigBrocanteState();
}

class _ConfigBrocanteState extends State<ConfigBrocante> {
  var finaldate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => callDatePicker());
  }

  void callDatePicker() async {
    var order = await getDate();
    if (order != null) {
      setState(() {
        finaldate = order.toString().substring(0, 10);
        Navigator.pop(context, finaldate);
      });
    }
  }

  Future<DateTime?> getDate() {
    return showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light(),
          child: child!,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const <Locale>[
        Locale('fr'), // Hebrew
      ],
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Configuration'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                decoration: BoxDecoration(color: Colors.grey[200]),
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: finaldate == null
                    ? const Text("2024-**-**", textScaleFactor: 2.0)
                    : Text("$finaldate", textScaleFactor: 2.0),
              ),
              ElevatedButton(
                onPressed: callDatePicker,
                child: const Text('Date', style: TextStyle(color: Colors.white)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, finaldate);
                },
                child: Container(
                    child: const Text('Back',
                        style: TextStyle(color: Colors.white))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
