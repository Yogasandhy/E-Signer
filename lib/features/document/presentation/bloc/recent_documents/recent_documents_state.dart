import 'package:equatable/equatable.dart';

class RecentDocumentsState extends Equatable {
  const RecentDocumentsState({required this.documentPath});

  final List<String> documentPath;

  @override
  List<Object?> get props => [documentPath];

  RecentDocumentsState copyWith({List<String>? documentPath}) {
    return RecentDocumentsState(
      documentPath: documentPath ?? this.documentPath,
    );
  }
}

