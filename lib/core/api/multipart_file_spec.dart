import 'dart:typed_data';

import 'package:dio/dio.dart';

/// v72: source-agnostic spec for one file in a multipart upload.
///
/// Either `path` (from a `file_picker` `PlatformFile`) or `bytes`
/// (for in-memory blobs) must be supplied — the helper picks the
/// right `MultipartFile` factory automatically. `filename` is the
/// user-supplied original name surfaced to the backend (and into
/// `original_filename` on the persisted SupportAttachment row).
///
/// Kept deliberately small so the support repository doesn't need
/// to import Dio symbols — the only Dio coupling is centralised in
/// `toMultipartFile()`.
class MultipartFileSpec {
  MultipartFileSpec({
    required this.filename,
    this.path,
    this.bytes,
    this.contentType,
  }) : assert(
          (path != null && path.isNotEmpty) ||
              (bytes != null && bytes.isNotEmpty),
          'MultipartFileSpec needs either a path or bytes',
        );

  /// User-supplied original filename — the backend stores this
  /// verbatim in `original_filename` (capped at 255 chars).
  final String filename;

  /// Absolute on-device path. Always populated for files picked via
  /// `file_picker` on iOS/Android. The helper prefers this when
  /// present so large files stream from disk instead of loading
  /// into memory first.
  final String? path;

  /// In-memory bytes. Only used when `path` is unavailable (rare on
  /// mobile; the path is the standard source).
  final Uint8List? bytes;

  /// Optional explicit MIME type. When `null` Dio infers from the
  /// filename extension or sends `application/octet-stream`. The
  /// backend `_mobile_save_support_attachments` helper relies on
  /// the extension whitelist, not the MIME type, so this is a hint
  /// rather than a contract requirement.
  final String? contentType;

  MultipartFile toMultipartFile() {
    final mime = _parseContentType(contentType);
    if (path != null && path!.isNotEmpty) {
      return MultipartFile.fromFileSync(
        path!,
        filename: filename,
        contentType: mime,
      );
    }
    return MultipartFile.fromBytes(
      bytes!,
      filename: filename,
      contentType: mime,
    );
  }

  static DioMediaType? _parseContentType(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty || !trimmed.contains('/')) return null;
    final parts = trimmed.split('/');
    return DioMediaType(parts[0], parts.sublist(1).join('/'));
  }
}
