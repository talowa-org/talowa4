import 'package:flutter/material.dart';

class NetworkScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Network'),
      ),
      body: Center(child: Text('Network Screen')),
    );
  }
}
