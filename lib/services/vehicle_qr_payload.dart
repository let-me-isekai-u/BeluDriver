/// Identify the vehicle envelope only; the backend validates its secret/authority.
bool isVehicleQrPayload(String raw) {
  try {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return false;
    final values = Uri.splitQueryString(
      uri.hasFragment ? uri.fragment : uri.query,
    );
    return (values['c'] ?? '').isNotEmpty && (values['k'] ?? '').isNotEmpty;
  } on FormatException {
    return false;
  }
}
