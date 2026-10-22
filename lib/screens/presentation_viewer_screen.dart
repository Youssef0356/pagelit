import 'dart:io';
import 'package:flutter/material.dart';

import 'package:share_plus/share_plus.dart';

import '../services/presentation_parser.dart';


class PresentationViewerScreen extends StatefulWidget {
  const PresentationViewerScreen({
    super.key,
    required this.filePath,
    required this.title,
  });

  final String filePath;
  final String title;

  @override
  State<PresentationViewerScreen> createState() => _PresentationViewerScreenState();
}

class _PresentationViewerScreenState extends State<PresentationViewerScreen> {
  PresentationDeck? _deck;
  bool _isLoading = true;
  String? _error;
  int _currentSlideIndex = 0;
  final PageController _pageController = PageController();
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();
      final deck = await PresentationParser.parse(bytes);
      if (!mounted) return;
      setState(() {
        _deck = deck;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load presentation: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _shareFile() async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(widget.filePath)],
        title: widget.title,
      ),
    );
  }

  void _openSlideOverview() {
    if (_deck == null || _deck!.slides.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text('All Slides (${_deck!.slides.length})', style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _deck!.slides.length,
                  itemBuilder: (context, idx) {
                    final slide = _deck!.slides[idx];
                    final isCurrent = idx == _currentSlideIndex;
                    final scheme = Theme.of(context).colorScheme;
                    return InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        _pageController.jumpToPage(idx);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isCurrent ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCurrent ? scheme.primary : scheme.outlineVariant,
                            width: isCurrent ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Slide ${slide.slideNumber}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isCurrent ? scheme.onPrimaryContainer : scheme.outline,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: Text(
                                slide.title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.deepOrange.shade700,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'PPTX',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (_deck != null && _deck!.slides.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ActionChip(
                avatar: const Icon(Icons.grid_view_rounded, size: 16),
                label: Text('${_currentSlideIndex + 1} / ${_deck!.slides.length}'),
                onPressed: _openSlideOverview,
              ),
            ),
          IconButton(
            tooltip: 'Search',
            icon: Icon(_isSearchOpen ? Icons.search_off_rounded : Icons.search_rounded),
            onPressed: () => setState(() {
              _isSearchOpen = !_isSearchOpen;
              if (!_isSearchOpen) {
                _searchQuery = '';
                _searchController.clear();
              }
            }),
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_rounded),
            onPressed: _shareFile,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSearchOpen)
            Container(
              color: scheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search slide text...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          }),
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              ),
            ),
          Expanded(child: _buildBody()),
          if (_deck != null && _deck!.slides.length > 1) _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
              const SizedBox(height: 14),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadFile, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_deck == null || _deck!.slides.isEmpty) {
      return const Center(child: Text('This presentation has no slides.'));
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: _deck!.slides.length,
      onPageChanged: (idx) => setState(() => _currentSlideIndex = idx),
      itemBuilder: (context, index) {
        final slide = _deck!.slides[index];
        return _buildSlideCard(slide);
      },
    );
  }

  Widget _buildSlideCard(PresentationSlide slide) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Center(
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        slide.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${slide.slideNumber}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: scheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final point in slide.bulletPoints) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 8, top: 4),
                                  child: Icon(Icons.arrow_right_rounded, size: 18, color: scheme.primary),
                                ),
                                Expanded(
                                  child: SelectableText(
                                    point,
                                    style: TextStyle(fontSize: 14, height: 1.5, color: scheme.onSurface),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (slide.images.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: slide.images.map((img) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  img,
                                  height: 140,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    final hasPrev = _currentSlideIndex > 0;
    final hasNext = _deck != null && _currentSlideIndex < _deck!.slides.length - 1;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton.filledTonal(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: hasPrev ? () => _pageController.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut) : null,
            ),
            TextButton.icon(
              icon: const Icon(Icons.grid_view_rounded, size: 16),
              label: Text('Slide ${_currentSlideIndex + 1} of ${_deck!.slides.length}'),
              onPressed: _openSlideOverview,
            ),
            IconButton.filledTonal(
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onPressed: hasNext ? () => _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut) : null,
            ),
          ],
        ),
      ),
    );
  }
}

