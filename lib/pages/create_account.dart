import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluttershare/widgets/header.dart';

class CreateAccount extends StatefulWidget 
{
  @override
  _CreateAccountState createState() => _CreateAccountState();
}

class _CreateAccountState extends State<CreateAccount> 
{
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormState>();
  String username;

  submit()
  {
    final form = _formKey.currentState;

    if(form.validate())
    {
      form.save();
      SnackBar snackbar = SnackBar(content: Text("Olá $username!",));
      _scaffoldKey.currentState.showSnackBar(snackbar);
      Timer(Duration(seconds: 2), () 
      {
        Navigator.pop(context, username);
      });
    }
  }


  @override
  Widget build(BuildContext parentContext) 
  {
    return Scaffold
    (
      key: _scaffoldKey,
      appBar: header(context, titleText: "Atualize seu perfil", removeBackButton: true),
      body: ListView
      (
        children: <Widget>
        [
          Container
          (
            child: Column
            (
              children: <Widget>
              [
                Padding
                (
                  padding: EdgeInsets.only(top: 25.0),
                  child: Center
                  (
                    child: Text("Nome de usuário", style: TextStyle(fontSize: 25.0),),
                  ),
                ),
                Padding
                (
                  padding: EdgeInsets.all(16.0),
                  child: Container
                  (
                    child: Form
                    (
                      key: _formKey,
                      child: TextFormField
                      (
                        autovalidate: true,
                        validator: (val)
                        {
                          if(val.trim().length < 3 || val.isEmpty)
                          {
                            return "Nome muito curto!";

                          }
                          else if(val.trim().length > 12)
                          {
                            return "Nome muito longo";
                          }
                          else
                          {
                            return null;
                          }
                        },
                        onSaved: (val) => username = val,
                        decoration: InputDecoration
                        (
                          border: OutlineInputBorder(),
                          labelText: "Username",
                          labelStyle: TextStyle(fontSize: 15.0),
                          hintText: "Mais de 3 letras"
                        ),
                      ),
                    ),
                  ),
                ),
                GestureDetector
                (
                  onTap: submit,
                  child: Container
                  (
                    height: 50.0,
                    width: 350.0,
                    decoration: BoxDecoration
                    (
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(7.0)
                    ),
                    child: Center
                    (
                      child: Text
                      (
                        "Submit",
                        style: TextStyle
                        (
                          color: Colors.white,
                          fontSize: 15.0,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    ),
                  ),
                )
              ],
            ),
          ),
        ],),
    );
  }
}
