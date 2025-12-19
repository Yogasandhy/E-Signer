// Keys for SharedPreferences or other storage identifiers.
const String keyListRecentFile = 'key_list_recent_file';
const String keyTenantId = 'key_tenant_id';
const String keyUserId = 'key_user_id';

String recentDocumentsStorageKey({
  required String tenantId,
  required String userId,
}) {
  final t = Uri.encodeComponent(tenantId.trim());
  final u = Uri.encodeComponent(userId.trim());
  return '${keyListRecentFile}__${t}__$u';
}
