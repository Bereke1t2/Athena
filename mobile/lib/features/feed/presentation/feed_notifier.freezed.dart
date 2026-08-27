// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'feed_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$FeedPageState {
  List<FeedItem> get items => throw _privateConstructorUsedError;
  String? get cursor => throw _privateConstructorUsedError;
  bool get loadingMore => throw _privateConstructorUsedError;

  /// Create a copy of FeedPageState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FeedPageStateCopyWith<FeedPageState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FeedPageStateCopyWith<$Res> {
  factory $FeedPageStateCopyWith(
          FeedPageState value, $Res Function(FeedPageState) then) =
      _$FeedPageStateCopyWithImpl<$Res, FeedPageState>;
  @useResult
  $Res call({List<FeedItem> items, String? cursor, bool loadingMore});
}

/// @nodoc
class _$FeedPageStateCopyWithImpl<$Res, $Val extends FeedPageState>
    implements $FeedPageStateCopyWith<$Res> {
  _$FeedPageStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FeedPageState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? cursor = freezed,
    Object? loadingMore = null,
  }) {
    return _then(_value.copyWith(
      items: null == items
          ? _value.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<FeedItem>,
      cursor: freezed == cursor
          ? _value.cursor
          : cursor // ignore: cast_nullable_to_non_nullable
              as String?,
      loadingMore: null == loadingMore
          ? _value.loadingMore
          : loadingMore // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FeedPageStateImplCopyWith<$Res>
    implements $FeedPageStateCopyWith<$Res> {
  factory _$$FeedPageStateImplCopyWith(
          _$FeedPageStateImpl value, $Res Function(_$FeedPageStateImpl) then) =
      __$$FeedPageStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<FeedItem> items, String? cursor, bool loadingMore});
}

/// @nodoc
class __$$FeedPageStateImplCopyWithImpl<$Res>
    extends _$FeedPageStateCopyWithImpl<$Res, _$FeedPageStateImpl>
    implements _$$FeedPageStateImplCopyWith<$Res> {
  __$$FeedPageStateImplCopyWithImpl(
      _$FeedPageStateImpl _value, $Res Function(_$FeedPageStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of FeedPageState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? cursor = freezed,
    Object? loadingMore = null,
  }) {
    return _then(_$FeedPageStateImpl(
      items: null == items
          ? _value._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<FeedItem>,
      cursor: freezed == cursor
          ? _value.cursor
          : cursor // ignore: cast_nullable_to_non_nullable
              as String?,
      loadingMore: null == loadingMore
          ? _value.loadingMore
          : loadingMore // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$FeedPageStateImpl implements _FeedPageState {
  const _$FeedPageStateImpl(
      {required final List<FeedItem> items,
      this.cursor,
      this.loadingMore = false})
      : _items = items;

  final List<FeedItem> _items;
  @override
  List<FeedItem> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final String? cursor;
  @override
  @JsonKey()
  final bool loadingMore;

  @override
  String toString() {
    return 'FeedPageState(items: $items, cursor: $cursor, loadingMore: $loadingMore)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FeedPageStateImpl &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.cursor, cursor) || other.cursor == cursor) &&
            (identical(other.loadingMore, loadingMore) ||
                other.loadingMore == loadingMore));
  }

  @override
  int get hashCode => Object.hash(runtimeType,
      const DeepCollectionEquality().hash(_items), cursor, loadingMore);

  /// Create a copy of FeedPageState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FeedPageStateImplCopyWith<_$FeedPageStateImpl> get copyWith =>
      __$$FeedPageStateImplCopyWithImpl<_$FeedPageStateImpl>(this, _$identity);
}

abstract class _FeedPageState implements FeedPageState {
  const factory _FeedPageState(
      {required final List<FeedItem> items,
      final String? cursor,
      final bool loadingMore}) = _$FeedPageStateImpl;

  @override
  List<FeedItem> get items;
  @override
  String? get cursor;
  @override
  bool get loadingMore;

  /// Create a copy of FeedPageState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FeedPageStateImplCopyWith<_$FeedPageStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
