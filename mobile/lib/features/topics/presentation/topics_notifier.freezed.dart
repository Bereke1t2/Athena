// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'topics_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$TopicListState {
  List<Topic> get items => throw _privateConstructorUsedError;
  String? get cursor => throw _privateConstructorUsedError;
  String get kindFilter => throw _privateConstructorUsedError;
  bool get loadingMore => throw _privateConstructorUsedError;

  /// Create a copy of TopicListState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TopicListStateCopyWith<TopicListState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TopicListStateCopyWith<$Res> {
  factory $TopicListStateCopyWith(
          TopicListState value, $Res Function(TopicListState) then) =
      _$TopicListStateCopyWithImpl<$Res, TopicListState>;
  @useResult
  $Res call(
      {List<Topic> items, String? cursor, String kindFilter, bool loadingMore});
}

/// @nodoc
class _$TopicListStateCopyWithImpl<$Res, $Val extends TopicListState>
    implements $TopicListStateCopyWith<$Res> {
  _$TopicListStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TopicListState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? cursor = freezed,
    Object? kindFilter = null,
    Object? loadingMore = null,
  }) {
    return _then(_value.copyWith(
      items: null == items
          ? _value.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<Topic>,
      cursor: freezed == cursor
          ? _value.cursor
          : cursor // ignore: cast_nullable_to_non_nullable
              as String?,
      kindFilter: null == kindFilter
          ? _value.kindFilter
          : kindFilter // ignore: cast_nullable_to_non_nullable
              as String,
      loadingMore: null == loadingMore
          ? _value.loadingMore
          : loadingMore // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TopicListStateImplCopyWith<$Res>
    implements $TopicListStateCopyWith<$Res> {
  factory _$$TopicListStateImplCopyWith(_$TopicListStateImpl value,
          $Res Function(_$TopicListStateImpl) then) =
      __$$TopicListStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<Topic> items, String? cursor, String kindFilter, bool loadingMore});
}

/// @nodoc
class __$$TopicListStateImplCopyWithImpl<$Res>
    extends _$TopicListStateCopyWithImpl<$Res, _$TopicListStateImpl>
    implements _$$TopicListStateImplCopyWith<$Res> {
  __$$TopicListStateImplCopyWithImpl(
      _$TopicListStateImpl _value, $Res Function(_$TopicListStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of TopicListState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? cursor = freezed,
    Object? kindFilter = null,
    Object? loadingMore = null,
  }) {
    return _then(_$TopicListStateImpl(
      items: null == items
          ? _value._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<Topic>,
      cursor: freezed == cursor
          ? _value.cursor
          : cursor // ignore: cast_nullable_to_non_nullable
              as String?,
      kindFilter: null == kindFilter
          ? _value.kindFilter
          : kindFilter // ignore: cast_nullable_to_non_nullable
              as String,
      loadingMore: null == loadingMore
          ? _value.loadingMore
          : loadingMore // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$TopicListStateImpl implements _TopicListState {
  const _$TopicListStateImpl(
      {required final List<Topic> items,
      this.cursor,
      this.kindFilter = '',
      this.loadingMore = false})
      : _items = items;

  final List<Topic> _items;
  @override
  List<Topic> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final String? cursor;
  @override
  @JsonKey()
  final String kindFilter;
  @override
  @JsonKey()
  final bool loadingMore;

  @override
  String toString() {
    return 'TopicListState(items: $items, cursor: $cursor, kindFilter: $kindFilter, loadingMore: $loadingMore)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TopicListStateImpl &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.cursor, cursor) || other.cursor == cursor) &&
            (identical(other.kindFilter, kindFilter) ||
                other.kindFilter == kindFilter) &&
            (identical(other.loadingMore, loadingMore) ||
                other.loadingMore == loadingMore));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_items),
      cursor,
      kindFilter,
      loadingMore);

  /// Create a copy of TopicListState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TopicListStateImplCopyWith<_$TopicListStateImpl> get copyWith =>
      __$$TopicListStateImplCopyWithImpl<_$TopicListStateImpl>(
          this, _$identity);
}

abstract class _TopicListState implements TopicListState {
  const factory _TopicListState(
      {required final List<Topic> items,
      final String? cursor,
      final String kindFilter,
      final bool loadingMore}) = _$TopicListStateImpl;

  @override
  List<Topic> get items;
  @override
  String? get cursor;
  @override
  String get kindFilter;
  @override
  bool get loadingMore;

  /// Create a copy of TopicListState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TopicListStateImplCopyWith<_$TopicListStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
