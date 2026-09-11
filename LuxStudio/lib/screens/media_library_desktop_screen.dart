import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../models/library_asset.dart';
import '../models/library_folder.dart';
import '../state/app_state.dart';
import '../theme/lux_theme.dart';
import '../utils/error_presenter.dart';

/// Desktop Media Library — matches `ui_kit/media_library_desktop/`'s
/// folders + asset-grid layout, wired to the real backend asset-library
/// entity (`backend/app/routers/library.py`, V2 Decision #2) instead of
/// the mockup's hardcoded video/audio/image cards.
///
/// Scope cut vs. the mockup: only video assets are supported — this app
/// only ever processes sermon video, so Audio/Image type filters would be
/// decorative with nothing real behind them. A card's action is "Use for
/// New Project" (copies the asset into a fresh project — real
/// cross-project reuse, see [AppState.useLibraryAssetAsProject]) or
/// Delete, rather than the mockup's no-op "..." menu.
class MediaLibraryDesktopScreen extends StatefulWidget {
  const MediaLibraryDesktopScreen({super.key});

  @override
  State<MediaLibraryDesktopScreen> createState() => _MediaLibraryDesktopScreenState();
}

class _MediaLibraryDesktopScreenState extends State<MediaLibraryDesktopScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _selectedFolderId;

  @override
  void initState() {
    super.initState();
    // Deferred to after the first frame — calling this straight from
    // build() would trigger AppState.notifyListeners() (and this screen's
    // own AnimatedBuilder rebuild) while the framework is still building,
    // which throws.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppStateScope.of(context).loadLibrary();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _uploadMedia(AppState appState) async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['mp4', 'mov']);
    if (file == null) return;
    final Uint8List bytes = await file.readAsBytes();
    if (!mounted) return;
    _showUploadProgressDialog(appState, file.name);
    await appState.uploadLibraryAsset(bytes, file.name, folderId: _selectedFolderId);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (appState.libraryError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(appState.libraryError))));
    }
  }

  /// Non-dismissible upload popup — closed by [_uploadMedia] once the
  /// upload settles (success or error), not by the user tapping outside.
  /// Progress comes from real bytes-sent-over-the-wire events (see
  /// `upload_progress_web.dart`), so the bar actually tracks the transfer
  /// rather than just spinning indefinitely.
  void _showUploadProgressDialog(AppState appState, String filename) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          final progress = appState.libraryUploadProgress;
          return AlertDialog(
            backgroundColor: LuxColors.surface,
            title: Text('Uploading Video', style: LuxText.sora(size: 16, weight: FontWeight.w700)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LuxText.manrope(size: 13, color: LuxColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress > 0 ? progress : null,
                    minHeight: 6,
                    backgroundColor: LuxColors.surfaceRaised,
                    color: LuxColors.gold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  progress > 0 ? '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%' : 'Starting…',
                  style: LuxText.manrope(size: 12, color: LuxColors.textMuted),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _createFolder(AppState appState) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LuxColors.surface,
        title: Text('New Folder', style: LuxText.sora(size: 16, weight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: LuxText.manrope(size: 14, color: LuxColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Folder name'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    await appState.createLibraryFolder(name.trim());
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LuxColors.surface,
        title: Text(title, style: LuxText.sora(size: 16, weight: FontWeight.w700)),
        content: Text(message, style: LuxText.manrope(size: 13, color: LuxColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: LuxColors.error)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteFolder(AppState appState, LibraryFolder folder) async {
    final ok = await _confirm('Delete "${folder.name}"?', 'Its assets move to All Assets — nothing is deleted.');
    if (!ok) return;
    if (_selectedFolderId == folder.id) setState(() => _selectedFolderId = null);
    await appState.deleteLibraryFolder(folder.id);
  }

  Future<void> _deleteAsset(AppState appState, LibraryAsset asset) async {
    final ok = await _confirm('Delete "${asset.filename}"?', 'This permanently removes the file from the library.');
    if (!ok) return;
    await appState.deleteLibraryAsset(asset.id);
  }

  Future<void> _useAsset(AppState appState, LibraryAsset asset) async {
    await appState.useLibraryAssetAsProject(asset.id);
    if (!mounted) return;
    Navigator.of(context).pushNamed(AppRoutes.analyse);
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return ColoredBox(
      color: LuxColors.background,
      child: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          final folders = appState.libraryFolders;
          final query = _query.trim().toLowerCase();
          final visibleAssets = appState.libraryAssets.where((a) {
            if (_selectedFolderId != null && a.folderId != _selectedFolderId) return false;
            if (query.isNotEmpty && !a.filename.toLowerCase().contains(query)) return false;
            return true;
          }).toList();

          return Column(
            children: [
              _Header(
                searchController: _searchController,
                onSearchChanged: (v) => setState(() => _query = v),
                onUpload: appState.isUploadingLibraryAsset ? null : () => _uploadMedia(appState),
                uploading: appState.isUploadingLibraryAsset,
              ),
              Expanded(
                child: appState.isLoadingLibrary
                    ? const Center(child: CircularProgressIndicator(color: LuxColors.gold))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (appState.libraryError != null) ...[
                              Text(friendlyError(appState.libraryError), style: LuxText.manrope(size: 12, color: LuxColors.error)),
                              const SizedBox(height: 16),
                            ],
                            const _SectionLabel('FOLDERS'),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _FolderChip(
                                  label: 'All Assets',
                                  count: appState.libraryAssets.length,
                                  selected: _selectedFolderId == null,
                                  onTap: () => setState(() => _selectedFolderId = null),
                                ),
                                for (final folder in folders)
                                  _FolderChip(
                                    label: folder.name,
                                    count: appState.libraryAssets.where((a) => a.folderId == folder.id).length,
                                    selected: _selectedFolderId == folder.id,
                                    onTap: () => setState(() => _selectedFolderId = folder.id),
                                    onDelete: () => _deleteFolder(appState, folder),
                                  ),
                                _NewFolderChip(onTap: () => _createFolder(appState)),
                              ],
                            ),
                            const SizedBox(height: 28),
                            _SectionLabel(_selectedFolderId == null ? 'ALL ASSETS' : 'FOLDER CONTENTS'),
                            const SizedBox(height: 12),
                            if (visibleAssets.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: Text(
                                    appState.libraryAssets.isEmpty
                                        ? 'No media yet — upload a sermon video to get started.'
                                        : 'No assets match here.',
                                    style: LuxText.manrope(size: 13, color: LuxColors.textSecondary),
                                  ),
                                ),
                              )
                            else
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 240,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: 0.82,
                                ),
                                itemCount: visibleAssets.length,
                                itemBuilder: (context, i) => _AssetCard(
                                  asset: visibleAssets[i],
                                  onUse: () => _useAsset(appState, visibleAssets[i]),
                                  onDelete: () => _deleteAsset(appState, visibleAssets[i]),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
              _QuotaFooter(usedBytes: appState.libraryUsedBytes, limitBytes: appState.libraryLimitBytes, assetCount: appState.libraryAssets.length),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onUpload;
  final bool uploading;

  const _Header({
    required this.searchController,
    required this.onSearchChanged,
    required this.onUpload,
    required this.uploading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: LuxColors.border))),
      child: Row(
        children: [
          Text('Media Library', style: LuxText.manrope(size: 15.5, weight: FontWeight.w700)),
          const Spacer(),
          SizedBox(
            width: 240,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              style: LuxText.manrope(size: 13, color: LuxColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: LuxColors.surfaceRaised,
                hintText: 'Search assets…',
                hintStyle: LuxText.manrope(size: 13, color: LuxColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, size: 17, color: LuxColors.textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onUpload,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  gradient: onUpload == null ? null : LuxColors.goldGradient,
                  color: onUpload == null ? LuxColors.surfaceRaised : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (uploading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: LuxColors.background),
                      )
                    else
                      Icon(Icons.add_rounded, size: 16, color: onUpload == null ? LuxColors.textMuted : LuxColors.background),
                    const SizedBox(width: 7),
                    Text(
                      uploading ? 'Uploading…' : 'Upload Media',
                      style: LuxText.manrope(
                        size: 13,
                        weight: FontWeight.w700,
                        color: onUpload == null ? LuxColors.textMuted : LuxColors.background,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label, style: LuxText.manrope(size: 10.5, weight: FontWeight.w700, color: LuxColors.textMuted, letterSpacing: 1));
  }
}

class _FolderChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _FolderChip({required this.label, required this.count, required this.selected, required this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LuxColors.surfaceRaised.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? LuxColors.gold.withValues(alpha: 0.6) : LuxColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_rounded, size: 18, color: LuxColors.gold),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: LuxText.manrope(size: 13, weight: FontWeight.w600, color: LuxColors.textPrimary)),
                  Text('$count item${count == 1 ? '' : 's'}', style: LuxText.manrope(size: 9.5, color: LuxColors.textMuted)),
                ],
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: onDelete,
                  child: const Icon(Icons.close_rounded, size: 14, color: LuxColors.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NewFolderChip extends StatelessWidget {
  final VoidCallback onTap;
  const _NewFolderChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: LuxColors.borderDashed),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 15, color: LuxColors.textSecondary),
              const SizedBox(width: 6),
              Text('New Folder', style: LuxText.manrope(size: 12.5, weight: FontWeight.w700, color: LuxColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  final LibraryAsset asset;
  final VoidCallback onUse;
  final VoidCallback onDelete;

  const _AssetCard({required this.asset, required this.onUse, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LuxColors.surface,
        border: Border.all(color: LuxColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: LuxColors.playerSurface),
                Center(
                  child: Text('LUX', style: LuxText.sora(size: 26, weight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.14))),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: LuxColors.gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.movie_creation_outlined, size: 13, color: LuxColors.gold),
                  ),
                ),
                if (asset.duration > Duration.zero)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(4)),
                      child: Text(asset.durationLabel, style: LuxText.manrope(size: 10, weight: FontWeight.w700, color: LuxColors.textPrimary)),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(asset.filename, maxLines: 1, overflow: TextOverflow.ellipsis, style: LuxText.manrope(size: 12, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${asset.sizeLabel} • MP4',
                        style: LuxText.manrope(size: 10, weight: FontWeight.w500, color: LuxColors.textSecondary),
                      ),
                    ),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert_rounded, size: 16, color: LuxColors.textSecondary),
                      color: LuxColors.surfaceRaised,
                      onSelected: (value) => value == 'use' ? onUse() : onDelete(),
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'use', child: Text('Use for New Project')),
                        PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: LuxColors.error))),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuotaFooter extends StatelessWidget {
  final int usedBytes;
  final int limitBytes;
  final int assetCount;

  const _QuotaFooter({required this.usedBytes, required this.limitBytes, required this.assetCount});

  String _fmtGb(int bytes) => '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';

  @override
  Widget build(BuildContext context) {
    final fraction = limitBytes == 0 ? 0.0 : (usedBytes / limitBytes).clamp(0.0, 1.0);

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: LuxColors.border))),
      child: Row(
        children: [
          Text(
            'Storage: ${_fmtGb(usedBytes)} / ${_fmtGb(limitBytes)}',
            style: LuxText.manrope(size: 10, weight: FontWeight.w700, color: LuxColors.textMuted, letterSpacing: 0.5),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 128,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: LuxColors.surfaceRaised,
                color: LuxColors.gold,
              ),
            ),
          ),
          const Spacer(),
          Text(
            '$assetCount Total Asset${assetCount == 1 ? '' : 's'}',
            style: LuxText.manrope(size: 10, color: LuxColors.textMuted),
          ),
        ],
      ),
    );
  }
}
