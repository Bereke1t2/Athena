import 'annotation.dart';

/// Repository interface managing paper annotations and highlights.
abstract class AnnotationRepository {
  /// Lists all annotations for the given paper.
  Future<List<Annotation>> listAnnotations(String paperId);

  /// Creates a new annotation or highlight.
  Future<Annotation> createAnnotation(CreateAnnotationParams params);

  /// Updates an existing annotation's note or color.
  Future<Annotation> updateAnnotation(UpdateAnnotationParams params);

  /// Deletes an annotation by ID.
  Future<void> deleteAnnotation({required String id, required String paperId});

  /// Lists all annotations for the current authenticated user across all papers.
  Future<List<UserAnnotation>> listUserAnnotations({
    String? color,
    String? query,
    int limit = 50,
  });
}
