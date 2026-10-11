import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mensapp_v2/utils/cardutils.dart';
import 'package:mensapp_v2/utils/title_case.dart';
import 'package:otp/otp.dart';
import 'package:qr_flutter/qr_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _generatedTotp = "";
  String _user = "";
  UserData? _currentProfile;
  List<UserData> _allProfiles = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final profiles = await ProfileManager.getAllProfiles();
    final current = await ProfileManager.getCurrentProfile();
    
    if (mounted) {
      setState(() {
        _allProfiles = profiles;
        _currentProfile = current;
      });
      
      if (_currentProfile != null) {
        _startTotpGeneration();
      }
    }
  }

  void _startTotpGeneration() {
    if (_currentProfile == null) return;

    final userData = _currentProfile!;

    var generatedTotp = OTP.generateTOTPCodeString(
      userData.cardData.cardSecret,
      DateTime.now().millisecondsSinceEpoch +
          userData.cardData.cardInterval * 1000,
      interval: userData.cardData.cardInterval,
      algorithm: Algorithm.SHA256,
      length: 6,
      isGoogle: true,
    );

    _user = "${userData.name} ${userData.lastName}".toTitleCase();

    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        generatedTotp = OTP.generateTOTPCodeString(
          userData.cardData.cardSecret,
          DateTime.now().millisecondsSinceEpoch +
              userData.cardData.cardInterval * 1000,
          interval: userData.cardData.cardInterval,
          algorithm: Algorithm.SHA1,
          length: 6,
          isGoogle: false,
        );
        _generatedTotp = userData.cardData.cardId.replaceFirst(
          "0000000",
          generatedTotp,
        );
      });
    });
  }

  Future<void> _switchProfile(UserData profile) async {
    await ProfileManager.setCurrentProfileId(profile.id);
    setState(() {
      _currentProfile = profile;
    });
    _startTotpGeneration();
  }

  void _deleteProfile(UserData profile) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Profile"),
          content: Text("Are you sure you want to delete ${profile.name}'s profile?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                await ProfileManager.deleteProfile(profile.id);
                Navigator.pop(context);
                _loadProfiles();
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'Profili',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            ..._allProfiles.map((profile) {
              final isSelected = profile.id == _currentProfile?.id;
              return ListTile(
                leading: Icon(Icons.person, color: isSelected ? Colors.blue : null),
                title: Text("${profile.name} ${profile.lastName}"),
                selected: isSelected,
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    Navigator.pop(context);
                    _deleteProfile(profile);
                  },
                ),
                onTap: () {
                  _switchProfile(profile);
                  Navigator.pop(context);
                },
              );
            }).toList(),
            Divider(),
            ListTile(
              leading: Icon(Icons.add),
              title: const Text("Add Profile"),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, "/add_code");
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        padding: const EdgeInsets.all(0),
        color: Colors.white,
        height: 25,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey, width: 1)),
          ),
          child: Center(
            child: Text(
              "Buon pranzo!",
              style: TextStyle(color: Colors.black, fontSize: 12),
            ),
          ),
        ),
      ),
      appBar: AppBar(
        title: const Text(
          'Mensapp V2',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton(
            onSelected: (String value) async {
              if (value == "share") {
                Navigator.of(context).pushNamed("/share");
              } else if (value == "logout") {
                showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text("Logout"),
                      content: const Text("Are you sure you want to logout?"),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(false);
                          },
                          child: const Text("No"),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(true);
                          },
                          child: const Text(
                            "Yes",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    );
                  },
                ).then((value) {
                  if (value == true && context.mounted) {
                    ProfileManager.deleteProfile(_currentProfile!.id).then((_) {
                      Navigator.of(context).pushNamedAndRemoveUntil("/", (route) => false);
                    });
                  }
                });
              } else {
                Navigator.of(context).pushNamed("/info");
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(
                  value: "share",
                  child: const Text("Share"),
                ),
                PopupMenuItem(value: "info", child: const Text("Info")),
                PopupMenuItem<String>(
                  value: "logout",
                  child: const Text("Logout"),
                ),
              ];
            },
            iconColor: Colors.white,
          ),
        ],
        backgroundColor: Colors.blue,
      ),
      body: _currentProfile == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(_user),
                  SizedBox(height: 16),
                  QrImageView(data: _generatedTotp, size: 350),
                  SizedBox(height: 16),
                  SizedBox(
                    width: 350,
                    child: Text(
                      "Scannerizza questo QR code all'entrata della mensa e spera che il cibo sia commestibile :P",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
