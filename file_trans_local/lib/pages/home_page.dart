import 'package:flutter/material.dart';
import 'sender_page.dart';
import 'receiver_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late PageController _pageController;
  late AnimationController _animationController;

  final List<Widget> _pages = [
    const SenderPage(),
    const ReceiverPage(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          elevation: 0,
          height: 70,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.send_rounded),
              selectedIcon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              label: '发送文件',
            ),
            NavigationDestination(
              icon: const Icon(Icons.download_rounded),
              selectedIcon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.download_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              label: '接收文件',
            ),
          ],
        ),
      ),
    );
  }
}

