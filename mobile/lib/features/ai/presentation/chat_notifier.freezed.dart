// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ChatThreadState {
  String? get sessionId => throw _privateConstructorUsedError;
  List<ChatMessage> get messages => throw _privateConstructorUsedError;

  /// Text currently streaming in (not yet finalized as a message).
  String get streaming => throw _privateConstructorUsedError;
  bool get sending => throw _privateConstructorUsedError;

  /// Create a copy of ChatThreadState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChatThreadStateCopyWith<ChatThreadState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatThreadStateCopyWith<$Res> {
  factory $ChatThreadStateCopyWith(
          ChatThreadState value, $Res Function(ChatThreadState) then) =
      _$ChatThreadStateCopyWithImpl<$Res, ChatThreadState>;
  @useResult
  $Res call(
      {String? sessionId,
      List<ChatMessage> messages,
      String streaming,
      bool sending});
}

/// @nodoc
class _$ChatThreadStateCopyWithImpl<$Res, $Val extends ChatThreadState>
    implements $ChatThreadStateCopyWith<$Res> {
  _$ChatThreadStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChatThreadState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = freezed,
    Object? messages = null,
    Object? streaming = null,
    Object? sending = null,
  }) {
    return _then(_value.copyWith(
      sessionId: freezed == sessionId
          ? _value.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String?,
      messages: null == messages
          ? _value.messages
          : messages // ignore: cast_nullable_to_non_nullable
              as List<ChatMessage>,
      streaming: null == streaming
          ? _value.streaming
          : streaming // ignore: cast_nullable_to_non_nullable
              as String,
      sending: null == sending
          ? _value.sending
          : sending // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChatThreadStateImplCopyWith<$Res>
    implements $ChatThreadStateCopyWith<$Res> {
  factory _$$ChatThreadStateImplCopyWith(_$ChatThreadStateImpl value,
          $Res Function(_$ChatThreadStateImpl) then) =
      __$$ChatThreadStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? sessionId,
      List<ChatMessage> messages,
      String streaming,
      bool sending});
}

/// @nodoc
class __$$ChatThreadStateImplCopyWithImpl<$Res>
    extends _$ChatThreadStateCopyWithImpl<$Res, _$ChatThreadStateImpl>
    implements _$$ChatThreadStateImplCopyWith<$Res> {
  __$$ChatThreadStateImplCopyWithImpl(
      _$ChatThreadStateImpl _value, $Res Function(_$ChatThreadStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatThreadState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = freezed,
    Object? messages = null,
    Object? streaming = null,
    Object? sending = null,
  }) {
    return _then(_$ChatThreadStateImpl(
      sessionId: freezed == sessionId
          ? _value.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String?,
      messages: null == messages
          ? _value._messages
          : messages // ignore: cast_nullable_to_non_nullable
              as List<ChatMessage>,
      streaming: null == streaming
          ? _value.streaming
          : streaming // ignore: cast_nullable_to_non_nullable
              as String,
      sending: null == sending
          ? _value.sending
          : sending // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$ChatThreadStateImpl implements _ChatThreadState {
  const _$ChatThreadStateImpl(
      {this.sessionId,
      final List<ChatMessage> messages = const <ChatMessage>[],
      this.streaming = '',
      this.sending = false})
      : _messages = messages;

  @override
  final String? sessionId;
  final List<ChatMessage> _messages;
  @override
  @JsonKey()
  List<ChatMessage> get messages {
    if (_messages is EqualUnmodifiableListView) return _messages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_messages);
  }

  /// Text currently streaming in (not yet finalized as a message).
  @override
  @JsonKey()
  final String streaming;
  @override
  @JsonKey()
  final bool sending;

  @override
  String toString() {
    return 'ChatThreadState(sessionId: $sessionId, messages: $messages, streaming: $streaming, sending: $sending)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatThreadStateImpl &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            const DeepCollectionEquality().equals(other._messages, _messages) &&
            (identical(other.streaming, streaming) ||
                other.streaming == streaming) &&
            (identical(other.sending, sending) || other.sending == sending));
  }

  @override
  int get hashCode => Object.hash(runtimeType, sessionId,
      const DeepCollectionEquality().hash(_messages), streaming, sending);

  /// Create a copy of ChatThreadState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatThreadStateImplCopyWith<_$ChatThreadStateImpl> get copyWith =>
      __$$ChatThreadStateImplCopyWithImpl<_$ChatThreadStateImpl>(
          this, _$identity);
}

abstract class _ChatThreadState implements ChatThreadState {
  const factory _ChatThreadState(
      {final String? sessionId,
      final List<ChatMessage> messages,
      final String streaming,
      final bool sending}) = _$ChatThreadStateImpl;

  @override
  String? get sessionId;
  @override
  List<ChatMessage> get messages;

  /// Text currently streaming in (not yet finalized as a message).
  @override
  String get streaming;
  @override
  bool get sending;

  /// Create a copy of ChatThreadState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatThreadStateImplCopyWith<_$ChatThreadStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
