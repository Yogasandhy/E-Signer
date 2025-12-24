import 'package:equatable/equatable.dart';

class TenantMembership extends Equatable {
  const TenantMembership({
    required this.id,
    required this.name,
    required this.slug,
    this.role,
    this.isOwner,
  });

  final String id;
  final String name;
  final String slug;
  final String? role;
  final bool? isOwner;

  @override
  List<Object?> get props => [id, name, slug, role, isOwner];
}

