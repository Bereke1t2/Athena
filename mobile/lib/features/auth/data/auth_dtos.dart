import 'package:json_annotation/json_annotation.dart';

import '../domain/auth_models.dart';

part 'auth_dtos.g.dart';

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class UserDto {
  const UserDto({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String createdAt;

  factory UserDto.fromJson(Map<String, dynamic> json) => _$UserDtoFromJson(json);

  UserProfile toDomain() {
    return UserProfile(
      id: id,
      email: email,
      displayName: displayName.isNotEmpty ? displayName : email.split('@').first,
      avatarUrl: avatarUrl,
      createdAt: DateTime.tryParse(createdAt) ?? DateTime.now(),
    );
  }
}

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class SessionResponseDto {
  const SessionResponseDto({
    required this.token,
    required this.expiresAt,
    required this.user,
  });

  final String token;
  final String expiresAt;
  final UserDto user;

  factory SessionResponseDto.fromJson(Map<String, dynamic> json) =>
      _$SessionResponseDtoFromJson(json);
}
