const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// // Create and Deploy Your First Cloud Functions
// // https://firebase.google.com/docs/functions/write-firebase-functions
//
// exports.helloWorld = functions.https.onRequest((request, response) => {
//  response.send("Hello from Firebase!");
// });

exports.onCreateFollower = functions.firestore
    .document("/followers/{userId}/userFollowers/{followerId}")
    .onCreate(async(snapshot, context) =>
    {
        console.log("follower created", snapshot.id);
        const userId = context.params.userId;
        const followerId = context.params.followerId;

    // 1) buscar os posts do usuario seguido(cria a referencia)

        const followerUserPostsRef = admin
            .firestore()
            .collection('posts')
            .doc(userId)
            .collection('userPosts');
    // 2) obter a timeline do usuario seguido(cria a referencia)

        const timelinePostsRef = admin
            .firestore()
            .collection('timeline')
            .doc(followerId)
            .collection('timelinePosts');
    // 3) Busca os posts dos seguidos para a timeline

        const querySnapshot = await followerUserPostsRef.get();
    // 4) adiciona cada post a linha do tempo dos seguidores

        querySnapshot.forEach(doc =>
            {
                if(doc.exists)
                {
                    const postId = doc.id;
                    const postData = doc.data();
                    timelinePostsRef.doc(postId).set(postData);
                }
            });
    });

exports.onDeleteFollowers = functions.firestore
    .document("/followers/{userId}/userFollowers/{followerId}")
    .onDelete(async(snapshot, context) =>
    {
        console.log("Follower deleted", snapshot.id);
        const userId = context.params.userId;
        const followerId = context.params.followerId;

        const timelinePostsRef = admin
            .firestore()
            .collection('timeline')
            .doc(followerId)
            .collection('timelinePosts')
            .where("ownerId","==", userId);

        const querySnapshot = await timelinePostsRef.get();
        querySnapshot.forEach(doc =>
            {
                if(doc.exists)
                {
                    doc.ref.delete();
                }
            })
    });

// adiciona novas postagens a linha do tempo dos seguidores

exports.onCreatePost = functions.firestore
    .document('/posts/{userId}/userPosts/{postId}')
    .onCreate(async(snapshot, context) =>
    {
        const postCreated = snapshot.data();
        const userId = context.params.userId;
        const postId = context.params.postId;

    // 1) busca todos os usuarios que seguem o dono d post
        const userFollowersRef = admin.firestore()
            .collection('followers')
            .doc(userId)
            .collection('userFollowers');

        const querySnapshot = await userFollowersRef.get();
    // 2) adiciona cada post a linha do tempo de cada seguidor
    
        querySnapshot.forEach(doc =>
            {
                const followerId = doc.id;

                admin
                    .firestore()
                    .collection('timeline')
                    .doc(followerId)
                    .collection('timelinePosts')
                    .doc(postId)
                    .set(postCreated);
            });
    });

exports.onUpdatePost = functions.firestore
    .document('/posts/{userId}/userPosts/{postId}')
    .onUpdate(async(change, context) =>
    {
        const postUpdated = change.after.data();
        const userId = context.params.userId;
        const postId = context.params.postId;

    // 1) busca todos os usuarios que seguem o dono d post
        const userFollowersRef = admin.firestore()
            .collection('followers')
            .doc(userId)
            .collection('userFollowers');

        const querySnapshot = await userFollowersRef.get();
    
    // 2) atualiza cada post a linha do tempo de cada seguidor
    
    querySnapshot.forEach(doc =>
        {
            const followerId = doc.id;

            admin
                .firestore()
                .collection('timeline')
                .doc(followerId)
                .collection('timelinePosts')
                .doc(postId)
                .get().then(doc =>
                    {
                        if(doc.exists)
                        {
                            doc.ref.update(postUpdated);
                        }
                    });
        });
    });

exports.onDeletePost = functions.firestore
    .document('/posts/{userId}/userPosts/{postId}')
    .onDelete(async(snapshot, context) =>
    {
        const userId = context.params.userId;
        const postId = context.params.postId;

    // 1) busca todos os usuarios que seguem o dono d post
        const userFollowersRef = admin.firestore()
            .collection('followers')
            .doc(userId)
            .collection('userFollowers');

        const querySnapshot = await userFollowersRef.get();
    
    // 2) deleta cada post a linha do tempo de cada seguidor
    
    querySnapshot.forEach(doc =>
        {
            const followerId = doc.id;

            admin
                .firestore()
                .collection('timeline')
                .doc(followerId)
                .collection('timelinePosts')
                .doc(postId)
                .get().then(doc =>
                    {
                        if(doc.exists)
                        {
                            doc.ref.delete();
                        }
                    });
        });
    });

exports.onCreateActivityFeedItem = functions.firestore
    .document('/feed/{userId}/feedItems/{activityFeedItem}')
    .onCreate(async(snapshot, context) =>
    {
        console.log('Atividade criada ', snapshot.data());
    // 1) Busca o usuário conectado ao feed
        const userId = context.params.userId;

        const userRef = admin.firestore().doc(`user/${userId}`);
        const doc = await userRef.get();
    // 2) Verifica se há usuario e se ha tokem para notificação e envia a notificação
        const androidNotificationToken = doc.data().androidNotificationToken;
        const createdActivityFeedItem = snapshot.data();

        if(androidNotificationToken)
        {
            //envia a notificação
            sendNotification(androidNotificationToken, createdActivityFeedItem);
        }
        else
        {
            console.log("sem tokem, notificação impossivel");
        }

        function sendNotification(androidNotificationToken, activityFeedItem)
        {
            let body;

        // 3) alterna o body de acordo com o tipo de notificação
            switch (activityFeedItem.type) {
                case "comment":
                    body = `${activityFeedItem.username} Comentou: ${activityFeedItem.commentData}`
                    
                    break;
                case "like":
                    body = `${activityFeedItem.username} Curtiu isso!`
                
                    break;
                case "follow":
                    body = `${activityFeedItem.username} Começou a te seguir!`
                
                    break;
            
                default:
                    break;
            }

            const message = {
                notification: { body },
                token: androidNotificationToken,
                data: { recipient: userId}
            };

        // 5) enviar a mensagem com admin.messaging()

            return admin
                .messaging()
                .send(message)
                .then( response => 
                    {
                        // resposta é uma mensagem em string com o id
                        console.log("Mensagem enviada com sucesso", response);
                    })
                .catch(error => 
                    {
                        console.log("Erro ao enviar uma mensagem", error);
                    });

        }
    });