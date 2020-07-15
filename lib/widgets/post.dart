import 'dart:async';
import 'package:animator/animator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttershare/models/user.dart';
import 'package:fluttershare/pages/comments.dart';
import 'package:fluttershare/pages/home.dart';
import 'package:fluttershare/pages/activity_feed.dart';
import 'package:fluttershare/widgets/custom_image.dart';
import 'package:fluttershare/widgets/progress.dart';

class Post extends StatefulWidget 
{
  final String postId;
  final String ownerId;
  final String username;
  final String location;
  final String description;
  final String mediaUrl;
  final dynamic likes;

  Post(
  {
    this.postId,
    this.ownerId,
    this.username,
    this.location,
    this.description,
    this.mediaUrl,
    this.likes,
  });

  factory Post.fromDocument(DocumentSnapshot doc)
  {
    return Post
    (
      postId: doc['postId'],
      ownerId: doc['ownerId'],
      username: doc['username'],
      location: doc['location'],
      description: doc['description'],
      mediaUrl: doc['mediaUrl'],
      likes: doc['likes'],
    );
  }
  int getLikeCount(likes)
  {
    // se não houver like retorna 0
    if(likes == null)
    {
      return 0;
    }
    int count = 0;
    // se apertou o botão, da like
    likes.values.forEach((val)
    {
      if(val == true)
      {
        count +=1;
      }
    });
    return count;
  }  

  @override
  _PostState createState() => _PostState(
    postId: this.postId,
    ownerId: this.ownerId,
    username: this.username,
    location: this.location,
    description: this.description,
    mediaUrl: this.mediaUrl,
    likes: this.likes,
    likeCount: getLikeCount(this.likes),
  );
}

class _PostState extends State<Post> 
{
  final String currentUserId = currentUser?.id;
  final String postId;
  final String ownerId;
  final String username;
  final String location;
  final String description;
  final String mediaUrl;
  int likeCount;
  Map likes;
  bool isLiked;
  bool showHeart = false;

  _PostState(
  {
    this.postId,
    this.ownerId,
    this.username,
    this.location,
    this.description,
    this.mediaUrl,
    this.likes,
    this.likeCount,
  });

