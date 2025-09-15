import 'package:flutter/material.dart';

/// Model untuk User/Account yang sedang login
class User {
  final String id;
  final String username;
  final String email;
  final String name;
  final String? avatar;
  final String? phone;
  final String? role;
  final DateTime? lastLogin;
  final DateTime? createdAt;
  final bool isActive;
  final bool isOnline;
  final Map<String, dynamic>? permissions;
  final Map<String, dynamic>? settings;
  final List<int> channels;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.name,
    this.avatar,
    this.phone,
    this.role,
    this.lastLogin,
    this.createdAt,
    this.isActive = true,
    this.isOnline = false,
    this.permissions,
    this.settings,
    this.channels = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? 
          json['userId']?.toString() ?? 
          json['Id']?.toString() ?? 
          json['UserId']?.toString() ?? '',
      username: json['username']?.toString() ?? 
                json['Username']?.toString() ?? 
                json['UserName']?.toString() ?? '',
      email: json['email']?.toString() ?? 
             json['Email']?.toString() ?? '',
      name: json['name']?.toString() ?? 
            json['displayName']?.toString() ?? 
            json['DisplayName']?.toString() ?? 
            json['fullName']?.toString() ?? 
            json['FullName']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? 
              json['Avatar']?.toString() ?? 
              json['userImage']?.toString() ?? 
              json['UserImage']?.toString(),
      phone: json['phone']?.toString() ?? 
             json['Phone']?.toString() ?? 
             json['phoneNumber']?.toString() ?? 
             json['PhoneNumber']?.toString(),
      role: json['role']?.toString() ?? 
            json['Role']?.toString() ?? 
            json['userRole']?.toString() ?? 
            json['UserRole']?.toString(),
      lastLogin: json['lastLogin'] != null 
        ? DateTime.tryParse(json['lastLogin'].toString()) ?? 
          DateTime.tryParse(json['LastLogin']?.toString() ?? '')
        : null,
      createdAt: json['createdAt'] != null 
        ? DateTime.tryParse(json['createdAt'].toString()) ?? 
          DateTime.tryParse(json['CreatedAt']?.toString() ?? '')
        : null,
      isActive: json['isActive'] == true || 
                json['IsActive'] == true || 
                json['active'] == true || 
                json['Active'] == true,
      isOnline: json['isOnline'] == true || 
                json['IsOnline'] == true || 
                json['online'] == true || 
                json['Online'] == true,
      permissions: json['permissions'] as Map<String, dynamic>? ?? 
                   json['Permissions'] as Map<String, dynamic>?,
      settings: json['settings'] as Map<String, dynamic>? ?? 
                json['Settings'] as Map<String, dynamic>?,
      channels: (json['channels'] as List<dynamic>?)?.map((e) => int.tryParse(e.toString()) ?? 0).toList() ?? 
                (json['Channels'] as List<dynamic>?)?.map((e) => int.tryParse(e.toString()) ?? 0).toList() ?? 
                [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'name': name,
      'avatar': avatar,
      'phone': phone,
      'role': role,
      'lastLogin': lastLogin?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'isActive': isActive,
      'isOnline': isOnline,
      'permissions': permissions,
      'settings': settings,
      'channels': channels,
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? name,
    String? avatar,
    String? phone,
    String? role,
    DateTime? lastLogin,
    DateTime? createdAt,
    bool? isActive,
    bool? isOnline,
    Map<String, dynamic>? permissions,
    Map<String, dynamic>? settings,
    List<int>? channels,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      lastLogin: lastLogin ?? this.lastLogin,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      isOnline: isOnline ?? this.isOnline,
      permissions: permissions ?? this.permissions,
      settings: settings ?? this.settings,
      channels: channels ?? this.channels,
    );
  }

  // Utility getters
  String get displayName => name.isNotEmpty ? name : username;
  
  String get initials {
    if (name.isNotEmpty) {
      final parts = name.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        return name.substring(0, 1).toUpperCase();
      }
    } else if (username.isNotEmpty) {
      return username.substring(0, 1).toUpperCase();
    }
    return 'U';
  }

  bool get hasAvatar => avatar != null && avatar!.isNotEmpty;
  
  bool get hasPermission => permissions != null && permissions!.isNotEmpty;
  
  bool get isAdmin => role?.toLowerCase() == 'admin' || role?.toLowerCase() == 'administrator';
  
  bool get isModerator => role?.toLowerCase() == 'moderator' || role?.toLowerCase() == 'mod';
  
  bool get isAgent => role?.toLowerCase() == 'agent' || role?.toLowerCase() == 'support';

  String get statusText {
    if (!isActive) return 'Inactive';
    if (isOnline) return 'Online';
    if (lastLogin != null) {
      final now = DateTime.now();
      final diff = now.difference(lastLogin!);
      if (diff.inMinutes < 5) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return 'Last seen ${lastLogin!.day}/${lastLogin!.month}';
    }
    return 'Offline';
  }

  Color get statusColor {
    if (!isActive) return Colors.grey;
    if (isOnline) return Colors.green;
    return Colors.orange;
  }

  @override
  String toString() {
    return 'User{id: $id, username: $username, name: $name, email: $email, role: $role, isActive: $isActive, isOnline: $isOnline}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Model untuk User Profile yang lebih detail
class UserProfile extends User {
  final String? bio;
  final String? department;
  final String? position;
  final String? location;
  final String? timezone;
  final String? language;
  final DateTime? birthday;
  final Map<String, String>? socialLinks;
  final List<String> skills;
  final Map<String, dynamic>? preferences;

  UserProfile({
    required String id,
    required String username,
    required String email,
    required String name,
    String? avatar,
    String? phone,
    String? role,
    DateTime? lastLogin,
    DateTime? createdAt,
    bool isActive = true,
    bool isOnline = false,
    Map<String, dynamic>? permissions,
    Map<String, dynamic>? settings,
    List<int> channels = const [],
    this.bio,
    this.department,
    this.position,
    this.location,
    this.timezone,
    this.language,
    this.birthday,
    this.socialLinks,
    this.skills = const [],
    this.preferences,
  }) : super(
          id: id,
          username: username,
          email: email,
          name: name,
          avatar: avatar,
          phone: phone,
          role: role,
          lastLogin: lastLogin,
          createdAt: createdAt,
          isActive: isActive,
          isOnline: isOnline,
          permissions: permissions,
          settings: settings,
          channels: channels,
        );

  factory UserProfile.fromUser(User user, {
    String? bio,
    String? department,
    String? position,
    String? location,
    String? timezone,
    String? language,
    DateTime? birthday,
    Map<String, String>? socialLinks,
    List<String> skills = const [],
    Map<String, dynamic>? preferences,
  }) {
    return UserProfile(
      id: user.id,
      username: user.username,
      email: user.email,
      name: user.name,
      avatar: user.avatar,
      phone: user.phone,
      role: user.role,
      lastLogin: user.lastLogin,
      createdAt: user.createdAt,
      isActive: user.isActive,
      isOnline: user.isOnline,
      permissions: user.permissions,
      settings: user.settings,
      channels: user.channels,
      bio: bio,
      department: department,
      position: position,
      location: location,
      timezone: timezone,
      language: language,
      birthday: birthday,
      socialLinks: socialLinks,
      skills: skills,
      preferences: preferences,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final user = User.fromJson(json);
    return UserProfile(
      id: user.id,
      username: user.username,
      email: user.email,
      name: user.name,
      avatar: user.avatar,
      phone: user.phone,
      role: user.role,
      lastLogin: user.lastLogin,
      createdAt: user.createdAt,
      isActive: user.isActive,
      isOnline: user.isOnline,
      permissions: user.permissions,
      settings: user.settings,
      channels: user.channels,
      bio: json['bio']?.toString() ?? json['Bio']?.toString(),
      department: json['department']?.toString() ?? json['Department']?.toString(),
      position: json['position']?.toString() ?? json['Position']?.toString(),
      location: json['location']?.toString() ?? json['Location']?.toString(),
      timezone: json['timezone']?.toString() ?? json['Timezone']?.toString(),
      language: json['language']?.toString() ?? json['Language']?.toString(),
      birthday: json['birthday'] != null 
        ? DateTime.tryParse(json['birthday'].toString()) ?? 
          DateTime.tryParse(json['Birthday']?.toString() ?? '')
        : null,
      socialLinks: (json['socialLinks'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())) ?? 
                   (json['SocialLinks'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())),
      skills: (json['skills'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? 
              (json['Skills'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? 
              [],
      preferences: json['preferences'] as Map<String, dynamic>? ?? 
                   json['Preferences'] as Map<String, dynamic>?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'bio': bio,
      'department': department,
      'position': position,
      'location': location,
      'timezone': timezone,
      'language': language,
      'birthday': birthday?.toIso8601String(),
      'socialLinks': socialLinks,
      'skills': skills,
      'preferences': preferences,
    });
    return json;
  }

  @override
  UserProfile copyWith({
    String? id,
    String? username,
    String? email,
    String? name,
    String? avatar,
    String? phone,
    String? role,
    DateTime? lastLogin,
    DateTime? createdAt,
    bool? isActive,
    bool? isOnline,
    Map<String, dynamic>? permissions,
    Map<String, dynamic>? settings,
    List<int>? channels,
    String? bio,
    String? department,
    String? position,
    String? location,
    String? timezone,
    String? language,
    DateTime? birthday,
    Map<String, String>? socialLinks,
    List<String>? skills,
    Map<String, dynamic>? preferences,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      lastLogin: lastLogin ?? this.lastLogin,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      isOnline: isOnline ?? this.isOnline,
      permissions: permissions ?? this.permissions,
      settings: settings ?? this.settings,
      channels: channels ?? this.channels,
      bio: bio ?? this.bio,
      department: department ?? this.department,
      position: position ?? this.position,
      location: location ?? this.location,
      timezone: timezone ?? this.timezone,
      language: language ?? this.language,
      birthday: birthday ?? this.birthday,
      socialLinks: socialLinks ?? this.socialLinks,
      skills: skills ?? this.skills,
      preferences: preferences ?? this.preferences,
    );
  }

  // Additional getters for UserProfile
  String get jobTitle {
    if (position != null && department != null) {
      return '$position at $department';
    } else if (position != null) {
      return position!;
    } else if (department != null) {
      return department!;
    }
    return role ?? 'User';
  }

  int get age {
    if (birthday == null) return 0;
    final now = DateTime.now();
    int age = now.year - birthday!.year;
    if (now.month < birthday!.month || 
        (now.month == birthday!.month && now.day < birthday!.day)) {
      age--;
    }
    return age;
  }

  bool get hasBio => bio != null && bio!.isNotEmpty;
  bool get hasLocation => location != null && location!.isNotEmpty;
  bool get hasSocialLinks => socialLinks != null && socialLinks!.isNotEmpty;
  bool get hasSkills => skills.isNotEmpty;

  @override
  String toString() {
    return 'UserProfile{id: $id, username: $username, name: $name, department: $department, position: $position}';
  }
}

/// Model untuk User Session
class UserSession {
  final User user;
  final String token;
  final DateTime loginTime;
  final DateTime? expiryTime;
  final String? deviceId;
  final String? deviceName;
  final String? ipAddress;
  final Map<String, dynamic>? sessionData;

  UserSession({
    required this.user,
    required this.token,
    required this.loginTime,
    this.expiryTime,
    this.deviceId,
    this.deviceName,
    this.ipAddress,
    this.sessionData,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      user: User.fromJson(json['user'] ?? json['User'] ?? {}),
      token: json['token']?.toString() ?? json['Token']?.toString() ?? '',
      loginTime: json['loginTime'] != null 
        ? DateTime.parse(json['loginTime'].toString())
        : DateTime.now(),
      expiryTime: json['expiryTime'] != null 
        ? DateTime.parse(json['expiryTime'].toString())
        : null,
      deviceId: json['deviceId']?.toString() ?? json['DeviceId']?.toString(),
      deviceName: json['deviceName']?.toString() ?? json['DeviceName']?.toString(),
      ipAddress: json['ipAddress']?.toString() ?? json['IpAddress']?.toString(),
      sessionData: json['sessionData'] as Map<String, dynamic>? ?? 
                   json['SessionData'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'token': token,
      'loginTime': loginTime.toIso8601String(),
      'expiryTime': expiryTime?.toIso8601String(),
      'deviceId': deviceId,
      'deviceName': deviceName,
      'ipAddress': ipAddress,
      'sessionData': sessionData,
    };
  }

  bool get isExpired {
    if (expiryTime == null) return false;
    return DateTime.now().isAfter(expiryTime!);
  }

  bool get isValid => token.isNotEmpty && !isExpired;

  Duration get sessionDuration => DateTime.now().difference(loginTime);

  String get sessionDurationText {
    final duration = sessionDuration;
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  @override
  String toString() {
    return 'UserSession{user: ${user.username}, token: ${token.substring(0, 10)}..., loginTime: $loginTime, isValid: $isValid}';
  }
}

/// Enum untuk User Status
enum UserStatus {
  online,
  away,
  busy,
  offline;

  String get displayName {
    switch (this) {
      case UserStatus.online: return 'Online';
      case UserStatus.away: return 'Away';
      case UserStatus.busy: return 'Busy';
      case UserStatus.offline: return 'Offline';
    }
  }

  Color get color {
    switch (this) {
      case UserStatus.online: return Colors.green;
      case UserStatus.away: return Colors.orange;
      case UserStatus.busy: return Colors.red;
      case UserStatus.offline: return Colors.grey;
    }
  }

  IconData get icon {
    switch (this) {
      case UserStatus.online: return Icons.circle;
      case UserStatus.away: return Icons.access_time;
      case UserStatus.busy: return Icons.do_not_disturb;
      case UserStatus.offline: return Icons.circle_outlined;
    }
  }
}

/// Extension untuk backward compatibility
extension UserExtensions on User {
  UserStatus get status {
    if (!isActive) return UserStatus.offline;
    if (isOnline) return UserStatus.online;
    if (lastLogin != null) {
      final diff = DateTime.now().difference(lastLogin!);
      if (diff.inMinutes < 5) return UserStatus.online;
      if (diff.inHours < 1) return UserStatus.away;
    }
    return UserStatus.offline;
  }
}