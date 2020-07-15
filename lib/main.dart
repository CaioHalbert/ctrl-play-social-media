import 'package:flutter/material.dart';
import 'package:fluttershare/pages/home.dart';

void main() 
{
  runApp(MyApp());
}

class MyApp extends StatelessWidget 
{
  @override
  Widget build(BuildContext context) 
  {
    return MaterialApp(
      title: 'Write',
      debugShowCheckedModeBanner: false,
      theme: ThemeData
      (
        primaryColor: Colors.blue[900],
        accentColor: Colors.orange[900],
      ),
      home: Home(),
    );
  }
}
