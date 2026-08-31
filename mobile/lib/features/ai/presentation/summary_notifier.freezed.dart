// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'summary_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$SummaryState {
  ExplanationLevel get level =>
      throw _privateConstructorUsedError; // null = not requested yet (idle). Generation is opt-in — no tokens are
// spent until the user taps "Summarize", so the initial state must be
// distinct from loading.
  AsyncValue<PaperSummaryAI>? get data => throw _privateConstructorUsedError;

  /// Create a copy of SummaryState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SummaryStateCopyWith<SummaryState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SummaryStateCopyWith<$Res> {
  factory $SummaryStateCopyWith(
          SummaryState value, $Res Function(SummaryState) then) =
      _$SummaryStateCopyWithImpl<$Res, SummaryState>;
  @useResult
  $Res call({ExplanationLevel level, AsyncValue<PaperSummaryAI>? data});
}

/// @nodoc
class _$SummaryStateCopyWithImpl<$Res, $Val extends SummaryState>
    implements $SummaryStateCopyWith<$Res> {
  _$SummaryStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SummaryState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? level = null,
    Object? data = freezed,
  }) {
    return _then(_value.copyWith(
      level: null == level
          ? _value.level
          : level // ignore: cast_nullable_to_non_nullable
              as ExplanationLevel,
      data: freezed == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as AsyncValue<PaperSummaryAI>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SummaryStateImplCopyWith<$Res>
    implements $SummaryStateCopyWith<$Res> {
  factory _$$SummaryStateImplCopyWith(
          _$SummaryStateImpl value, $Res Function(_$SummaryStateImpl) then) =
      __$$SummaryStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({ExplanationLevel level, AsyncValue<PaperSummaryAI>? data});
}

/// @nodoc
class __$$SummaryStateImplCopyWithImpl<$Res>
    extends _$SummaryStateCopyWithImpl<$Res, _$SummaryStateImpl>
    implements _$$SummaryStateImplCopyWith<$Res> {
  __$$SummaryStateImplCopyWithImpl(
      _$SummaryStateImpl _value, $Res Function(_$SummaryStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of SummaryState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? level = null,
    Object? data = freezed,
  }) {
    return _then(_$SummaryStateImpl(
      level: null == level
          ? _value.level
          : level // ignore: cast_nullable_to_non_nullable
              as ExplanationLevel,
      data: freezed == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as AsyncValue<PaperSummaryAI>?,
    ));
  }
}

/// @nodoc

class _$SummaryStateImpl implements _SummaryState {
  const _$SummaryStateImpl(
      {this.level = ExplanationLevel.intermediate, this.data});

  @override
  @JsonKey()
  final ExplanationLevel level;
// null = not requested yet (idle). Generation is opt-in — no tokens are
// spent until the user taps "Summarize", so the initial state must be
// distinct from loading.
  @override
  final AsyncValue<PaperSummaryAI>? data;

  @override
  String toString() {
    return 'SummaryState(level: $level, data: $data)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SummaryStateImpl &&
            (identical(other.level, level) || other.level == level) &&
            (identical(other.data, data) || other.data == data));
  }

  @override
  int get hashCode => Object.hash(runtimeType, level, data);

  /// Create a copy of SummaryState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SummaryStateImplCopyWith<_$SummaryStateImpl> get copyWith =>
      __$$SummaryStateImplCopyWithImpl<_$SummaryStateImpl>(this, _$identity);
}

abstract class _SummaryState implements SummaryState {
  const factory _SummaryState(
      {final ExplanationLevel level,
      final AsyncValue<PaperSummaryAI>? data}) = _$SummaryStateImpl;

  @override
  ExplanationLevel
      get level; // null = not requested yet (idle). Generation is opt-in — no tokens are
// spent until the user taps "Summarize", so the initial state must be
// distinct from loading.
  @override
  AsyncValue<PaperSummaryAI>? get data;

  /// Create a copy of SummaryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SummaryStateImplCopyWith<_$SummaryStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
