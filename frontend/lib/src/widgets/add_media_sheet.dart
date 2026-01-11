import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

/// A reusable bottom sheet widget to collect media file + metadata.
/// Returns a Map<String, dynamic> through Navigator.pop when submitted:
/// {
///   'picked': PlatformFile,
///   'title': String,
///   'description': String,
///   'duration': int?
/// }
class AddMediaSheet extends StatefulWidget {
  const AddMediaSheet({Key? key}) : super(key: key);

  @override
  State<AddMediaSheet> createState() => _AddMediaSheetState();
}

class _AddMediaSheetState extends State<AddMediaSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  PlatformFile? _chosen;
  bool _isPicking = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: false,
        withReadStream: true,
        type: FileType.any,
      );
      if (res != null && res.files.isNotEmpty) {
        setState(() {
          _chosen = res.files.first;
          // Always update title to match selected file name so reselects take effect
          _titleController.text = _chosen!.name;
        });
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width < 600
                  ? MediaQuery.of(context).size.width
                  : MediaQuery.of(context).size.width * 0.6,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Add Media',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12.0),
                    ElevatedButton.icon(
                      onPressed: _isPicking ? null : _pickFile,
                      icon: _isPicking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.attach_file),
                      label: Text(
                        _isPicking
                            ? 'Preparing file...'
                            : (_chosen == null ? 'Choose File' : _chosen!.name),
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    // Show helpful info while picking or when a large file is chosen
                    if (_chosen != null && _chosen!.size > 50 * 1024 * 1024)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0, bottom: 6.0),
                        child: Flexible(
                          child: Text(
                            'Large file selected (${(_chosen!.size / (1024 * 1024)).toStringAsFixed(1)} MB). Preparing and uploading may take several minutes.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange[800],
                            ),
                            softWrap: true,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4.0),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 8.0),
                    TextField(
                      controller: _descController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    TextField(
                      controller: _durationController,
                      decoration: const InputDecoration(
                        labelText: 'Duration (seconds - optional)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8.0),
                        ElevatedButton(
                          onPressed: _chosen == null
                              ? null
                              : () => Navigator.of(context).pop({
                                  'picked': _chosen,
                                  'title': _titleController.text.trim(),
                                  'description': _descController.text.trim(),
                                  'duration':
                                      _durationController.text.isNotEmpty
                                      ? int.tryParse(_durationController.text)
                                      : null,
                                }),
                          child: const Text('Upload'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
