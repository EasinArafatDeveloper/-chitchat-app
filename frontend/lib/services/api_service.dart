import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config.dart';

class ApiService {
  static const String _baseUrl = AppConfig.baseUrl;

  // Headers helper
  static Map<String, String> _getHeaders({String? token}) {
    final headers = {
      'Content-Type': 'application/json; charset=UTF-8',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // Register
  static Future<http.Response> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$_baseUrl/api/auth/register');
    final body = jsonEncode({
      'name': name,
      'email': email,
      'password': password,
    });
    return await http.post(url, headers: _getHeaders(), body: body);
  }

  // Login
  static Future<http.Response> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$_baseUrl/api/auth/login');
    final body = jsonEncode({
      'email': email,
      'password': password,
    });
    return await http.post(url, headers: _getHeaders(), body: body);
  }

  // Get current user details
  static Future<http.Response> getMe(String token) async {
    final url = Uri.parse('$_baseUrl/api/auth/me');
    return await http.get(url, headers: _getHeaders(token: token));
  }

  // Search users
  static Future<http.Response> searchUsers({
    required String query,
    required String token,
  }) async {
    final url = Uri.parse('$_baseUrl/api/auth/search?query=$query');
    return await http.get(url, headers: _getHeaders(token: token));
  }

  // Upload Profile Avatar
  static Future<http.StreamedResponse> uploadAvatar({
    required File imageFile,
    required String token,
  }) async {
    final url = Uri.parse('$_baseUrl/api/auth/upload-avatar');
    final request = http.MultipartRequest('POST', url);
    
    // Set headers
    request.headers['Authorization'] = 'Bearer $token';
    
    // Add file
    final mimeType = imageFile.path.endsWith('.png') ? 'image/png' : 'image/jpeg';
    request.files.add(
      await http.MultipartFile.fromPath(
        'avatar',
        imageFile.path,
        contentType: MediaType.parse(mimeType),
      ),
    );

    return await request.send();
  }

  // Upload Message Media (Image/Audio)
  static Future<http.StreamedResponse> uploadMediaFile({
    required File file,
    required String token,
  }) async {
    final url = Uri.parse('$_baseUrl/api/messages/upload-media');
    final request = http.MultipartRequest('POST', url);
    
    // Set headers
    request.headers['Authorization'] = 'Bearer $token';
    
    // Determine content-type based on extension
    String mimeType = 'application/octet-stream';
    final pathStr = file.path.toLowerCase();
    if (pathStr.endsWith('.png')) {
      mimeType = 'image/png';
    } else if (pathStr.endsWith('.jpg') || pathStr.endsWith('.jpeg')) {
      mimeType = 'image/jpeg';
    } else if (pathStr.endsWith('.gif')) {
      mimeType = 'image/gif';
    } else if (pathStr.endsWith('.mp3')) {
      mimeType = 'audio/mpeg';
    } else if (pathStr.endsWith('.m4a')) {
      mimeType = 'audio/mp4';
    } else if (pathStr.endsWith('.wav')) {
      mimeType = 'audio/wav';
    } else if (pathStr.endsWith('.ogg')) {
      mimeType = 'audio/ogg';
    }
    
    request.files.add(
      await http.MultipartFile.fromPath(
        'media',
        file.path,
        contentType: MediaType.parse(mimeType),
      ),
    );

    return await request.send();
  }

  // Get conversation list
  static Future<http.Response> getConversations(String token) async {
    final url = Uri.parse('$_baseUrl/api/messages/conversations/list');
    return await http.get(url, headers: _getHeaders(token: token));
  }

  // Get messages with a specific user
  static Future<http.Response> getMessages({
    required String userId,
    required String token,
  }) async {
    final url = Uri.parse('$_baseUrl/api/messages/$userId');
    return await http.get(url, headers: _getHeaders(token: token));
  }
}
