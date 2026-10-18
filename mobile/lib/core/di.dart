import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/ai/data/ai_repository_impl.dart';
import '../features/ai/domain/ai_repository.dart';
import '../features/auth/data/auth_repository_impl.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/comparison/data/comparison_repository_impl.dart';
import '../features/comparison/domain/comparison_repository.dart';
import '../features/feed/data/feed_repository_impl.dart';
import '../features/feed/domain/feed_repository.dart';
import '../features/follows/data/follows_repository_impl.dart';
import '../features/follows/domain/follows_repository.dart';
import '../features/notifications/data/notifications_repository_impl.dart';
import '../features/notifications/domain/notifications_repository.dart';
import '../features/papers/data/paper_repository_impl.dart';
import '../features/papers/data/pdf_repository_impl.dart';
import '../features/papers/domain/paper_repository.dart';
import '../features/search/data/search_repository_impl.dart';
import '../features/search/domain/search_repository.dart';
import '../features/topics/data/topics_repository_impl.dart';
import '../features/topics/domain/topics_repository.dart';
import 'network/api_client.dart';

part 'di.g.dart';

/// Composition root: interfaces bound to implementations; controllers depend
/// on interfaces only and tests override these providers.
@riverpod
AuthRepository authRepository(Ref ref) =>
    AuthRepositoryImpl(ref.watch(apiClientProvider));

@riverpod
FeedRepository feedRepository(Ref ref) =>
    FeedRepositoryImpl(ref.watch(apiClientProvider));

@riverpod
SearchRepository searchRepository(Ref ref) =>
    SearchRepositoryImpl(ref.watch(apiClientProvider));

@riverpod
TopicsRepository topicsRepository(Ref ref) =>
    TopicsRepositoryImpl(ref.watch(apiClientProvider));

@riverpod
PaperRepository paperRepository(Ref ref) =>
    PaperRepositoryImpl(ref.watch(apiClientProvider));

@riverpod
AiRepository aiRepository(Ref ref) =>
    AiRepositoryImpl(ref.watch(apiClientProvider));

@riverpod
PdfRepositoryImpl pdfRepository(Ref ref) =>
    PdfRepositoryImpl(ref.watch(apiClientProvider));

@riverpod
FollowsRepository followsRepository(Ref ref) =>
    FollowsRepositoryImpl(ref.watch(apiClientProvider));

@riverpod
NotificationsRepository notificationsRepository(Ref ref) =>
    NotificationsRepositoryImpl(ref.watch(apiClientProvider));

@riverpod
ComparisonRepository comparisonRepository(Ref ref) =>
    ComparisonRepositoryImpl(ref.watch(apiClientProvider));

