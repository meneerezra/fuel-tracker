import 'package:flutter/material.dart';

/// Search bar with an X to clear it. Pressing back while searching clears the
/// search instead of leaving the page.
class SearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  const SearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Rebuild when the parent clears the search, for example on tab change.
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  void _clear() {
    widget.controller.clear();
    _focusNode.unfocus();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final searching = widget.controller.text.isNotEmpty;

    return PopScope(
      canPop: !searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clear();
      },
      child: SearchBar(
        controller: widget.controller,
        focusNode: _focusNode,
        hintText: widget.hintText,
        leading: const Icon(Icons.search),
        trailing: [
          if (searching)
            IconButton(
              tooltip: 'Clear search',
              icon: const Icon(Icons.close),
              onPressed: _clear,
            ),
        ],
        elevation: const WidgetStatePropertyAll(0),
        onChanged: widget.onChanged,
      ),
    );
  }
}
