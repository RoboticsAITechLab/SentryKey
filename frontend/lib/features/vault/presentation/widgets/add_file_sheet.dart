import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/auth_session.dart';
import '../../data/models/vault_file.dart';

class AddFileSheet extends StatefulWidget {
  final Function(VaultFile) onFileSaved;

  const AddFileSheet({Key? key, required this.onFileSaved}) : super(key: key);

  @override
  State<AddFileSheet> createState() => _AddFileSheetState();
}

class _AddFileSheetState extends State<AddFileSheet> {
  final TextEditingController _titleController = TextEditingController();
  PlatformFile? _pickedFile;
  bool _isSaving = false;
  final Uuid _uuid = const Uuid();

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.first.path != null) {
      setState(() {
        _pickedFile = result.files.first;
        if (_titleController.text.isEmpty) {
          _titleController.text = p.basenameWithoutExtension(_pickedFile!.name);
        }
      });
    }
  }

  Future<void> _saveFile() async {
    if (_pickedFile == null || _titleController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);

    try {
      File file = File(_pickedFile!.path!);
      final appDir = await getApplicationDocumentsDirectory();
      final folderName = AuthSession.isDuressMode ? 'sentry_vault_files_duress' : 'sentry_vault_files';
      final vaultDir = Directory(p.join(appDir.path, folderName));

      if (!await vaultDir.exists()) {
        await vaultDir.create(recursive: true);
      }

      final fileExtension = p.extension(file.path);
      final newFileName = '\${_uuid.v4()}\$fileExtension';
      final newPath = p.join(vaultDir.path, newFileName);

      final savedFile = await file.copy(newPath);

      final vaultFile = VaultFile(
        id: _uuid.v4(),
        name: _titleController.text.trim(),
        path: savedFile.path,
        sizeBytes: await savedFile.length(),
        dateAdded: DateTime.now(),
        extension: fileExtension.replaceAll('.', '').toLowerCase(),
      );

      widget.onFileSaved(vaultFile);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error saving file: \$e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildFileIcon(String ext) {
    IconData iconData;
    Color iconColor;

    switch (ext) {
      case 'pdf':
        iconData = Icons.picture_as_pdf_rounded;
        iconColor = const Color(0xFFFF4D4D);
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
        iconData = Icons.image_rounded;
        iconColor = const Color(0xFF00E5FF);
        break;
      case 'mp3':
      case 'wav':
      case 'm4a':
        iconData = Icons.audiotrack_rounded;
        iconColor = const Color(0xFFFF00AA);
        break;
      case 'mp4':
      case 'mkv':
      case 'avi':
        iconData = Icons.video_file_rounded;
        iconColor = const Color(0xFFB000FF);
        break;
      case 'doc':
      case 'docx':
      case 'txt':
        iconData = Icons.description_rounded;
        iconColor = const Color(0xFF0077B6);
        break;
      case 'xls':
      case 'xlsx':
      case 'csv':
        iconData = Icons.table_chart_rounded;
        iconColor = const Color(0xFF00E676);
        break;
      default:
        iconData = Icons.insert_drive_file_rounded;
        iconColor = AppColors.primary;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.3)),
      ),
      child: Icon(iconData, color: iconColor, size: 24),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes > 0) ? (bytes.toString().length - 1) ~/ 3 : 0;
    if (i >= suffixes.length) i = suffixes.length - 1;
    final value = bytes / (1024 * (i > 0 ? i : 1));
    return '\${value.toStringAsFixed(1)} \${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      margin: EdgeInsets.only(bottom: keyboardHeight),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 40,
            spreadRadius: -10,
            offset: const Offset(0, -10),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: AppColors.primary.withOpacity(0.2),
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Secure a New File',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload a document, photo, or any file. It will be encrypted and hidden in your vault.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          
          // File Picker Area
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _pickedFile != null ? AppColors.primary : AppColors.primary.withOpacity(0.3),
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: _pickedFile == null
                  ? Column(
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 48,
                          color: AppColors.primary.withOpacity(0.8),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tap to browse files',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Images, PDFs, Audio, Video & more',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        _buildFileIcon(_pickedFile!.extension?.toLowerCase().replaceAll('.', '') ?? ''),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _pickedFile!.name,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatBytes(_pickedFile!.size),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.check_circle_rounded, color: AppColors.primary),
                      ],
                    ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Title Input
          Text(
            'FILE TITLE',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'E.g., Passport Copy',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary.withOpacity(0.5)),
              ),
              prefixIcon: Icon(
                Icons.title_rounded,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Save Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveFile,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Secure to Vault',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
