import 'package:bloc/bloc.dart';

import '../../../domain/usecases/document_usecases.dart';
import 'recent_documents_event.dart';
import 'recent_documents_state.dart';

class RecentDocumentsBloc extends Bloc<RecentDocumentsEvent, RecentDocumentsState> {
  static const int _maxRecentDocuments = 3;

  RecentDocumentsBloc({
    required DocumentUseCases documentUseCases,
    required String tenantId,
    required String userId,
  })  : _documentUseCases = documentUseCases,
        _tenantId = tenantId,
        _userId = userId,
        super(const RecentDocumentsState(documentPath: [])) {
    on<RecentDocumentsLoaded>(_onLoaded);
    on<RecentDocumentAdded>(_onAdded);
    on<RecentDocumentDeleted>(_onDeleted);
    on<RecentDocumentSelected>(_onSelected);
  }

  final DocumentUseCases _documentUseCases;
  final String _tenantId;
  final String _userId;

  Future<void> _onLoaded(
    RecentDocumentsLoaded event,
    Emitter<RecentDocumentsState> emit,
  ) async {
    final paths = await _documentUseCases.loadRecentDocuments(
      tenantId: _tenantId,
      userId: _userId,
    );
    emit(state.copyWith(documentPath: paths));
  }

  Future<void> _onAdded(
    RecentDocumentAdded event,
    Emitter<RecentDocumentsState> emit,
  ) async {
    await _upsertRecentDocument(event.documentPath, emit);
  }

  Future<void> _onDeleted(
    RecentDocumentDeleted event,
    Emitter<RecentDocumentsState> emit,
  ) async {
    final updated = [...state.documentPath]
      ..removeWhere((d) => d == event.documentPath);

    emit(RecentDocumentsState(documentPath: updated));
    await _documentUseCases.saveRecentDocuments(
      tenantId: _tenantId,
      userId: _userId,
      documentPaths: updated,
    );
  }

  Future<void> _onSelected(
    RecentDocumentSelected event,
    Emitter<RecentDocumentsState> emit,
  ) async {
    await _upsertRecentDocument(event.documentPath, emit);
  }

  Future<void> _upsertRecentDocument(
    String documentPath,
    Emitter<RecentDocumentsState> emit,
  ) async {
    final path = documentPath.trim();
    if (path.isEmpty) return;

    final current = state.documentPath;
    final updated = current.contains(path)
        ? [path, ...current.where((d) => d != path)]
        : [path, ...current];

    final trimmed = _trimList(updated);
    emit(state.copyWith(documentPath: trimmed));
    await _documentUseCases.saveRecentDocuments(
      tenantId: _tenantId,
      userId: _userId,
      documentPaths: trimmed,
    );
  }

  List<String> _trimList(List<String> list) {
    if (list.length <= _maxRecentDocuments) return list;
    return list.take(_maxRecentDocuments).toList();
  }
}
