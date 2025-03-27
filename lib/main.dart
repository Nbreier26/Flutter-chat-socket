import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:web_socket_client/web_socket_client.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat App',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: const ContactsPage(),
    );
  }
}

/// Tela de contatos que permite gerar um ID aleatório e inserir o nickname
class ContactsPage extends StatefulWidget {
  const ContactsPage({Key? key}) : super(key: key);

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  String id = '';
  String nickname = '';
  final _nicknameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    generateRandomId();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  void generateRandomId() {
    final random = Random();
    final randomNumber = random.nextInt(900000) + 100000;
    setState(() {
      id = randomNumber.toString();
      _nicknameController.text = '';
    });
  }

  void openChatPage(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatPage(name: nickname, id: id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seu Chat:', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: generateRandomId,
            tooltip: 'Gerar novo ID',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 4,
                  color: Colors.deepPurple[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Seu ID',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.deepPurple,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          id,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: Colors.deepPurple[700],
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nicknameController,
                  decoration: InputDecoration(
                    labelText: 'Entre com Nickname',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, entre com um nickname';
                    }
                    if (value.length < 2) {
                      return 'Nickname deve ter mais de 2 caracteres';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {
                      nickname = value.trim();
                    });
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => openChatPage(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Iniciar Chat',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tela de chat que se conecta via WebSocket e utiliza a biblioteca flutter_chat_ui
/// Suporta envio de mensagens de texto e imagens.
class ChatPage extends StatefulWidget {
  const ChatPage({Key? key, required this.name, required this.id})
      : super(key: key);

  final String name;
  final String id;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // Substitua a URL abaixo pela do seu servidor WebSocket
  final socket = WebSocket(Uri.parse('ws://localhost:3000'));
  final List<types.Message> _messages = [];
  late types.User otherUser;
  late types.User me;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    me = types.User(
      id: widget.id,
      firstName: widget.name,
    );

    // Escuta as mensagens vindas do servidor WebSocket
    socket.messages.listen((incomingMessage) {
      // O servidor deve enviar um JSON contendo a chave "type": "text" ou "image"
      Map<String, dynamic> data = jsonDecode(incomingMessage);
      String id = data['id'];
      String msg = data['msg'];
      String nick = data['nick'] ?? id;
      String type = data['type'] ?? 'text';

      if (id != me.id) {
        otherUser = types.User(
          id: id,
          firstName: nick,
        );
        if (type == 'text') {
          onMessageReceived(msg);
        } else if (type == 'image') {
          onImageReceived(msg);
        }
      }
    }, onError: (error) {
      print("WebSocket error: $error");
    });
  }

  // Gera uma string aleatória para identificação única da mensagem
  String randomString() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(255));
    return base64UrlEncode(values);
  }

  // Trata mensagem de texto recebida
  void onMessageReceived(String message) {
    final newMessage = types.TextMessage(
      author: otherUser,
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: message,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      metadata: {
        'senderName': otherUser.firstName,
      },
    );
    _addMessage(newMessage);
  }

  // Trata mensagem de imagem recebida (base64)
  void onImageReceived(String base64Image) {
    final imageMessage = types.ImageMessage(
      author: otherUser,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'imagem_recebida.jpg',
      size: 0, // tamanho desconhecido
      uri: 'data:image/jpeg;base64,$base64Image',
      metadata: {
        'senderName': otherUser.firstName,
      },
    );
    _addMessage(imageMessage);
  }

  // Adiciona a mensagem à lista e atualiza a interface
  void _addMessage(types.Message message) {
    setState(() {
      _messages.insert(0, message);
    });
  }

  // Envia mensagem de texto
  void _sendMessageCommon(String text) {
    final textMessage = types.TextMessage(
      author: me,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: randomString(),
      text: text,
      metadata: {
        'senderName': me.firstName,
      },
    );

    final payload = {
      'id': me.id,
      'msg': text,
      'nick': me.firstName,
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': 'text',
    };

    socket.send(json.encode(payload));
    _addMessage(textMessage);
  }

  // Envia imagem selecionada pelo usuário
  Future<void> _sendImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await File(pickedFile.path).readAsBytes();
      final base64Image = base64Encode(bytes);

      final payload = {
        'id': me.id,
        'msg': base64Image,
        'nick': me.firstName,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        'type': 'image',
      };

      socket.send(json.encode(payload));

      final imageMessage = types.ImageMessage(
        author: me,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: randomString(),
        name: pickedFile.name,
        size: bytes.length,
        uri: 'data:image/jpeg;base64,$base64Image',
        metadata: {
          'senderName': me.firstName,
        },
      );
      _addMessage(imageMessage);
    }
  }

  // Callback acionado ao enviar mensagem na UI do chat
  void _handleSendPressed(types.PartialText message) {
    _sendMessageCommon(message.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Seu Chat: ${widget.name}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
      ),
      body: Chat(
        messages: _messages,
        user: me,
        showUserAvatars: true,
        showUserNames: true,
        onSendPressed: _handleSendPressed,
        imageMessageBuilder: (message, {required messageWidth}) {
          // Verifica se a uri é do tipo data: e extrai a parte base64
          if (message.uri.startsWith('data:')) {
            final base64Str = message.uri.split(',')[1];
            return Container(
              width: messageWidth.toDouble(),
              padding: const EdgeInsets.all(8),
              child: Image.memory(
                base64Decode(base64Str),
                fit: BoxFit.cover,
              ),
            );
          }
          // Caso contrário, carrega normalmente (por exemplo, via network)
          return Container(
            width: messageWidth.toDouble(),
            padding: const EdgeInsets.all(8),
            child: Image.network(
              message.uri,
              fit: BoxFit.cover,
            ),
          );
        },
      ),
      // Botão para enviar imagem
      floatingActionButton: FloatingActionButton(
        onPressed: _sendImage,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.image),
      ),
    );
  }

  @override
  void dispose() {
    socket.close();
    super.dispose();
  }
}
