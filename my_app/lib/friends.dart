import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class Friend {
  final int id;
  final String username;
  final String friendCode;
  final String mood; // optional from API later
  final int streak; // optional from API later
  final List<String> sharedHabits;

  Friend({
    required this.id,
    required this.username,
    required this.friendCode,
    this.mood = "🙂",
    this.streak = 0,
    this.sharedHabits = const [],
  });

  factory Friend.fromJson(Map<String, dynamic> j) => Friend(
        id: (j['id'] as num).toInt(),
        username: j['username'] as String,
        friendCode: (j['friend_code'] ?? '') as String,
      );

  Friend copyWith({List<String>? sharedHabits, String? mood, int? streak}) =>
      Friend(
        id: id,
        username: username,
        friendCode: friendCode,
        mood: mood ?? this.mood,
        streak: streak ?? this.streak,
        sharedHabits: sharedHabits ?? this.sharedHabits,
      );
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const String baseUrl = 'http://10.0.2.2:3000';

  List<Friend> _friends = [];
  int get friendsCount => _friends.length;
  List<Friend> _requests = [];
  String myFriendCode = '';

  final _friendCodeCtrl = TextEditingController();
  final _encourageCtrl = TextEditingController();

  // (Optional) keep your leaderboard mock for now
  final leaderboard = const [
    {"rank": 1, "name": "Emma Wilson", "points": 2840, "streak": 31},
    {"rank": 2, "name": "Alex Rodriguez", "points": 2650, "streak": 22},
    {"rank": 3, "name": "You", "points": 2420, "streak": 18},
    {"rank": 4, "name": "Sarah Chen", "points": 2180, "streak": 15},
    {"rank": 5, "name": "Jordan Kim", "points": 1950, "streak": 8},
  ];

  Future<String> _jwt() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('jwt_token') ?? '';
  }

  Future<void> _loadFriendCode() async {
    try {
      final token = await _jwt();
      final r = await http.get(
        Uri.parse('$baseUrl/me/friend_code'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      if (r.statusCode == 200) {
        setState(() {
          myFriendCode = (json.decode(r.body)['friendCode'] ?? '') as String;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadFriends() async {
    try {
      final token = await _jwt();
      final r = await http.get(
        Uri.parse('$baseUrl/friends'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      if (r.statusCode == 200) {
        final list = (json.decode(r.body) as List)
            .map((j) => Friend.fromJson(j as Map<String, dynamic>))
            .toList();

        // Optionally fetch shared habits for each friend
        for (int i = 0; i < list.length; i++) {
          final sh = await _fetchSharedHabits(list[i].id);
          list[i] = list[i].copyWith(sharedHabits: sh);
        }
        setState(() => _friends = list);
      }
    } catch (_) {}
  }

  Future<void> _loadRequests() async {
    try {
      final token = await _jwt();
      final r = await http.get(
        Uri.parse('$baseUrl/friends/requests'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      if (r.statusCode == 200) {
        final list = (json.decode(r.body) as List)
            .map((j) => Friend.fromJson(j as Map<String, dynamic>))
            .toList();
        setState(() => _requests = list);
      }
    } catch (_) {}
  }

  Future<List<String>> _fetchSharedHabits(int friendId) async {
    try {
      final token = await _jwt();
      final r = await http.get(
        Uri.parse('$baseUrl/friends/$friendId/shared_habits'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (r.statusCode == 200) {
        return List<String>.from(json.decode(r.body) as List);
      }
    } catch (_) {}
    return const [];
  }

  Future<void> _searchAndSendRequest() async {
    final code = _friendCodeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;

    try {
      final token = await _jwt();
      final search = await http.post(
        Uri.parse('$baseUrl/friends/search'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'code': code}),
      );

      if (search.statusCode != 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Not found: ${search.body}')),
        );
        return;
      }

      final user =
          Friend.fromJson(json.decode(search.body) as Map<String, dynamic>);

      final req = await http.post(
        Uri.parse('$baseUrl/friends/request'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'friendId': user.id}),
      );

      if (!mounted) return;
      if (req.statusCode == 200) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request sent to ${user.username}')),
        );
        _friendCodeCtrl.clear();
        await _loadRequests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${req.body}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _accept(int friendId) async {
    try {
      final token = await _jwt();
      final r = await http.post(
        Uri.parse('$baseUrl/friends/accept'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'friendId': friendId}),
      );
      if (r.statusCode == 200) {
        await _loadFriends();
        await _loadRequests();
      }
    } catch (_) {}
  }

  Future<void> _decline(int friendId) async {
    try {
      final token = await _jwt();
      final r = await http.post(
        Uri.parse('$baseUrl/friends/decline'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'friendId': friendId}),
      );
      if (r.statusCode == 200) {
        await _loadRequests();
      }
    } catch (_) {}
  }

  Future<void> _encourage(int friendId, String username) async {
    try {
      final token = await _jwt();
      final msg = _encourageCtrl.text.trim().isEmpty
          ? null
          : _encourageCtrl.text.trim();
      await http.post(
        Uri.parse('$baseUrl/friends/encourage'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body:
            json.encode({'friendId': friendId, 'emoji': '👏', 'message': msg}),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$username is proud of you! 👏')),
      );
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFriendCode();
    _loadFriends();
    _loadRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _friendCodeCtrl.dispose();
    _encourageCtrl.dispose();
    super.dispose();
  }

  void _showAddFriendDialog() {
    _friendCodeCtrl.clear();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Friend by Code"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (myFriendCode.isNotEmpty)
              Text("Your code: $myFriendCode",
                  style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: _friendCodeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: "Friend Code",
                hintText: "e.g. 7GQ2XF",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: _searchAndSendRequest,
              child: const Text("Send Request")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Friends & Community"),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showAddFriendDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "Friends (${_friends.length})"),
            Tab(text: "Requests (${_requests.length})"),
            const Tab(text: "Leaderboard"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RefreshIndicator(
              onRefresh: () async => _loadFriends(), child: _buildFriendsTab()),
          RefreshIndicator(
              onRefresh: () async => _loadRequests(),
              child: _buildRequestsTab()),
          _buildLeaderboardTab(),
        ],
      ),
    );
  }

  Widget _buildFriendsTab() {
    if (_friends.isEmpty) {
      return const Center(
          child: Text("No friends yet. Add one with the + button."));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _friends.map((f) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(f.username,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Text("online · just now",
                          style: TextStyle(color: Colors.grey)),
                    ])),
                Column(children: [
                  Text(f.mood, style: const TextStyle(fontSize: 22)),
                  Row(children: const [
                    Icon(Icons.local_fire_department,
                        size: 16, color: Colors.orange),
                  ]),
                  Text("${f.streak}"),
                ]),
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.pink.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('"Keep going — you’ve got this! 💪"',
                    style: TextStyle(fontStyle: FontStyle.italic)),
              ),
              const SizedBox(height: 8),
              const Text("Shared Habits",
                  style: TextStyle(fontWeight: FontWeight.w500)),
              Wrap(
                spacing: 6,
                children: (f.sharedHabits.isEmpty
                    ? [const Chip(label: Text("—"))]
                    : f.sharedHabits.map((h) => Chip(label: Text(h))).toList()),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: OutlinedButton(
                        onPressed: () {/* TODO: open chat screen */},
                        child: const Text("Message"))),
                const SizedBox(width: 8),
                Expanded(
                    child: OutlinedButton(
                  onPressed: () {
                    _encourageCtrl.clear();
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text("Encourage ${f.username}"),
                        content: TextField(
                          controller: _encourageCtrl,
                          decoration: const InputDecoration(
                              hintText: 'Optional message'),
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Cancel")),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _encourage(f.id, f.username);
                            },
                            child: const Text("Send 👏"),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text("Encourage"),
                )),
              ]),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRequestsTab() {
    if (_requests.isEmpty) {
      return const Center(child: Text("No pending friend requests"));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _requests
          .map((u) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading:
                      CircleAvatar(child: Text(u.username[0].toUpperCase())),
                  title: Text(u.username),
                  subtitle: Text("Friend code: ${u.friendCode}"),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    OutlinedButton(
                        onPressed: () => _decline(u.id),
                        child: const Text("Decline")),
                    const SizedBox(width: 8),
                    ElevatedButton(
                        onPressed: () => _accept(u.id),
                        child: const Text("Accept")),
                  ]),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildLeaderboardTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: leaderboard.map((user) {
        final isYou = user["name"] == "You";
        final bgColor = isYou ? Colors.blue.shade50 : Colors.grey.shade200;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: isYou ? Border.all(color: Colors.blue.shade200) : null,
          ),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              CircleAvatar(child: Text('${user["rank"]}')),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user["name"] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Row(children: [
                  const Icon(Icons.local_fire_department,
                      size: 16, color: Colors.orange),
                  Text("${user["streak"]} day streak"),
                ]),
              ]),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text("${user["points"]}",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Text("points", style: TextStyle(color: Colors.grey)),
            ]),
          ]),
        );
      }).toList(),
    );
  }
}
