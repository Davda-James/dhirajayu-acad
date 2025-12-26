import 'package:file_picker/file_picker.dart';

class PendingFile {
  final PlatformFile file;
  String title;
  String? description;
  int? duration;
  bool expanded = false;
  String? mediaId;
  String? uploadUrl;
  double progress = 0.0;
  bool uploaded = false;
  bool failed = false;

  PendingFile({
    required this.file,
    this.title = '',
    this.description,
    this.duration,
  });
}
