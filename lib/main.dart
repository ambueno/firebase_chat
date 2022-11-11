import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() async {
  await Firebase.initializeApp();
  runApp(MyApp());
}

final ThemeData kIOStheme = ThemeData(
  primarySwatch: Colors.blue,
  primaryColor: Colors.greenAccent[100],
);

final ThemeData kDefaultTheme = ThemeData(
  colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.lightBlue)
      .copyWith(secondary: Colors.orangeAccent[400]),
);

final googleSignIn = GoogleSignIn();
final auth = FirebaseAuth.instance;

Future<void> _ensureLoggedIn() async {
  GoogleSignInAccount? user = googleSignIn.currentUser;
  user ??= (await googleSignIn.signInSilently());
  // ignore: unnecessary_null_comparison
  user ??= (await googleSignIn.signIn());
  // ignore: unnecessary_null_comparison
  if (auth.currentUser == null) {
    GoogleSignInAuthentication? credentials =
        await googleSignIn.currentUser?.authentication;
    await auth.signInWithCredential(GoogleAuthProvider.credential(
        idToken: credentials?.idToken, accessToken: credentials?.accessToken));
  }
}

//final googleSignIn = GoogleSignIn();
//final auth = FirebaseAuth.instance;

/*Future<void> _ensureLoggedIn() async {
  // Trigger the Google Authentication flow.
  final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
  // Obtain the auth details from the request.
  final GoogleSignInAuthentication googleAuth = await googleUser!.authentication;
  // Create a new credential.
  final OAuthCredential googleCredential = GoogleAuthProvider.credential(
    accessToken: googleAuth.accessToken,
    idToken: googleAuth.idToken,
  );
  // Sign in to Firebase with the Google [UserCredential].
  final UserCredential googleUserCredential =
  await auth.signInWithCredential(googleCredential);
}*/

_handleSubmitted(String text) async {
  await _ensureLoggedIn();
  _sendMessage(text: text, imgUrl: '');
}

void _sendMessage({required String text, required String imgUrl}) {
  FirebaseFirestore.instance.collection("messages").add({
    "text": text,
    "imgUrl": imgUrl,
    "senderName": googleSignIn.currentUser?.displayName,
    "senderPhotoUrl": googleSignIn.currentUser?.photoUrl,
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Chat App",
      debugShowCheckedModeBanner: false,
      theme: Theme.of(context).platform == TargetPlatform.iOS
          ? kIOStheme
          : kDefaultTheme,
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      top: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Chat App"),
          centerTitle: true,
          elevation:
              Theme.of(context).platform == TargetPlatform.iOS ? 0.0 : 4.0,
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("messages")
                      .snapshots(),
                  builder: (context, snapshot) {
                    switch (snapshot.connectionState) {
                      case ConnectionState.none:
                      case ConnectionState.waiting:
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      default:
                        return ListView.builder(
                            reverse: true,
                            itemCount: snapshot.data?.docs.length,
                            itemBuilder: (context, index) {
                              List<QueryDocumentSnapshot<Object?>> r = snapshot.data?.docs.reversed.toList();
                              return ChatMessage(r[index].data);
                            });
                    }
                  }),
            ),
            const Divider(
              height: 1.0,
            ),
            Container(
              decoration: BoxDecoration(color: Theme.of(context).cardColor),
              child: TextComposer(),
            )
          ],
        ),
      ),
    );
  }
}

class TextComposer extends StatefulWidget {
  @override
  _TextComposerState createState() => _TextComposerState();
}

class _TextComposerState extends State<TextComposer> {
  bool _isComposing = false;
  final _textController = TextEditingController();

  void _reset() {
    _textController.clear();
    setState(() {
      _isComposing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: Theme.of(context).platform == TargetPlatform.iOS
            ? const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.lightBlue)))
            : null,
        child: Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.photo_camera),
              onPressed: () {},
            ),
            Expanded(
                child: TextField(
              controller: _textController,
              decoration: const InputDecoration.collapsed(
                  hintText: "Enviar uma mensagem"),
              onChanged: (text) {
                setState(() {
                  _isComposing = text.length > 0;
                });
              },
              onSubmitted: _handleSubmitted(_textController.text),
            )),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Theme.of(context).platform == TargetPlatform.iOS
                  ? CupertinoButton(
                      onPressed: _isComposing
                          ? () {
                              _handleSubmitted(_textController.text);
                              _reset();
                            }
                          : null,
                      child: const Text("Enviar"),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _isComposing
                          ? () {
                              _handleSubmitted(_textController.text);
                              _reset();
                            }
                          : null,
                    ),
            )
          ],
        ),
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final Map<String, dynamic> data;

  const ChatMessage(this.data, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundImage: NetworkImage(data["senderPhotoUrl"]),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  data["senderName"],
                  style: Theme.of(context).textTheme.subtitle1,
                ),
                Container(
                    margin: const EdgeInsets.only(top: 5.0),
                    child: data["imgUrl"] != null
                        ? Image.network(
                            data["imgUrl"],
                            width: 250.0,
                          )
                        : Text(data["text"]))
              ],
            ),
          )
        ],
      ),
    );
  }
}
