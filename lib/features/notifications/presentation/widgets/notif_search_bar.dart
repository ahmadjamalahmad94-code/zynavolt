import 'package:flutter/material.dart';

import '../../../../core/design/zyn_tokens.dart';

/// v102 DS v1 — Search row for the Notifications screen.
///
/// Two pieces, side-by-side:
///   * a square "filter" button on the leading edge that opens the
///     filter sheet (read/unread + bucket scope), and
///   * a rounded search field with a leading search icon, a
///     placeholder "ابحث في الإشعارات…", and an "AI sparkle" icon
///     at the trailing edge that hints at the smart-suggestion
///     feature without claiming a feature we don't ship yet.
///
/// The search field's `onChanged` is debounced upstream; this widget
/// just relays raw text changes via [onQueryChanged].
class NotifSearchBar extends StatelessWidget {
  const NotifSearchBar({
    super.key,
    required this.query,
    required this.onQueryChanged,
    required this.onFilterTap,
    this.filtersActive = false,
  });

  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onFilterTap;
  final bool filtersActive;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _FilterButton(active: filtersActive, onTap: onFilterTap),
        const SizedBox(width: ZynSpacing.sm),
        Expanded(
          child: _SearchField(query: query, onQueryChanged: onQueryChanged),
        ),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ZynRadii.inner),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZynRadii.inner),
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ZynColors.surface,
            borderRadius: BorderRadius.circular(ZynRadii.inner),
            border: Border.all(
              color: active ? ZynColors.primary500 : ZynColors.line,
              width: active ? 1.4 : 1,
            ),
            boxShadow: ZynShadows.soft(),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 20,
                color: active ? ZynColors.primary700 : ZynColors.muted,
              ),
              if (active)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: ZynColors.primary500,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ZynColors.surface,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({required this.query, required this.onQueryChanged});

  final String query;
  final ValueChanged<String> onQueryChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.query);

  @override
  void didUpdateWidget(covariant _SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _ctrl.text) {
      _ctrl.text = widget.query;
      _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.inner),
        border: Border.all(color: ZynColors.line, width: 1),
        boxShadow: ZynShadows.soft(),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(
            Icons.auto_awesome_rounded,
            size: 16,
            color: ZynColors.accent,
          ),
          const SizedBox(width: 6),
          Container(
            width: 1,
            height: 20,
            color: ZynColors.line,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _ctrl,
              onChanged: widget.onQueryChanged,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(
                color: ZynColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
                hintText: 'ابحث في الإشعارات…',
                hintStyle: TextStyle(
                  color: ZynColors.faint,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          const Icon(
            Icons.search_rounded,
            size: 20,
            color: ZynColors.muted,
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}
