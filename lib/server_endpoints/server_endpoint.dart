class ServerEndpoint {
  const ServerEndpoint({
    required this.id,
    required this.name,
    required this.url,
    this.checkWebSocketAccept = true,
    this.lastUsedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String url;
  final bool checkWebSocketAccept;
  final DateTime? lastUsedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  ServerEndpoint copyWith({
    String? id,
    String? name,
    String? url,
    bool? checkWebSocketAccept,
    DateTime? lastUsedAt,
    bool clearLastUsedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServerEndpoint(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      checkWebSocketAccept: checkWebSocketAccept ?? this.checkWebSocketAccept,
      lastUsedAt: clearLastUsedAt ? null : (lastUsedAt ?? this.lastUsedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'url': url,
      'checkWebSocketAccept': checkWebSocketAccept,
      'lastUsedAt': lastUsedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static ServerEndpoint fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().toUtc();
    final parsedCreatedAt =
        DateTime.tryParse('${json['createdAt'] ?? ''}')?.toUtc();
    final parsedUpdatedAt =
        DateTime.tryParse('${json['updatedAt'] ?? ''}')?.toUtc();
    final parsedLastUsedAt =
        DateTime.tryParse('${json['lastUsedAt'] ?? ''}')?.toUtc();

    return ServerEndpoint(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      url: '${json['url'] ?? ''}',
      checkWebSocketAccept:
          json['checkWebSocketAccept'] == false ? false : true,
      lastUsedAt: parsedLastUsedAt,
      createdAt: parsedCreatedAt ?? now,
      updatedAt: parsedUpdatedAt ?? now,
    );
  }
}
