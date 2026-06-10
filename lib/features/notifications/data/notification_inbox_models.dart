class NotificationInboxItem {
  final String notificationId;
  final String typeCode;
  final String title;
  final String description;
  final String targetPath;
  final DateTime? createdDate;
  final bool read;

  const NotificationInboxItem({
    required this.notificationId,
    required this.typeCode,
    required this.title,
    required this.description,
    required this.targetPath,
    required this.createdDate,
    required this.read,
  });

  factory NotificationInboxItem.fromJson(Map<String, dynamic> json) {
    return NotificationInboxItem(
      notificationId: json['notificationId']?.toString() ?? '',
      typeCode: json['typeCode']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Notificacion',
      description: json['description']?.toString() ?? '',
      targetPath: json['targetPath']?.toString() ?? '/dashboard',
      createdDate: DateTime.tryParse(json['createdDate']?.toString() ?? ''),
      read: json['read'] == true,
    );
  }
}

class NotificationPreferenceItem {
  final String typeCode;
  final String description;
  final bool bellEnabled;
  final bool webPushEnabled;
  final bool mobilePushEnabled;
  final bool emailEnabled;

  const NotificationPreferenceItem({
    required this.typeCode,
    required this.description,
    required this.bellEnabled,
    required this.webPushEnabled,
    required this.mobilePushEnabled,
    required this.emailEnabled,
  });

  factory NotificationPreferenceItem.fromJson(Map<String, dynamic> json) {
    return NotificationPreferenceItem(
      typeCode: json['typeCode']?.toString() ?? '',
      description: json['typeDescription']?.toString() ?? '',
      bellEnabled: json['bellEnabled'] == true,
      webPushEnabled: json['webPushEnabled'] == true,
      mobilePushEnabled: json['mobilePushEnabled'] == true,
      emailEnabled: json['emailEnabled'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'typeCode': typeCode,
        'bellEnabled': bellEnabled,
        'webPushEnabled': webPushEnabled,
        'mobilePushEnabled': mobilePushEnabled,
        'emailEnabled': emailEnabled,
      };

  NotificationPreferenceItem copyWith({
    bool? bellEnabled,
    bool? webPushEnabled,
    bool? mobilePushEnabled,
    bool? emailEnabled,
  }) {
    return NotificationPreferenceItem(
      typeCode: typeCode,
      description: description,
      bellEnabled: bellEnabled ?? this.bellEnabled,
      webPushEnabled: webPushEnabled ?? this.webPushEnabled,
      mobilePushEnabled: mobilePushEnabled ?? this.mobilePushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
    );
  }
}
