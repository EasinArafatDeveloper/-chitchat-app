import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../config.dart';
import 'chat_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isLoading = false;

  void _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      final response = await ApiService.searchUsers(
        query: query.trim(),
        token: authProvider.token!,
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _searchResults = jsonDecode(response.body);
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Search users error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildAvatar(String? path, String name) {
    if (path == null || path.isEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: const Color(0xFF6C63FF).withOpacity(0.2),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Color(0xFF8B80F9),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final imageUrl = path.startsWith('http') ? path : '${AppConfig.baseUrl}$path';

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        placeholder: (context, url) => CircleAvatar(
          radius: 22,
          backgroundColor: Colors.grey[900],
          child: const SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF6C63FF)),
          ),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: 22,
          backgroundColor: Colors.grey[800],
          child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF15102A),
        elevation: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search by name or email...',
            hintStyle: TextStyle(color: Colors.white38),
            border: InputBorder.none,
          ),
          onChanged: _performSearch,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.white),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchResults = [];
                });
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
            )
          : _searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 80, color: Colors.white.withOpacity(0.1)),
                      const SizedBox(height: 16),
                      Text(
                        _searchController.text.isEmpty
                            ? 'Search for users to start chatting'
                            : 'No users found matching query',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    final userId = user['_id']?.toString() ?? '';
                    final userName = user['name'] ?? '';
                    final userEmail = user['email'] ?? '';
                    final isOnline = user['isOnline'] as bool? ?? false;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.01),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.02)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: Stack(
                          children: [
                            _buildAvatar(user['profilePic'], userName),
                            if (isOnline)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent[400],
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF0F0C20), width: 1.5),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          userName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          userEmail,
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF6C63FF)),
                        onTap: () {
                          // Close search screen and open chat screen
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                userId: userId,
                                userName: userName,
                                userProfilePic: user['profilePic'],
                                isOnline: isOnline,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
