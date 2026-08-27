// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$SearchPageState {
  List<SearchResult> get results => throw _privateConstructorUsedError;
  String? get cursor => throw _privateConstructorUsedError;
  String get modeUsed => throw _privateConstructorUsedError;
  int get totalEstimate => throw _privateConstructorUsedError;
  bool get loadingMore => throw _privateConstructorUsedError;
  List<SearchSourceStatus> get sources => throw _privateConstructorUsedError;
  int get tookMs => throw _privateConstructorUsedError;

  /// Create a copy of SearchPageState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SearchPageStateCopyWith<SearchPageState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SearchPageStateCopyWith<$Res> {
  factory $SearchPageStateCopyWith(
          SearchPageState value, $Res Function(SearchPageState) then) =
      _$SearchPageStateCopyWithImpl<$Res, SearchPageState>;
  @useResult
  $Res call(
      {List<SearchResult> results,
      String? cursor,
      String modeUsed,
      int totalEstimate,
      bool loadingMore,
      List<SearchSourceStatus> sources,
      int tookMs});
}

/// @nodoc
class _$SearchPageStateCopyWithImpl<$Res, $Val extends SearchPageState>
    implements $SearchPageStateCopyWith<$Res> {
  _$SearchPageStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SearchPageState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? results = null,
    Object? cursor = freezed,
    Object? modeUsed = null,
    Object? totalEstimate = null,
    Object? loadingMore = null,
    Object? sources = null,
    Object? tookMs = null,
  }) {
    return _then(_value.copyWith(
      results: null == results
          ? _value.results
          : results // ignore: cast_nullable_to_non_nullable
              as List<SearchResult>,
      cursor: freezed == cursor
          ? _value.cursor
          : cursor // ignore: cast_nullable_to_non_nullable
              as String?,
      modeUsed: null == modeUsed
          ? _value.modeUsed
          : modeUsed // ignore: cast_nullable_to_non_nullable
              as String,
      totalEstimate: null == totalEstimate
          ? _value.totalEstimate
          : totalEstimate // ignore: cast_nullable_to_non_nullable
              as int,
      loadingMore: null == loadingMore
          ? _value.loadingMore
          : loadingMore // ignore: cast_nullable_to_non_nullable
              as bool,
      sources: null == sources
          ? _value.sources
          : sources // ignore: cast_nullable_to_non_nullable
              as List<SearchSourceStatus>,
      tookMs: null == tookMs
          ? _value.tookMs
          : tookMs // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SearchPageStateImplCopyWith<$Res>
    implements $SearchPageStateCopyWith<$Res> {
  factory _$$SearchPageStateImplCopyWith(_$SearchPageStateImpl value,
          $Res Function(_$SearchPageStateImpl) then) =
      __$$SearchPageStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<SearchResult> results,
      String? cursor,
      String modeUsed,
      int totalEstimate,
      bool loadingMore,
      List<SearchSourceStatus> sources,
      int tookMs});
}

/// @nodoc
class __$$SearchPageStateImplCopyWithImpl<$Res>
    extends _$SearchPageStateCopyWithImpl<$Res, _$SearchPageStateImpl>
    implements _$$SearchPageStateImplCopyWith<$Res> {
  __$$SearchPageStateImplCopyWithImpl(
      _$SearchPageStateImpl _value, $Res Function(_$SearchPageStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of SearchPageState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? results = null,
    Object? cursor = freezed,
    Object? modeUsed = null,
    Object? totalEstimate = null,
    Object? loadingMore = null,
    Object? sources = null,
    Object? tookMs = null,
  }) {
    return _then(_$SearchPageStateImpl(
      results: null == results
          ? _value._results
          : results // ignore: cast_nullable_to_non_nullable
              as List<SearchResult>,
      cursor: freezed == cursor
          ? _value.cursor
          : cursor // ignore: cast_nullable_to_non_nullable
              as String?,
      modeUsed: null == modeUsed
          ? _value.modeUsed
          : modeUsed // ignore: cast_nullable_to_non_nullable
              as String,
      totalEstimate: null == totalEstimate
          ? _value.totalEstimate
          : totalEstimate // ignore: cast_nullable_to_non_nullable
              as int,
      loadingMore: null == loadingMore
          ? _value.loadingMore
          : loadingMore // ignore: cast_nullable_to_non_nullable
              as bool,
      sources: null == sources
          ? _value._sources
          : sources // ignore: cast_nullable_to_non_nullable
              as List<SearchSourceStatus>,
      tookMs: null == tookMs
          ? _value.tookMs
          : tookMs // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$SearchPageStateImpl implements _SearchPageState {
  const _$SearchPageStateImpl(
      {required final List<SearchResult> results,
      this.cursor,
      this.modeUsed = '',
      this.totalEstimate = -1,
      this.loadingMore = false,
      final List<SearchSourceStatus> sources = const <SearchSourceStatus>[],
      this.tookMs = 0})
      : _results = results,
        _sources = sources;

  final List<SearchResult> _results;
  @override
  List<SearchResult> get results {
    if (_results is EqualUnmodifiableListView) return _results;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_results);
  }

  @override
  final String? cursor;
  @override
  @JsonKey()
  final String modeUsed;
  @override
  @JsonKey()
  final int totalEstimate;
  @override
  @JsonKey()
  final bool loadingMore;
  final List<SearchSourceStatus> _sources;
  @override
  @JsonKey()
  List<SearchSourceStatus> get sources {
    if (_sources is EqualUnmodifiableListView) return _sources;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sources);
  }

  @override
  @JsonKey()
  final int tookMs;

  @override
  String toString() {
    return 'SearchPageState(results: $results, cursor: $cursor, modeUsed: $modeUsed, totalEstimate: $totalEstimate, loadingMore: $loadingMore, sources: $sources, tookMs: $tookMs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SearchPageStateImpl &&
            const DeepCollectionEquality().equals(other._results, _results) &&
            (identical(other.cursor, cursor) || other.cursor == cursor) &&
            (identical(other.modeUsed, modeUsed) ||
                other.modeUsed == modeUsed) &&
            (identical(other.totalEstimate, totalEstimate) ||
                other.totalEstimate == totalEstimate) &&
            (identical(other.loadingMore, loadingMore) ||
                other.loadingMore == loadingMore) &&
            const DeepCollectionEquality().equals(other._sources, _sources) &&
            (identical(other.tookMs, tookMs) || other.tookMs == tookMs));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_results),
      cursor,
      modeUsed,
      totalEstimate,
      loadingMore,
      const DeepCollectionEquality().hash(_sources),
      tookMs);

  /// Create a copy of SearchPageState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SearchPageStateImplCopyWith<_$SearchPageStateImpl> get copyWith =>
      __$$SearchPageStateImplCopyWithImpl<_$SearchPageStateImpl>(
          this, _$identity);
}

