import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _errorMessage;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _token != null;

  // Clear errors
  void clearErrors() {
    _errorMessage = null;
    notifyListeners();
  }

  // Auto Login
  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('chitchat_token')) {
      return false;
    }
    
    _token = prefs.getString('chitchat_token');
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.getMe(_token!);
      if (response.statusCode == 200) {
        _user = jsonDecode(response.body);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        // Token might be expired
        await logout();
        _isLoading = false;
        return false;
      }
    } catch (e) {
      print('Auto login error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Register
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.register(
        name: name,
        email: email,
        password: password,
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201) {
        _token = responseData['token'];
        _user = responseData['user'];
        
        // Save to cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('chitchat_token', _token!);

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = responseData['message'] ?? 'Registration failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Connection server error. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Login
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.login(
        email: email,
        password: password,
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _token = responseData['token'];
        _user = responseData['user'];
        
        // Save to cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('chitchat_token', _token!);

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = responseData['message'] ?? 'Authentication failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Connection server error. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Upload Profile Avatar
  Future<bool> uploadProfilePicture(File imageFile) async {
    if (_token == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final streamedResponse = await ApiService.uploadAvatar(
        imageFile: imageFile,
        token: _token!,
      );

      final response = await http.Response.fromStream(streamedResponse);
      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (_user != null) {
          _user!['profilePic'] = responseData['profilePic'];
        }
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = responseData['message'] ?? 'Avatar upload failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error uploading image file.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chitchat_token');
    notifyListeners();
  }
}
