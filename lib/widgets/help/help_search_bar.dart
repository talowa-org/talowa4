// TALOWA Help Search Bar Widget
// Search interface for help articles

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class HelpSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSearch;
  final VoidCallback onClear;
  final bool isLoading;

  const HelpSearchBar({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onClear,
    this.isLoading = false,
  });

  @override
  State<HelpSearchBar> createState() => _HelpSearchBarState();
}

class _HelpSearchBarState extends State<HelpSearchBar> {
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      decoration: InputDecoration(
        hintText: 'Search help articles...',
        prefixIcon: widget.isLoading
            ? const Padding(
                padding: EdgeInsets.all(12.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.talowaGreen),
                  ),
                ),
              )
            : const Icon(Icons.search),
        suffixIcon: widget.controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: widget.onClear,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.talowaGreen),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      onChanged: (value) {
        setState(() {}); // Rebuild to show/hide clear button
        if (value.trim().isNotEmpty) {
          // Debounce search
          Future.delayed(const Duration(milliseconds: 500), () {
            if (widget.controller.text == value) {
              widget.onSearch(value);
            }
          });
        } else {
          widget.onSearch('');
        }
      },
      onSubmitted: widget.onSearch,
    );
  }
}
