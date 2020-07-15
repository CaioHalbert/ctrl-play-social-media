import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttershare/models/user.dart';
import 'package:fluttershare/pages/activity_feed.dart';
import 'package:fluttershare/pages/create_account.dart';
import 'package:fluttershare/pages/profile.dart';
import 'package:fluttershare/pages/search.dart';
import 'package:fluttershare/pages/timeline.dart';
import 'package:fluttershare/pages/upload.dart';
import 'package:google_sign_in/google_sign_in.dart';

final GoogleSignIn googleSignIn = GoogleSignIn();
final StorageReference storageRef = FirebaseStorage.instance.ref();
final usersRef = Firestore.instance.collection("users");
final postRef = Firestore.instance.collection("posts");
final commentsRef = Firestore.instance.collection("comments");
final followersRef = Firestore.instance.collection("followers");
final followingRef = Firestore.instance.collection("following");
final activityFeedRef = Firestore.instance.collection("feed");
final timelineRef = Firestore.instance.collection('timeline');
final DateTime timestamp = DateTime.now();

User currentUser;

class Home extends StatefulWidget 
{
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> 
{
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  FirebaseMessaging _firebaseMessaging = FirebaseMessaging();
  PageController pageController; // variavel que controla o fluxo de paginas
  bool isAuth = false;// variavel para verificar autenticação do usuario
  int pageIndex = 0;//Base para o indexador da lista de paginas

  
//---------------------------inicialização---------------------------------
  @override
  //autentica o usuario
  void initState() 
  { 
    super.initState();
    pageController = PageController();

    googleSignIn.onCurrentUserChanged.listen((account)
    {
      handleSignIn(account);
    },
    
      onError: (err)
      {
        print('Error on signin $err');
      }
    );
    // reautentica o usuario ao abrir o app
    googleSignIn.signInSilently(suppressErrors: false).then(
      (account)
      {
        handleSignIn(account);
      }).catchError((err)
      {
        print('Error on signin $err');
      }
    );
  }

//---------------------------Funções---------------------------------
  handleSignIn(GoogleSignInAccount account)async
  {
    if(account != null)
    {
      await createUserInFirestore();
      setState(() 
      {
        isAuth = true;
      });
      configurePushNotification();
    }
    else
    {
      setState(() 
      {
        isAuth = false;
      });
    }
  }

  configurePushNotification()
  {
    final GoogleSignInAccount user = googleSignIn.currentUser;
    if(Platform.isIOS) getIOSPermission();

    _firebaseMessaging.getToken().then((token)
    {
      print("Mensagem do token: $token\n");
      usersRef
        .document(user.id)
        .updateData({"androidNotificationToken": token});
    });

     _firebaseMessaging.configure(
      onLaunch: (Map<String, dynamic> message) async { print("OnLaunch"); },
      onResume: (Map<String, dynamic> message) async { print("OnResume"); },
      onMessage: (Map<String, dynamic> message) async {
        final String recipientId = message['data']['recipient'];
        final String body = message['notification']['body'];
        print("messaged !");
        if (recipientId == user.id) {
          SnackBar snackbar = SnackBar(
            content: Text(body, overflow: TextOverflow.ellipsis)
          );
          _scaffoldKey.currentState.showSnackBar(snackbar);
        }
      },
    );
  }

  getIOSPermission()
  {
    _firebaseMessaging.requestNotificationPermissions
    (IosNotificationSettings(alert: true, badge: true, sound: true));
      _firebaseMessaging.onIosSettingsRegistered.listen((settings)
      {
        print("Settings registered: $settings");
      });
  }

  createUserInFirestore() async
  {
    // verificar se o usuario existe no banco
    final GoogleSignInAccount user = googleSignIn.currentUser;
    DocumentSnapshot doc = await usersRef.document(user.id).get();

    // se o usuario não existir, criar uma conta para ele
    if(!doc.exists)
    {
      final username = await Navigator.push(context, MaterialPageRoute(builder: (context) => CreateAccount()));
    
    // buscar o nome do usuario e criar uma nova coleção para esse usuario
      usersRef.document(user.id).setData
      ({
        "id": user.id,
        "username": username,
        "photoUrl": user.photoUrl,
        "email": user.email,
        "displayName": user.displayName,
        "bio": "",
        "timestamp": timestamp,

      });
    // cria um usuario baseado em si para adicionar as proprias postagens na timeline
    await followersRef
      .document(user.id)
      .collection('userFollowers')
      .document(user.id)
      .setData({});

      doc = await usersRef.document(user.id).get();
    }

    currentUser = User.fromDocument(doc);

    print(currentUser);
    print(currentUser.username);
  }

  // Metodo que cuidará do controle de telas
  @override
  void dispose() 
  { 
    pageController.dispose();
    super.dispose();
  }

  //função que chama o login
  login()
  {
    googleSignIn.signIn();
  }
  //função para logout
  logout()
  {
    googleSignIn.signOut();
  }
  //Função que gerencia as paginas e a barra inferior
  onPageChanged(int pageIndex)
  {
    setState(() 
    {
      this.pageIndex = pageIndex;

    });
  }
  
  onTap(int pageIndex)
  {
    pageController.animateToPage
    (
      pageIndex,
      duration: Duration(milliseconds: 100),
      curve: Curves.easeInOut

    );
  }
  //função para criar a tela Home caso esteja logada
  Scaffold buildAuthScreen()
  {
    return Scaffold
    (
      key: _scaffoldKey,
      body: PageView
      (
        children: <Widget>
        [
          Timeline(currentUser: currentUser),
          ActivityFeed(),
          Upload(currentUser: currentUser),
          Search(),
          Profile(profileId: currentUser?.id),
        ],
        controller: pageController,
        onPageChanged: onPageChanged,
        physics: NeverScrollableScrollPhysics(),
      ),
      bottomNavigationBar: CupertinoTabBar
      (
        currentIndex: pageIndex,
        onTap: onTap,
        activeColor: Theme.of(context).accentColor,
        items: 
        [
          BottomNavigationBarItem(icon: Icon(Icons.home)),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_active)),
          BottomNavigationBarItem(icon: Icon(Icons.note_add, size: 35.0,)),
          BottomNavigationBarItem(icon: Icon(Icons.search)),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle)),
        ],
      ),
    );
  }

  //desenha a tela de login caso não esteja autenticado
  Scaffold buildUnauthScreen()
  {
    return Scaffold
    (
      body: Container
      (
        decoration: BoxDecoration
        (
          image: DecorationImage
          (
            image: AssetImage('assets/images/pattern_final-03.png'), 
            fit: BoxFit.cover
          ),

          gradient: LinearGradient
          (
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: 
            [
              Theme.of(context).accentColor.withOpacity(0.5),
              Theme.of(context).primaryColor.withOpacity(0.5),
            ],
          ),
        ),
        alignment: Alignment.center,
        child: Column
        (
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>
          [
            Text
            (
              "Ctrl+Play",
              style: TextStyle
              (
                shadows: 
                [
                  Shadow( // bottomLeft
                    offset: Offset(0.0, 0.0),
                    color: Colors.black
                  ),
                  Shadow( // bottomRight
                    offset: Offset(5.5, -1.5),
                    color: Colors.black
                  ),
                ],
                fontFamily: "Signatra",
                fontSize: 90.0,
                color: Colors.white,
              ),
            ),
            
            Container
            (
              height: 250.0,
              width: 250.0,
              decoration: BoxDecoration
              (
                image: DecorationImage
                (// vertical, move down 10
                  image: AssetImage('assets/images/logo_final-17.png'),
                  fit: BoxFit.cover 
                
                ),
              ),
            ),
            GestureDetector
            (
              onTap: login,
              child: Container
              (
                width: 260.0,
                height: 60.0,
                decoration: BoxDecoration
                (
                  image: DecorationImage
                  (
                    image: AssetImage('assets/images/google_signin_button.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

//---------------------------Aplicação em si---------------------------------
  @override
  Widget build(BuildContext context) 
  {
    return isAuth ? buildAuthScreen() : buildUnauthScreen();
  }
}
