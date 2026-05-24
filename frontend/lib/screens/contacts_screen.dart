import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../config.dart';
import 'chat_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _allUsers = [];
  List<dynamic> _filteredUsers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      // Fetch users with a blank/default query to list all contacts
      final response = await ApiService.searchUsers(
        query: '',
        token: authProvider.token!,
      );

      if (response.statusCode == 200 && mounted) {
        final List<dynamic> users = jsonDecode(response.body);
        // Exclude current user from contact lists
        final currentUserId = authProvider.user?['_id']?.toString() ?? authProvider.user?['id']?.toString() ?? '';
        final filteredList = users.where((u) => u['_id']?.toString() != currentUserId).toList();

        setState(() {
          _allUsers = filteredList;
          _filteredUsers = filteredList;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Load contacts error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _filteredUsers = _allUsers;
      });
      return;
    }

    setState(() {
      _filteredUsers = _allUsers.where((user) {
        final name = (user['name'] ?? '').toString().toLowerCase();
        final email = (user['email'] ?? '').toString().toLowerCase();
        final q = query.trim().toLowerCase();
        return name.contains(q) || email.contains(q);
      }).toList();
    });
  }

  Widget _buildAvatar(String? path, String name, {double radius = 24}) {
    if (path == null || path.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF00A86B).withOpacity(0.1),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: const Color(0xFF00A86B),
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.8,
          ),
        ),
      );
    }

    final imageUrl = path.startsWith('http') ? path : '${AppConfig.baseUrl}$path';

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey[100],
          child: const SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF00A86B)),
          ),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey[200],
          child: Text(name[0].toUpperCase(), style: const TextStyle(color: Color(0xFF1E293B))),
        ),
      ),
    );
  }

  Map<String, List<dynamic>> _groupContactsAlphabetically(List<dynamic> users) {
    final Map<String, List<dynamic>> grouped = {};
    for (var user in users) {
      final String name = user['name'] ?? '';
      if (name.isEmpty) continue;
      final String firstLetter = name[0].toUpperCase();
      if (!RegExp(r'[A-Z]').hasMatch(firstLetter)) {
        if (!grouped.containsKey('#')) {
          grouped['#'] = [];
        }
        grouped['#']!.add(user);
      } else {
        if (!grouped.containsKey(firstLetter)) {
          grouped[firstLetter] = [];
        }
        grouped[firstLetter]!.add(user);
      }
    }
    // Sort keys alphabetically
    final sortedKeys = grouped.keys.toList()..sort();
    final Map<String, List<dynamic>> sortedGrouped = {};
    for (var key in sortedKeys) {
      // Sort users inside the group by name
      grouped[key]!.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
      sortedGrouped[key] = grouped[key]!;
    }
    return sortedGrouped;
  }

  @override
  Widget build(BuildContext context) {
    final activeNowUsers = _allUsers.where((u) => u['isOnline'] as bool? ?? false).toList();
    final groupedContacts = _groupContactsAlphabetically(_filteredUsers);

    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'ConnectChat',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF1E293B)),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00A86B)))
          : RefreshIndicator(
              onRefresh: _loadContacts,
              color: const Color(0xFF00A86B),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          style: const TextStyle(color: Color(0xFF1E293B)),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                            hintText: 'Search friends, groups...',
                            hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 15),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),

                    // Active Now section
                    if (activeNowUsers.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(left: 20.0, top: 8.0, bottom: 12.0),
                        child: Text(
                          'Active Now',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Container(
                        height: 96,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: activeNowUsers.length,
                          itemBuilder: (context, index) {
                            final user = activeNowUsers[index];
                            final String name = user['name'] ?? '';
                            final String firstName = name.split(' ')[0];

                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      userId: user['_id']?.toString() ?? '',
                                      userName: name,
                                      userProfilePic: user['profilePic'],
                                      isOnline: true,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Column(
                                  children: [
                                    Stack(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFF00A86B),
                                              width: 2,
                                            ),
                                          ),
                                          child: _buildAvatar(user['profilePic'], name, radius: 24),
                                        ),
                                        Positioned(
                                          bottom: 2,
                                          right: 2,
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00A86B),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 2),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      firstName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    // Contacts List grouped alphabetically
                    if (_filteredUsers.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.0),
                          child: Text(
                            'No contacts found',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: groupedContacts.length,
                        itemBuilder: (context, index) {
                          final String letter = groupedContacts.keys.elementAt(index);
                          final List<dynamic> groupUsers = groupedContacts[letter]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                                child: Text(
                                  letter,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00A86B),
                                  ),
                                ),
                              ),
                              Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                color: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: groupUsers.length,
                                  separatorBuilder: (context, i) => const Divider(
                                    height: 1,
                                    indent: 72,
                                    color: Color(0xFFF1F5F9),
                                  ),
                                  itemBuilder: (context, i) {
                                    final user = groupUsers[i];
                                    final String name = user['name'] ?? '';
                                    final String email = user['email'] ?? '';
                                    final bool isOnline = user['isOnline'] as bool? ?? false;
                                    final String userId = user['_id']?.toString() ?? '';

                                    // Alternating action style just to match the visual mock (Add Friend vs Invite)
                                    final bool isEven = i % 2 == 0;

                                    return ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                      leading: Stack(
                                        children: [
                                          _buildAvatar(user['profilePic'], name, radius: 22),
                                          if (isOnline)
                                            Positioned(
                                              bottom: 0,
                                              right: 0,
                                              child: Container(
                                                width: 11,
                                                height: 11,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF00A86B),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: Colors.white, width: 1.5),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      title: Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E293B),
                                          fontSize: 15,
                                        ),
                                      ),
                                      subtitle: Text(
                                        email,
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 12,
                                        ),
                                      ),
                                      trailing: isEven
                                          ? TextButton(
                                              onPressed: () {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Sent friend request to $name')),
                                                );
                                              },
                                              style: TextButton.styleFrom(
                                                backgroundColor: const Color(0xFFF1F5F9),
                                                foregroundColor: const Color(0xFF00A86B),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                              ),
                                              child: const Text(
                                                'Add Friend',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                            )
                                          : ElevatedButton(
                                              onPressed: () {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Invited $name to group')),
                                                );
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF00A86B),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                                elevation: 0,
                                              ),
                                              child: const Text(
                                                'Invite',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                            ),
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => ChatScreen(
                                              userId: userId,
                                              userName: name,
                                              userProfilePic: user['profilePic'],
                                              isOnline: isOnline,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}
