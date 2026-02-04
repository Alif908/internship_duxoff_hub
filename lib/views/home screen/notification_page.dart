import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:internship_duxoff_hub/views/qkwashome.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<Map<String, String>> notificationList = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    getNotifications();
  }

  void getNotifications() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Set<String> allKeys = prefs.getKeys();

    List<Map<String, String>> tempList = [];

    for (String key in allKeys) {
      if (key.startsWith('notification_50_sent_')) {
        bool sent = prefs.getBool(key) ?? false;
        if (sent == true) {
          tempList.add({
            'id': key,
            'title': '🧺 Wash Halfway Done!',
            'message': 'Your wash cycle is 50% complete',
            'type': '50%'
          });
        }
      }

      if (key.startsWith('notification_85_sent_')) {
        bool sent = prefs.getBool(key) ?? false;
        if (sent == true) {
          tempList.add({
            'id': key,
            'title': '🧺 Almost Done!',
            'message': 'Your wash cycle is 85% complete',
            'type': '85%'
          });
        }
      }

      if (key.startsWith('notification_completion_sent_')) {
        bool sent = prefs.getBool(key) ?? false;
        if (sent == true) {
          tempList.add({
            'id': key,
            'title': '✅ Wash Complete!',
            'message': 'Please collect your laundry',
            'type': 'Complete'
          });
        }
      }
    }

    setState(() {
      notificationList = tempList;
      loading = false;
    });
  }

  void deleteOne(String id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(id);
    getNotifications();
  }

  void deleteAll() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    for (int i = 0; i < notificationList.length; i++) {
      String id = notificationList[i]['id']!;
      await prefs.remove(id);
    }

    getNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => QKWashHome()),
            );
          },
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          if (notificationList.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.black),
              onPressed: () {
                deleteAll();
              },
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : notificationList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off,
                          size: 80, color: Colors.grey),
                      const SizedBox(height: 20),
                      const Text(
                        'No Notifications',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: notificationList.length,
                  itemBuilder: (context, index) {
                    String id = notificationList[index]['id']!;
                    String title = notificationList[index]['title']!;
                    String message = notificationList[index]['message']!;
                    String type = notificationList[index]['type']!;

                    Color bgColor;
                    IconData icon;

                    if (type == '50%') {
                      bgColor = Colors.blue;
                      icon = Icons.hourglass_bottom;
                    } else if (type == '85%') {
                      bgColor = Colors.orange;
                      icon = Icons.hourglass_top;
                    } else {
                      bgColor = Colors.green;
                      icon = Icons.check_circle;
                    }

                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: bgColor,
                          child: Icon(icon, color: Colors.white),
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(message),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            deleteOne(id);
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
