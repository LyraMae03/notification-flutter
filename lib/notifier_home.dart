import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotifierHome extends StatefulWidget {
  const NotifierHome({Key? key}) : super(key: key);

  @override
  State<NotifierHome> createState() => _NotifierHomeState();
}

class _NotifierHomeState extends State<NotifierHome> {
  late IO.Socket socket;
  bool isConnected = false;
  List<Map<String, dynamic>> notifications = [];

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final List<String> serverIPs = [
    'http://192.168.100.223:3000',
  ];

  @override
  void initState() {
    super.initState();
    initNotifications();
    connectToFirstAvailableSocket();
  }

  void connectToFirstAvailableSocket() async {
    for (String ip in serverIPs) {
      IO.Socket tempSocket = IO.io(ip, {
        'transports': ['websocket'],
        'autoConnect': false,
        'reconnection': false,
      });

      tempSocket.onConnect((_) {
        print('✅ Connected to server: $ip');
        setState(() {
          isConnected = true;
          socket = tempSocket;
        });
        setupSocketListeners();
        return;
      });

      tempSocket.onConnectError((err) {
        print('⚠️ Failed to connect to $ip: $err');
        tempSocket.dispose();
      });

      tempSocket.connect();
      await Future.delayed(const Duration(seconds: 2));
      if (isConnected) break;
    }

    if (!isConnected) {
      print('❌ Could not connect to any server.');
    }
  }

  void setupSocketListeners() {
    socket.onDisconnect((_) {
      print('❌ Disconnected from server');
      setState(() {
        isConnected = false;
      });
    });

    socket.on('db_change', (data) {
      print('📦 Database change detected: $data');
      setState(() {
        notifications.insert(0, {
          'event': data['event'],
          'payload': data['payload'],
          'time': DateTime.now().toString()
        });
      });
      showNotification(data['event'], data['payload']);
    });

    socket.onError((error) {
      print('🔴 Socket error: $error');
    });
  }

  Future<void> initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Notification clicked: ${response.payload}');
      },
    );
  }

  Future<void> showNotification(String eventType, dynamic payload) async {
    final int notificationId =
        DateTime.now().millisecondsSinceEpoch.remainder(100000);

    String title;
    String body;

    switch (eventType) {
      case 'added':
        title = 'Record Added';
        body = 'New record: ${payload['name']} (ID: ${payload['id']})';
        break;
      case 'updated':
        title = 'Record Updated';
        body = 'Updated record: ${payload['name']} (ID: ${payload['id']})';
        break;
      case 'deleted':
        title = 'Record Deleted';
        body = 'Deleted record with ID: ${payload['id']}';
        break;
      default:
        title = 'Database Changed';
        body = 'A database change occurred';
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'db_changes',
      'Database Changes',
      channelDescription: 'Notifications for database changes',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      body,
      platformDetails,
    );
  }

  @override
  void dispose() {
    if (isConnected) {
      socket.disconnect();
      socket.dispose();
    }
    super.dispose();
  }

  String _formatTime(DateTime time, {bool includeSeconds = false}) {
    String hour = time.hour.toString().padLeft(2, '0');
    String minute = time.minute.toString().padLeft(2, '0');
    if (includeSeconds) {
      String second = time.second.toString().padLeft(2, '0');
      return '$hour:$minute:$second';
    }
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(31, 0, 0, 0),
      appBar: AppBar(
        title: const Text('Database Change Notifier'),
        
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log Out',
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: isConnected ? Colors.green.shade100 : Colors.red.shade100,
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isConnected ? Icons.wifi : Icons.wifi_off,
                  color: isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  isConnected
                      ? 'Connected to server - Listening for changes'
                      : 'Disconnected from server',
                  style: TextStyle(
                    color: isConnected ? Colors.green.shade800 : Colors.red.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: notifications.isEmpty
                ? const Center(
                    child: Text(
                      'No notifications yet.\nWaiting for database changes...',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      final event = notification['event'];
                      final payload = notification['payload'];
                      final time = DateTime.parse(notification['time']);

                      IconData icon;
                      Color color;

                      switch (event) {
                        case 'added':
                          icon = Icons.add_circle;
                          color = Colors.green;
                          break;
                        case 'updated':
                          icon = Icons.edit;
                          color = Colors.orange;
                          break;
                        case 'deleted':
                          icon = Icons.delete;
                          color = Colors.red;
                          break;
                        default:
                          icon = Icons.notification_important;
                          color = Colors.blue;
                      }

                      return Card(
                        margin:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.2),
                            child: Icon(icon, color: color),
                          ),
                          title: Text(
                            event == 'deleted'
                                ? 'Record Deleted (ID: ${payload['id']})'
                                : '${payload['name']} (ID: ${payload['id']})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${event.toUpperCase()} • ${_formatTime(time)}',
                            style: TextStyle(color: color, fontSize: 12),
                          ),
                          trailing: Icon(Icons.chevron_right,
                              color: Colors.grey.shade400),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('${event.toUpperCase()} Event Details'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        'Time: ${_formatTime(time, includeSeconds: true)}'),
                                    const SizedBox(height: 8),
                                    Text('Event Type: ${event.toUpperCase()}'),
                                    const SizedBox(height: 8),
                                    Text('Payload:'),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(payload.toString()),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            notifications.clear();
          });
        },
        tooltip: 'Clear Notifications',
        child: const Icon(Icons.clear_all),
      ),
    );
  }
}
