class MatchModel {
  final String roomId;
  final String peerId;
  final String peerUsername;
  final String peerNativeLang;
  final String peerTargetLang;
  final bool isInitiator;

  MatchModel({
    required this.roomId,
    required this.peerId,
    required this.peerUsername,
    required this.peerNativeLang,
    required this.peerTargetLang,
    required this.isInitiator,
  });

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    return MatchModel(
      roomId: json['room_id'] ?? '',
      peerId: json['peer_id'] ?? '',
      peerUsername: json['peer_username'] ?? '',
      peerNativeLang: json['peer_native_lang'] ?? '',
      peerTargetLang: json['peer_target_lang'] ?? '',
      isInitiator: json['is_initiator'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'peer_id': peerId,
      'peer_username': peerUsername,
      'peer_native_lang': peerNativeLang,
      'peer_target_lang': peerTargetLang,
      'is_initiator': isInitiator,
    };
  }
}
