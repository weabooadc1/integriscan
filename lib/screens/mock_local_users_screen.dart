import 'package:flutter/material.dart';
import 'package:integriscan/database/database_helper.dart';

class MockLocalUsersScreen extends StatefulWidget {
  const MockLocalUsersScreen({super.key});

  @override
  State<MockLocalUsersScreen> createState() => _MockLocalUsersScreenState();
}

class _MockLocalUsersScreenState extends State<MockLocalUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    final users = await DatabaseHelper().getUsers();
    setState(() {
      _users = users;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Local Users (SQLite)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('No users found in local database.'))
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text('${user['firstName']} ${user['lastName']}'),
                      subtitle: Text(user['email'] ?? ''),
                    );
                  },
                ),
    );
  }
}
