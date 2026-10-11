import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'names_list.dart';

class CardData {
  final String sessionId;
  final String sessionKey;
  final String codapp;
  final String cardId;
  final String cardSecret;
  final int cardInterval;

  CardData({
    required this.sessionId,
    required this.sessionKey,
    required this.codapp,
    required this.cardId,
    required this.cardSecret,
    required this.cardInterval,
  });

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'sessionKEY': sessionKey,
      'codapp': codapp,
      'cardid': cardId,
      'cardsecret': cardSecret,
      'cardinterval': cardInterval,
    };
  }

  factory CardData.fromJson(Map<String, dynamic> json) {
    return CardData(
      sessionId: json['sessionId'],
      sessionKey: json['sessionKEY'],
      codapp: json['codapp'],
      cardId: json['cardid'],
      cardSecret: json['cardsecret'],
      cardInterval: json['cardinterval'],
    );
  }
}

class UserData {
  final String id;
  final String name;
  final String lastName;
  final CardData cardData;

  UserData({
    required this.id,
    required this.name,
    required this.lastName,
    required this.cardData,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lastName': lastName,
      'cardData': cardData.toJson(),
    };
  }

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'],
      name: json['name'],
      lastName: json['lastName'],
      cardData: CardData.fromJson(json['cardData']),
    );
  }

  static UserData? fromOfficialJson(Map<String, dynamic> json) {
    var cardDataStr = json['jwt'].split(".");
    if (cardDataStr.length != 3) {
      return null;
    }
    var cardData = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(cardDataStr[1]))),
    );

    return UserData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['first_name'],
      lastName: json['last_name'],
      cardData: CardData.fromJson(cardData['public']),
    );
  }
}

// Gestione profili
class ProfileManager {
  static const String _profilesListKey = 'profiles-list';
  static const String _currentProfileKey = 'current-profile-id';
  static const String _userDataPrefix = 'user-data-';

  static Future<List<String>> getProfileIds() async {
    final prefs = await SharedPreferences.getInstance();
    final idsJson = prefs.getString(_profilesListKey);
    if (idsJson == null) return [];
    return List<String>.from(jsonDecode(idsJson) as List);
  }

  static Future<void> saveProfileIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profilesListKey, jsonEncode(ids));
  }

  static Future<String?> getCurrentProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentProfileKey);
  }

  static Future<void> setCurrentProfileId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentProfileKey, id);
  }

  static Future<UserData?> getProfile(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('$_userDataPrefix$id');
    if (userData == null) return null;
    return UserData.fromJson(jsonDecode(userData));
  }

  static Future<UserData?> getCurrentProfile() async {
    final currentId = await getCurrentProfileId();
    if (currentId == null) return null;
    return getProfile(currentId);
  }

  static Future<void> addProfile(UserData userData) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = await getProfileIds();
    ids.add(userData.id);
    
    await saveProfileIds(ids);
    await prefs.setString('$_userDataPrefix${userData.id}', jsonEncode(userData.toJson()));
    await setCurrentProfileId(userData.id);
  }

  static Future<void> deleteProfile(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = await getProfileIds();
    ids.remove(id);
    
    await saveProfileIds(ids);
    await prefs.remove('$_userDataPrefix$id');
    
    if (await getCurrentProfileId() == id) {
      if (ids.isNotEmpty) {
        await setCurrentProfileId(ids.first);
      } else {
        await prefs.remove(_currentProfileKey);
      }
    }
  }

  static Future<List<UserData>> getAllProfiles() async {
    final ids = await getProfileIds();
    final profiles = <UserData>[];
    for (final id in ids) {
      final profile = await getProfile(id);
      if (profile != null) {
        profiles.add(profile);
      }
    }
    return profiles;
  }
}

Future<UserData?> getUserData(String qrContent, MobileScannerController? controller) async {
  if (controller != null) {
    await controller.stop();
  }

  final data = jsonDecode(qrContent);
  final callbackUrl = data['url'];
  final key = data['key'];

  var res = await http.post(
    Uri.parse(callbackUrl),
    headers: {'authorization': 'Bearer cbf23b95-e56d-4494-830e-f4b8594a3704', 'content-type': 'application/json'},
    body: jsonEncode({
      'KEY': key,
      'DEVICE_UID': 'N/A',
      'DEVICE_NAME': 'Samsung Galaxy Sirda di ${names[Random().nextInt(names.length)]}',
      'DEVICE_OS': "Android",
      'DEVICE_VERSION': '35',
      'APP_NAME': 'DiSCo MensaApp',
      'APP_VER': '2.5.11',
    }),
  );

  if (res.statusCode != 200) {
    throw Exception('Failed to post data: ${res.statusCode} ${res.body}');
  }

  var respData = jsonDecode(res.body);

  if (respData['status'] != 'OK') {
    throw Exception('Failed to post data: ${respData['error']}');
  }

  var rawCardData = respData['data'];

  return UserData.fromOfficialJson(rawCardData);
}
