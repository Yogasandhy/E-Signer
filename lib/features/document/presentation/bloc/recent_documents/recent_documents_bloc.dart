import 'package:bloc/bloc.dart';

import '../../../domain/usecases/document_usecases.dart';
import 'recent_documents_event.dart';
import 'recent_documents_state.dart';

class RecentDocumentsBloc extends Bloc<RecentDocumentsEvent, RecentDocumentsState> {
  RecentDocumentsBloc({
    required DocumentUseCases documentUseCases,
  })  : _documentUseCases = documentUseCases,
        super(const RecentDocumentsState(documentPath: [])) {
    on<RecentDocumentsLoaded>(_onLoaded);
    on<RecentDocumentAdded>(_onAdded);
    on<RecentDocumentDeleted>(_onDeleted);
    on<RecentDocumentSelected>(_onSelected);
  }

  final DocumentUseCases _documentUseCases;

  Future<void> _onLoaded(
    RecentDocumentsLoaded event,
    Emitter<RecentDocumentsState> emit,
  ) async {
    final paths = await _documentUseCases.loadRecentDocuments();
    emit(state.copyWith(documentPath: paths));
  }

  Future<void> _onAdded(
    RecentDocumentAdded event,
    Emitter<RecentDocumentsState> emit,
  ) async {
    final current = state.documentPath;

    final updated = current.contains(event.documentPath)
        ? [
            event.documentPath,
            ...current.where((d) => d != event.documentPath),
          ]
        : [event.documentPath, ...current];

    final trimmed = _trimList(updated);
    emit(state.copyWith(documentPath: trimmed));
    await _documentUseCases.saveRecentDocuments(trimmed);
  }

  Future<void> _onDeleted(
    RecentDocumentDeleted event,
    Emitter<RecentDocumentsState> emit,
  ) async {
    final updated = [...state.documentPath]
      ..removeWhere((d) => d == event.documentPath);

    emit(RecentDocumentsState(documentPath: updated));
    await _documentUseCases.saveRecentDocuments(updated);
  }

  Future<void> _onSelected(
    RecentDocumentSelected event,
    Emitter<RecentDocumentsState> emit,
  ) async {
    final current = state.documentPath;

    final updated = current.contains(event.documentPath)
        ? [
            event.documentPath,
            ...current.where((d) => d != event.documentPath),
          ]
        : [event.documentPath, ...current];

    final trimmed = _trimList(updated);
    emit(state.copyWith(documentPath: trimmed));
    await _documentUseCases.saveRecentDocuments(trimmed);
  }

  List<String> _trimList(List<String> list) {
    if (list.length <= 3) return list;
    return list.take(3).toList();
  }
}
