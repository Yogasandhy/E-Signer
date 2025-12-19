import 'package:equatable/equatable.dart';

sealed class RecentDocumentsEvent extends Equatable {
  const RecentDocumentsEvent();

  @override
  List<Object?> get props => [];
}

final class RecentDocumentsLoaded extends RecentDocumentsEvent {
  const RecentDocumentsLoaded();
}

final class RecentDocumentAdded extends RecentDocumentsEvent {
  const RecentDocumentAdded(this.documentPath);

  final String documentPath;

  @override
  List<Object?> get props => [documentPath];
}

final class RecentDocumentDeleted extends RecentDocumentsEvent {
  const RecentDocumentDeleted(this.documentPath);

  final String documentPath;

  @override
  List<Object?> get props => [documentPath];
}

final class RecentDocumentSelected extends RecentDocumentsEvent {
  const RecentDocumentSelected(this.documentPath);

  final String documentPath;

  @override
  List<Object?> get props => [documentPath];
}

