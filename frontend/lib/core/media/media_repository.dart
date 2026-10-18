import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/models.dart';
import '../api/api_client.dart';
import '../providers.dart';

typedef MediaFile = ({Uint8List bytes, String filename});

class MediaRepository {
  MediaRepository(this.api);
  final ApiClient api;

  Future<Json> upload(String name, Uint8List bytes) => api.upload(name, bytes);
  Future<Json> metadata(int id) async => Map<String, dynamic>.from(
    await api.request('/uploads/$id/metadata') as Map,
  );
  Future<MediaFile> download(int id, {String? path}) =>
      api.download(id, path: path);
}

final mediaRepositoryProvider = Provider(
  (ref) => MediaRepository(ref.watch(apiProvider)),
);

// Provider lifetime follows the visible image. Neither bytes nor private
// metadata are stored in the persistent offline cache.
final mediaBytesProvider = FutureProvider.autoDispose
    .family<MediaFile, ({int id, String? path})>((ref, key) {
      ref.watch(sessionProvider.select((value) => value.value?.id));
      return ref
          .watch(mediaRepositoryProvider)
          .download(key.id, path: key.path);
    });
final mediaMetadataProvider = FutureProvider.autoDispose.family<Json, int>((
  ref,
  id,
) {
  ref.watch(sessionProvider.select((value) => value.value?.id));
  return ref.watch(mediaRepositoryProvider).metadata(id);
});
