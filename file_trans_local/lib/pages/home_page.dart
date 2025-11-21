import 'package:flutter/material.dart';
import 'sender_page.dart';
import 'receiver_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const SenderPage(),
    const ReceiverPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.send),
            selectedIcon: Icon(Icons.send),
            label: '发送文件',
          ),
          NavigationDestination(
            icon: Icon(Icons.download),
            selectedIcon: Icon(Icons.download),
            label: '接收文件',
          ),
        ],
      ),
    );
  }
}