abstract class _SearchPageState implements SearchPageState {
  const factory _SearchPageState(
      {required final List<SearchResult> results,
      final String? cursor,
      final String modeUsed,
      final int totalEstimate,
      final bool loadingMore,
      final List<SearchSourceStatus> sources,
      final int tookMs}) = _$SearchPageStateImpl;

  @override
  List<SearchResult> get results;
  @override
  String? get cursor;
  @override
  String get modeUsed;
  @override
  int get totalEstimate;
  @override
  bool get loadingMore;
  @override
  List<SearchSourceStatus> get sources;
  @override
  int get tookMs;

  /// Create a copy of SearchPageState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SearchPageStateImplCopyWith<_$SearchPageStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$SearchState {
  SearchFilters get filters => throw _privateConstructorUsedError;
  AsyncValue<SearchPageState> get page => throw _privateConstructorUsedError;
  bool get submitted => throw _privateConstructorUsedError;

  /// Create a copy of SearchState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SearchStateCopyWith<SearchState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SearchStateCopyWith<$Res> {
  factory $SearchStateCopyWith(
          SearchState value, $Res Function(SearchState) then) =
      _$SearchStateCopyWithImpl<$Res, SearchState>;
  @useResult
  $Res call(
      {SearchFilters filters,
      AsyncValue<SearchPageState> page,
      bool submitted});
}

/// @nodoc
class _$SearchStateCopyWithImpl<$Res, $Val extends SearchState>
    implements $SearchStateCopyWith<$Res> {
  _$SearchStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SearchState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? filters = null,
    Object? page = null,
    Object? submitted = null,
  }) {
    return _then(_value.copyWith(
      filters: null == filters
          ? _value.filters
          : filters // ignore: cast_nullable_to_non_nullable
              as SearchFilters,
      page: null == page
          ? _value.page
          : page // ignore: cast_nullable_to_non_nullable
              as AsyncValue<SearchPageState>,
      submitted: null == submitted
          ? _value.submitted
          : submitted // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SearchStateImplCopyWith<$Res>
    implements $SearchStateCopyWith<$Res> {
  factory _$$SearchStateImplCopyWith(
          _$SearchStateImpl value, $Res Function(_$SearchStateImpl) then) =
      __$$SearchStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {SearchFilters filters,
      AsyncValue<SearchPageState> page,
      bool submitted});
}

/// @nodoc
class __$$SearchStateImplCopyWithImpl<$Res>
    extends _$SearchStateCopyWithImpl<$Res, _$SearchStateImpl>
    implements _$$SearchStateImplCopyWith<$Res> {
  __$$SearchStateImplCopyWithImpl(
      _$SearchStateImpl _value, $Res Function(_$SearchStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of SearchState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? filters = null,
    Object? page = null,
    Object? submitted = null,
  }) {
    return _then(_$SearchStateImpl(
      filters: null == filters
          ? _value.filters
          : filters // ignore: cast_nullable_to_non_nullable
              as SearchFilters,
      page: null == page
          ? _value.page
          : page // ignore: cast_nullable_to_non_nullable
              as AsyncValue<SearchPageState>,
      submitted: null == submitted
          ? _value.submitted
          : submitted // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$SearchStateImpl implements _SearchState {
  const _$SearchStateImpl(
      {this.filters = const SearchFilters(query: ''),
      this.page = const AsyncValue<SearchPageState>.loading(),
      this.submitted = false});

  @override
  @JsonKey()
  final SearchFilters filters;
  @override
  @JsonKey()
  final AsyncValue<SearchPageState> page;
  @override
  @JsonKey()
  final bool submitted;

  @override
  String toString() {
    return 'SearchState(filters: $filters, page: $page, submitted: $submitted)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SearchStateImpl &&
            (identical(other.filters, filters) || other.filters == filters) &&
            (identical(other.page, page) || other.page == page) &&
            (identical(other.submitted, submitted) ||
                other.submitted == submitted));
  }

  @override
  int get hashCode => Object.hash(runtimeType, filters, page, submitted);

  /// Create a copy of SearchState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SearchStateImplCopyWith<_$SearchStateImpl> get copyWith =>
      __$$SearchStateImplCopyWithImpl<_$SearchStateImpl>(this, _$identity);
}

abstract class _SearchState implements SearchState {
  const factory _SearchState(
      {final SearchFilters filters,
      final AsyncValue<SearchPageState> page,
      final bool submitted}) = _$SearchStateImpl;

  @override
  SearchFilters get filters;
  @override
  AsyncValue<SearchPageState> get page;
  @override
  bool get submitted;

  /// Create a copy of SearchState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SearchStateImplCopyWith<_$SearchStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