  buildPostHeader()
  {
    return FutureBuilder
    (
      future: usersRef.document(ownerId).get(),
      builder: (context, snapshot) 
      {
        if(!snapshot.hasData)
        {
          return circularProgress();
        }
        User user = User.fromDocument(snapshot.data);
        bool isPostOwner = currentUserId == ownerId;

        return ListTile
        (
          leading: CircleAvatar
          (
            backgroundImage: CachedNetworkImageProvider(user.photoUrl),
            backgroundColor: Colors.grey,
          ),
          title: GestureDetector
          (
            onTap: () => showProfile(context, profileId: user.id),
            child: Text
            (
              user.username,
              style: TextStyle
              (
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          subtitle: Text(location),
          trailing: isPostOwner ? IconButton
          (
            onPressed: () => handleDeletPost(context),
            icon: Icon(Icons.more_vert),
          ) : Text(''),
        );
      },
    );
  }

  handleDeletPost(BuildContext parentContext)
  {
    return showDialog(
      context: parentContext,
      builder: (context)
      {
        return SimpleDialog
        (
          title: Text("Remover este post?"),
          children: <Widget>
          [
            SimpleDialogOption
            (
              onPressed: () 
              {
                Navigator.pop(context);
                deletPost();
              },
              child: Text("Deletar", style: TextStyle(color: Colors.red)),
            ),
            SimpleDialogOption
            (
              onPressed: () => Navigator.pop(context),
              child: Text("Cancelar", style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      }
    );
  }

  // para deletar o post, o usuario tem que ter o mesmo id do dono do post
  deletPost() async
  {
    //deletar o post
    postRef
      .document(ownerId)
      .collection('userPosts')
      .document(postId)
      .get().then((doc) 
      {
        if(doc.exists)
        {
          doc.reference.delete();
        }
      });
    // deletar a imagem postada

    storageRef.child('post_$postId.jpg').delete();
    // deletar todas as notificações

    QuerySnapshot activityFeedSnapshot = await activityFeedRef
      .document(ownerId)
      .collection("feedItems")
      .where("postId", isEqualTo: postId)
      .getDocuments();

      activityFeedSnapshot.documents.forEach((doc) 
      { 
        if(doc.exists)
        {
          doc.reference.delete();
        }
      });
    // deletar todos os comentarios

    QuerySnapshot commentSnapshot = await commentsRef
      .document(postId)
      .collection('comments')
      .getDocuments();

    commentSnapshot.documents.forEach((doc) 
    { 
      if(doc.exists)
      {
        doc.reference.delete();
      }
    });

  }

  handleLikePost()
  {
    bool _isLiked = likes[currentUserId] == true; 

    if(_isLiked)
    {
      postRef
        .document(ownerId)
        .collection('userPosts')
        .document(postId)
        .updateData({'likes.$currentUserId': false});
      setState(() 
      {
        likeCount -= 1;  
        isLiked = false;
        likes[currentUserId] = false;
      });

      removeLikeFromActiveFeed();
    }
    else if(!_isLiked)
    {
      postRef
        .document(ownerId)
        .collection('userPosts')
        .document(postId)
        .updateData({'likes.$currentUserId': true});
      
      addLikeToActiveFeed();
      setState(() 
      {
        likeCount += 1;  
        isLiked = true;
        likes[currentUserId] = true;
        showHeart = true;
      });
      Timer(Duration(milliseconds: 500), ()
      {
        setState(() 
        {
          showHeart = false;  
        });
      });
    }
  }

  addLikeToActiveFeed()
  {
    bool isNotPostOwner = currentUserId != ownerId;
    if(isNotPostOwner)
    {
      activityFeedRef
      .document(ownerId)
      .collection("feedItems")
      .document(postId)
      .setData(
        {
          "type": "like",
          "username": currentUser.username,
          "userId": currentUser.id,
          "userProfileImage": currentUser.photoUrl,
          "postId": postId,
          "mediaUrl": mediaUrl,
          "timestamp": timestamp
        });
    }
  }
  removeLikeFromActiveFeed()
  {
    bool isNotPostOwner = currentUserId != ownerId;
    if(isNotPostOwner)
    {
      activityFeedRef
      .document(ownerId)
      .collection("feedItems")
      .document(postId)
      .get().then((doc)
      {
        if(doc.exists)
        {
          doc.reference.delete();
        }
      });
    }

  }

  buildPostImage()
  {
    return GestureDetector
    (
      onDoubleTap: handleLikePost,
      child: Stack
      (
        alignment: Alignment.center,
        children: <Widget>
        [
          cachedNetworkImage(mediaUrl),
          showHeart 
          ? Animator
          (
            duration: Duration(milliseconds: 300),
            tween: Tween(begin: 0.8, end: 1.4),
            curve: Curves.elasticInOut,
            cycles: 0,
            builder: (anim) => Transform.scale(
              scale: anim.value,
              child: Icon
              (
                Icons.favorite, size: 160.0, color: Colors.white.withOpacity(0.4)
              ),
            ),
          )
          : Text(""),
        ],
      ),
    );

  }

  buildPostFooter()
  {
    return Column
    (
      children: <Widget>
      [
        Row
        (
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>
          [
            Padding(padding: EdgeInsets.only(top: 40.0, left: 20.0)),
            GestureDetector
            (
              onTap: handleLikePost,
              child: Icon
              (
                isLiked ? Icons.favorite : Icons.favorite_border,
                size: 28.0,
                color: Colors.pink,
              ),
            ),
            Padding(padding: EdgeInsets.only(right: 20.0)),
            GestureDetector
            (
              onTap: () => showComments(
                context,
                postId: postId,
                ownerId: ownerId,
                mediaUrl: mediaUrl
              ),
              child: Icon
              (
                Icons.chat,
                size: 28.0,
                color: Colors.blue[900],
              ),
            ),
          ],
        ),
        Row
        (
          children: <Widget>
          [
            Container
            (
              margin: EdgeInsets.only(left: 20.0),
              child: Text
              (
                "$likeCount Curtidas",
                style: TextStyle
                (
                  color: Colors.black,
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
          ],
        ),
        Row
        (
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>
          [
            Container
            (
              margin: EdgeInsets.only(left: 20.0),
              child: Text
              (
                "$username - ",
                style: TextStyle
                (
                  color: Colors.black,
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
            Expanded
            (
              child: Text(description),
            ),
          ],
        ),
      ],
    );

  }

  @override
  Widget build(BuildContext context) 
  {
    isLiked = (likes[currentUserId] == true);
    return Column
    (
      mainAxisSize: MainAxisSize.min,
      children: <Widget>
      [
        buildPostHeader(),
        buildPostImage(),
        buildPostFooter()
      ],
    );
  }
}

showComments(BuildContext context, { String postId, String ownerId, String mediaUrl})
{
  Navigator.push(context, MaterialPageRoute(builder: (context)
  {
    return Comments(
      postId: postId,
      postOwnerId: ownerId,
      postMediaUrl: mediaUrl,
    );
  }));
}
