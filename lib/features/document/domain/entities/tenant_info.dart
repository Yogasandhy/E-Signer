import 'package:equatable/equatable.dart';

class TenantInfo extends Equatable {
  const TenantInfo({
    required this.id,
    required this.name,
    required this.slug,
  });

  final String id;
  final String name;
  final String slug;

  @override
  List<Object?> get props => [id, name, slug];
}

