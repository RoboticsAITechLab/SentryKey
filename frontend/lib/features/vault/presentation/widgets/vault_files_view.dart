import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/auth_session.dart';
import '../../data/models/vault_file.dart';
import '../pages/media_viewer_screen.dart';

class VaultFilesView extends StatefulWidget {
  const VaultFilesView({Key? key}) : super(key: key);

  @override
  State<VaultFilesView> createState() => VaultFilesViewState();
}

class VaultFilesViewState extends State<VaultFilesView> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  List<VaultFile> _files = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = ['All', 'Images', 'Docs', 'Audio', 'Video'];

  String get _metadataKey => AuthSession.isDuressMode ? 'vault_files_metadata_duress' : 'vault_files_metadata';

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    try {
      final String? filesJson = await _storage.read(key: _metadataKey);
      if (filesJson != null) {
        final List<dynamic> decoded = jsonDecode(filesJson);
        _files = decoded.map((e) => VaultFile(
          id: e['id'],
          name: e['name'],
          path: e['path'],
          sizeBytes: e['sizeBytes'],
          dateAdded: DateTime.parse(e['dateAdded']),
          extension: e['extension'],
        )).toList();
        
        // Sort by date descending
        _files.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      }
    } catch (e) {
      debugPrint('Error loading files: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMetadata() async {
    final encoded = jsonEncode(_files.map((e) => {
      'id': e.id,
      'name': e.name,
      'path': e.path,
      'sizeBytes': e.sizeBytes,
      'dateAdded': e.dateAdded.toIso8601String(),
      'extension': e.extension,
    }).toList());
    await _storage.write(key: _metadataKey, value: encoded);
  }

  Future<void> addFileAndSave(VaultFile vaultFile) async {
    _files.insert(0, vaultFile);
    await _saveMetadata();
    setState(() {});
  }

  Future<void> _deleteFile(VaultFile file) async {
    try {
      final f = File(file.path);
      if (await f.exists()) {
        await f.delete();
      }
      _files.removeWhere((element) => element.id == file.id);
      await _saveMetadata();
      setState(() {});
    } catch (e) {
      debugPrint('Error deleting file: $e');
    }
  }

  void _openFile(VaultFile file) {
    final String pathExt = p.extension(file.path).replaceAll('.', '').toLowerCase().trim();
    final String modelExt = file.extension.replaceAll('.', '').toLowerCase().trim();
    final ext = modelExt.isNotEmpty ? modelExt : pathExt;

    final isSupported = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'txt', 'mp3', 'wav', 'm4a', 'flac', 'mp4', 'mkv', 'avi', 'mov'].contains(ext);

    if (isSupported) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MediaViewerScreen(file: file),
        ),
      );
    } else {
      OpenFilex.open(file.path);
    }
  }

  List<VaultFile> get _filteredFiles {
    return _files.where((file) {
      final matchesSearch = file.name.toLowerCase().contains(_searchQuery.toLowerCase());
      if (_selectedCategory == 'All') return matchesSearch;
      
      final ext = file.extension.toLowerCase();
      if (_selectedCategory == 'Images') {
        return matchesSearch && ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext);
      } else if (_selectedCategory == 'Docs') {
        return matchesSearch && ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'csv'].contains(ext);
      } else if (_selectedCategory == 'Audio') {
        return matchesSearch && ['mp3', 'wav', 'm4a', 'flac'].contains(ext);
      } else if (_selectedCategory == 'Video') {
        return matchesSearch && ['mp4', 'mkv', 'avi', 'mov'].contains(ext);
      }
      return matchesSearch;
    }).toList();
  }

  int get _totalSizeBytes {
    return _files.fold(0, (sum, item) => sum + item.sizeBytes);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _files.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return Column(
      children: [
        // 1. Secure Storage Summary (Premium Widget)
        if (_files.isNotEmpty) _buildStorageSummary(),

        // 2. Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search secure files...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white30),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),

        // 3. Category Filter Chips
        if (_files.isNotEmpty)
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(vertical: 10),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, i) {
                final cat = _categories[i];
                final isSelected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: isSelected
                          ? const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF0077B6)])
                          : null,
                      color: isSelected ? null : AppColors.surface,
                      border: Border.all(
                        color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // 4. Files List
        Expanded(
          child: _filteredFiles.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: _filteredFiles.length,
                  itemBuilder: (context, index) {
                    final file = _filteredFiles[index];
                    return _buildFileCard(file);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStorageSummary() {
    final formattedSize = _formatBytes(_totalSizeBytes);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            const Color(0xFF1a1c29).withOpacity(0.6),
          ],
        ),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 16,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SECURE VAULT SPACE',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formattedSize,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_files.length} Files',
                  style: GoogleFonts.spaceMono(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const LinearProgressIndicator(
              value: 0.12, // Visual filler for secure vault storage percent
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.12),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 40,
              color: AppColors.primary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _searchQuery.isNotEmpty ? 'No search results' : 'No files stored yet',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty ? 'Try checking your spelling.' : 'Tap + to securely store a file.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(VaultFile file) {
    final fileColor = _getFileColor(file.extension);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: fileColor.withOpacity(0.04),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openFile(file),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Upgraded glowing dynamic file icon
                _buildFileIcon(file.extension),
                const SizedBox(width: 16),
                // Text details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: fileColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              file.extension.toUpperCase(),
                              style: TextStyle(
                                color: fileColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatBytes(file.sizeBytes),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${file.dateAdded.day.toString().padLeft(2, '0')}/${file.dateAdded.month.toString().padLeft(2, '0')}/${file.dateAdded.year}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Advanced context actions
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white54),
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) {
                    if (value == 'delete') _deleteFile(file);
                    else if (value == 'open') _openFile(file);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'open',
                      child: Row(
                        children: [
                          Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 20),
                          SizedBox(width: 12),
                          Text('Open File', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Color(0xFFFF4D4D), size: 20),
                          SizedBox(width: 12),
                          Text('Delete', style: TextStyle(color: Color(0xFFFF4D4D))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getFileColor(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return const Color(0xFFFF4D4D);
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
        return const Color(0xFF00E5FF);
      case 'mp3':
      case 'wav':
      case 'm4a':
        return const Color(0xFFFF00AA);
      case 'mp4':
      case 'mkv':
      case 'avi':
        return const Color(0xFFB000FF);
      case 'doc':
      case 'docx':
      case 'txt':
        return const Color(0xFF0077B6);
      case 'xls':
      case 'xlsx':
      case 'csv':
        return const Color(0xFF00E676);
      default:
        return AppColors.primary;
    }
  }

  Widget _buildFileIcon(String ext) {
    IconData iconData;
    final iconColor = _getFileColor(ext);

    switch (ext.toLowerCase()) {
      case 'pdf':
        iconData = Icons.picture_as_pdf_rounded;
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
        iconData = Icons.image_rounded;
        break;
      case 'mp3':
      case 'wav':
      case 'm4a':
        iconData = Icons.audiotrack_rounded;
        break;
      case 'mp4':
      case 'mkv':
      case 'avi':
        iconData = Icons.video_file_rounded;
        break;
      case 'doc':
      case 'docx':
      case 'txt':
        iconData = Icons.description_rounded;
        break;
      case 'xls':
      case 'xlsx':
      case 'csv':
        iconData = Icons.table_chart_rounded;
        break;
      default:
        iconData = Icons.insert_drive_file_rounded;
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ],
      ),
      child: Icon(iconData, color: iconColor, size: 28),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes > 0) ? (bytes.toString().length - 1) ~/ 3 : 0;
    if (i >= suffixes.length) i = suffixes.length - 1;
    final value = bytes / (1024 * (i > 0 ? i : 1));
    return '${value.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
