import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttershare/models/user.dart';
import 'package:fluttershare/pages/edit_profile.dart';
import 'package:fluttershare/pages/home.dart';
import 'package:fluttershare/widgets/header.dart';
import 'package:fluttershare/widgets/post.dart';
import 'package:fluttershare/widgets/post_tile.dart';
import 'package:fluttershare/widgets/progress.dart';



class Profile extends StatefulWidget 
{
  final String profileId;
  

  Profile({this.profileId});

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> 
{
  
  final String currentUserId = currentUser?.id;
  String postOrientation = "grid";
  bool isFollowing = false;
  bool isLoading = false;
  int postCount = 0;
  int followerCount = 0;
  int followingCount = 0;
  List<Post> post = [];

  @override
  void initState() 
  {
    super.initState();
    getProfilePost();
    getFollowers();
    getFollowing();
    checkIsFolowing();

    
  }

  checkIsFolowing() async
  {
    DocumentSnapshot doc = await followersRef
      .document(widget.profileId)
      .collection('userFollowers')
      .document(currentUserId)
      .get();
    
    setState(() 
    {
      isFollowing = doc.exists;
    });
  }

  getFollowers() async
  {
    QuerySnapshot snapshot =  await followersRef
      .document(widget.profileId)
      .collection('userFollowers')
      .getDocuments();
    
    setState(() 
    {
      followerCount = snapshot.documents.length;  
    });
  }

  getFollowing() async
  {
    QuerySnapshot snapshot = await followingRef
      .document(widget.profileId)
      .collection('userFollowing')
      .getDocuments();

    setState(() 
    {
      followingCount = snapshot.documents.length;  
    });
  }

  getProfilePost() async
  {
    setState(() 
    {
      isLoading = true;  
    });
    QuerySnapshot snapshot = await postRef.document(widget.profileId)
    .collection("userPosts")
    .orderBy("timestamp", descending: true)
    .getDocuments();

    setState(() 
    {
      isLoading = false;
      postCount = snapshot.documents.length;
      post = snapshot.documents.map((doc) => Post.fromDocument(doc)).toList();
    });
  }

  
  Column buildCountColumn(String label, int count)
  {
    return Column
    (
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>
      [
        Text
        (
          count.toString(),
          style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
        ),
        Container
        (
          margin: EdgeInsets.only(top: 4.0),
          child: Text
          (
            label,
            style: TextStyle
            (
              color: Colors.grey,
              fontSize: 15.0,
              fontWeight: FontWeight.w400
            ),
          ),
        ),
      ],
    );
  }

  editProfile()
  {
    Navigator.push(context, MaterialPageRoute(builder: (context) => 
    EditProfile(currentUserId: currentUserId)));
  }

  Container buildButton({ String text, Function function })
  {
    return Container
    (
      padding: EdgeInsets.only(top: 2.0),
      child: FlatButton
      (
        onPressed: function,
        child: Container
        (
          width: 200.0,
          height: 27.0,
          child: Text
          (
            text,
            style: TextStyle
            (
              color: isFollowing ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold
            ),
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration
          (
            color: isFollowing ? Colors.white : Colors.blue,
            border: Border.all(
              color: isFollowing ? Colors.grey : Colors.blue
            ),
            borderRadius: BorderRadius.circular(5.0),
          ),
        ),
      ),
    );
  }

  buildProfileButton()
  {
    // no proprio perfil, mostra o botão para editar o perfil
    bool isProfileOwner = currentUserId == widget.profileId;
    if(isProfileOwner)
    {
      return buildButton(
        text: "Editar perfil",
        function: editProfile,
      );
    }
    else if(isFollowing)
    {
      return buildButton(text: "Deixar de seguir", function: handleUnfollowUser);
    }
    else if(!isFollowing)
    {
      return buildButton(text: "Seguir", function: handleFollowUser);
    }
  }

  handleUnfollowUser()
  {
    setState(() 
    {
      isFollowing = false;
    });
    // remove o seguidor da lista de seguidores deste usuario
    followersRef
      .document(widget.profileId)
      .collection("userFollowers")
      .document(currentUserId)
      .get().then((doc)
      {
        if(doc.exists)
        {
          doc.reference.delete();
        }
      });
      // remove o usuario na sua lista de seguidores
    followingRef
      .document(currentUserId)
      .collection("userFollowing")
      .document(widget.profileId)
      .get().then((doc)
      {
        if(doc.exists)
        {
          doc.reference.delete();
        }
      });

      //deleta a notificação ao usuario seguido
    activityFeedRef
      .document(widget.profileId)
      .collection("feedItems")
      .document(currentUserId)
      .get().then((doc)
      {
        if(doc.exists)
        {
          doc.reference.delete();
        }
      });
  }

  handleFollowUser()
  {
    setState(() 
    {
      isFollowing = true;
    });
    //fazer o atual usuario começar a seguir o outro perfil e tornar ele um seguidor(atualizar a coleção de seguidores)
    followersRef
      .document(widget.profileId)
      .collection("userFollowers")
      .document(currentUserId)
      .setData({});
      // coloca o usuario na sua lista de seguidores
    followingRef
      .document(currentUserId)
      .collection("userFollowing")
      .document(widget.profileId)
      .setData({});

      //adiciona a notificação ao usuario seguido
    activityFeedRef
      .document(widget.profileId)
      .collection("feedItems")
      .document(currentUserId)
      .setData(
        {
          "type": "follow",
          "ownerId": widget.profileId,
          "username": currentUser.username,
          "userId": currentUserId,
          "userProfileImage": currentUser.photoUrl,
          "timestamp": timestamp,
        }
      );
  }

  buildProfileHeader()
  {
    return FutureBuilder
    (
      future: usersRef.document(widget.profileId).get(),
      builder: (context, snapshot)
      {
        if(!snapshot.hasData)
        {
          return circularProgress();
        }
        User user = User.fromDocument(snapshot.data);

        return Padding
        (
          padding: EdgeInsets.all(16.0),
          child: Column
          (
            children: <Widget>
            [
              Row
              (
                children: <Widget>
                [
                  CircleAvatar
                  (
                    radius: 40.0,
                    backgroundColor: Colors.grey,
                    backgroundImage: CachedNetworkImageProvider(user.photoUrl)
                  ),
                  Expanded
                  (
                    flex: 1,
                    child: Column
                    (
                      children: <Widget>
                      [
                        Row
                        (
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>
                          [
                            buildCountColumn("Post", postCount),
                            buildCountColumn("Seguidores", followerCount),
                            buildCountColumn("Seguindo", followingCount),
                          ],
                        ),
                        Row
                        (
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>
                          [
                            buildProfileButton(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Container
              (
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.only(top: 12.0),
                child: Text
                (
                  user.username,
                  style: TextStyle
                  (fontWeight: FontWeight.bold, fontSize: 16.0),
                ),
              ),
              Container
              (
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.only(top: 4.0),
                child: Text
                (
                  user.displayName,
                  style: TextStyle
                  (fontWeight: FontWeight.bold),
                ),
              ),
              Container
              (
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.only(top: 2.0),
                child: Text
                (
                  user.bio,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  buildProfilePost()
  {
    if(isLoading)
    {
      return circularProgress();
    }
    else if(postOrientation == "grid")
    {
      List<GridTile> gridTiles = [];
      post.forEach((post) 
      {
        gridTiles.add(GridTile(child: PostTile(post)));
      });
      return GridView.count(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        mainAxisSpacing: 1.5,
        crossAxisSpacing: 1.5,
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        children: gridTiles,
      );
    }
    else if(postOrientation == "list")
    {
      return Column(children: post);
    }
  }

      setPostOrientation(String postOrientation)
    {
      setState(() 
      {
        this.postOrientation = postOrientation;
      });
    }

  buildTogglePostOrientation()
  {
    return Row
    (
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>
      [
        IconButton
        (
          onPressed: () => setPostOrientation("grid"),
          icon: Icon(Icons.grid_on),
          color: postOrientation == "grid" ? Theme.of(context).primaryColor : Colors.grey,
          

        ),
        IconButton
        (
          icon: Icon(Icons.list),
          color: postOrientation == "list" ? Theme.of(context).primaryColor : Colors.grey,

          onPressed: () => setPostOrientation("list"),
          
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) 
  {
    return Scaffold
    (
      appBar: header(context, titleText:"Profile" ),
      body: ListView
      (
        children: <Widget>
        [
          buildProfileHeader(),
          Divider(),
          buildTogglePostOrientation(),
          Divider(height: 0.0),
          buildProfilePost(),

        ],
      ),

    );
  }
}
