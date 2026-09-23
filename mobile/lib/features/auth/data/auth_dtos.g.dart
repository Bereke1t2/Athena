// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_dtos.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserDto _$UserDtoFromJson(Map<String, dynamic> json) => UserDto(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] as String,
    );

SessionResponseDto _$SessionResponseDtoFromJson(Map<String, dynamic> json) =>
    SessionResponseDto(
      token: json['token'] as String,
      expiresAt: json['expires_at'] as String,
      user: UserDto.fromJson(json['user'] as Map<String, dynamic>),
    );
