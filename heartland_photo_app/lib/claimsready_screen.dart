import 'package:flutter/material.dart';

class ClaimsreadyScreen extends StatefulWidget {
  const ClaimsreadyScreen({super.key});

  @override
  State<ClaimsreadyScreen> createState() => _ClaimsreadyScreenState();
}

class _ClaimsreadyScreenState extends State<ClaimsreadyScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Heartland Workforce Solutions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blueGrey[800],
        elevation: 0,
      ),
      body: Center(
        child: Text(''),
      ),
    );
  }
}
