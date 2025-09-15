class LinkResolver {
  // key: LinkIdExt (String), value: LinkId (int)
  static final Map<String, int> _cache = {};

  /// Seed 1 mapping (paling sering dipakai ketika membuka detail chat)
  static void seedOne({required String linkIdExt, required int linkId}) {
    if (linkIdExt.isEmpty || linkId <= 0) return;
    _cache[linkIdExt] = linkId;
  }

  /// Seed banyak mapping (saat load chat list)
  static void seedMany(List<Map<String, dynamic>> items) {
    for (final it in items) {
      final ext = it['IdExt']?.toString() ?? it['LinkIdExt']?.toString();
      final idRaw = it['Id'] ?? it['LinkId'];
      final id = idRaw is int ? idRaw : int.tryParse(idRaw?.toString() ?? '');
      if (ext != null && ext.isNotEmpty && id != null && id > 0) {
        _cache[ext] = id;
      }
    }
  }

  /// Ambil LinkId dari LinkIdExt (return null kalau tidak ketemu)
  static int? resolve(String? linkIdExt) {
    if (linkIdExt == null || linkIdExt.isEmpty) return null;
    return _cache[linkIdExt];
  }
}
