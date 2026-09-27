import 'package:flutter/material.dart';

import '../../../core/ff_constants.dart';
import '../../../core/ff_format.dart';
import '../../../design/ff_colors.dart';
import '../../../design/ff_theme.dart';
import '../../../design/ff_tokens.dart';
import '../../../design/ff_typography.dart';

/// The block being edited, before it reaches the repository.
class BlockDraft {
  const BlockDraft({
    this.name = '',
    this.description = '',
    this.durationMin = 25,
    this.category = 0,
    this.trackEnabled = false,
    this.startMin,
    this.deleted = false,
  });

  final String name;
  final String description;
  final int durationMin;
  final int category;
  final bool trackEnabled;

  /// Null means "run straight after the previous block".
  final int? startMin;

  final bool deleted;
}

class BlockEditorSheet extends StatefulWidget {
  const BlockEditorSheet({super.key, this.initial, this.allowDelete = false});

  final BlockDraft? initial;
  final bool allowDelete;

  @override
  State<BlockEditorSheet> createState() => _BlockEditorSheetState();
}

class _BlockEditorSheetState extends State<BlockEditorSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late final TextEditingController _desc = TextEditingController(
    text: widget.initial?.description ?? '',
  );

  late int _duration = widget.initial?.durationMin ?? 25;
  late int _category = widget.initial?.category ?? 0;
  late bool _track = widget.initial?.trackEnabled ?? false;
  late int? _startMin = widget.initial?.startMin;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final valid = _name.text.trim().isNotEmpty && _duration > 0;

    return Padding(
      padding: EdgeInsets.only(
        left: FfSpace.gutter,
        right: FfSpace.gutter,
        top: FfSpace.sm,
        bottom: MediaQuery.viewInsetsOf(context).bottom + FfSpace.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.initial == null ? 'New block' : 'Edit block',
              style: FfType.titleMedium.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: FfSpace.lg),

            // The 16/24 limits are the firmware struct widths, not a style
            // choice — so the counter is always visible rather than appearing
            // only once the user has already overrun.
            TextField(
              controller: _name,
              autofocus: widget.initial == null,
              maxLength: FfFirmware.blockNameMaxChars,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Deep Work 1',
                helperText: 'Shown large on the bot screen',
              ),
            ),
            const SizedBox(height: FfSpace.sm),
            TextField(
              controller: _desc,
              maxLength: FfFirmware.blockDescMaxChars,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Math + Physics',
              ),
            ),

            const SizedBox(height: FfSpace.lg),
            _Label('Category'),
            const SizedBox(height: FfSpace.sm),
            Wrap(
              spacing: FfSpace.sm,
              runSpacing: FfSpace.sm,
              children: <Widget>[
                for (final c in FfCategory.values)
                  _CategoryOption(
                    category: c,
                    selected: c.id == _category,
                    onTap: () => setState(() => _category = c.id),
                  ),
              ],
            ),

            const SizedBox(height: FfSpace.xl),
            _Label('Duration'),
            const SizedBox(height: FfSpace.sm),
            Row(
              children: <Widget>[
                _StepButton(
                  icon: Icons.remove_rounded,
                  onTap: () => setState(
                    () => _duration = (_duration - 5).clamp(1, 1440),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      FfFormat.minutes(_duration),
                      style: FfType.countdownMd.copyWith(color: p.textPrimary),
                    ),
                  ),
                ),
                _StepButton(
                  icon: Icons.add_rounded,
                  onTap: () => setState(
                    () => _duration = (_duration + 5).clamp(1, 1440),
                  ),
                ),
              ],
            ),
            const SizedBox(height: FfSpace.sm),
            Wrap(
              spacing: FfSpace.sm,
              children: <Widget>[
                for (final m in <int>[15, 25, 45, 52, 90, 105])
                  ActionChip(
                    label: Text('${m}m'),
                    onPressed: () => setState(() => _duration = m),
                  ),
              ],
            ),

            const SizedBox(height: FfSpace.xl),
            SwitchListTile(
              value: _track,
              onChanged: (v) => setState(() => _track = v),
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Track this block',
                style: FfType.titleSmall.copyWith(color: p.textPrimary),
              ),
              subtitle: Text(
                _track
                    ? 'Minutes only count while verification holds. '
                          'The gap between verified and claimed is the point.'
                    : 'A plain timer. Honest, just not evidence.',
                style: FfType.caption.copyWith(color: p.textMuted),
              ),
            ),

            const SizedBox(height: FfSpace.md),
            SwitchListTile(
              value: _startMin != null,
              onChanged: (v) => setState(() => _startMin = v ? 8 * 60 : null),
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Fixed start time',
                style: FfType.titleSmall.copyWith(color: p.textPrimary),
              ),
              subtitle: Text(
                _startMin == null
                    ? 'Runs straight after the previous block'
                    : 'Starts at ${FfFormat.timeOfDay(_startMin!)}',
                style: FfType.caption.copyWith(color: p.textMuted),
              ),
            ),
            if (_startMin != null)
              Padding(
                padding: const EdgeInsets.only(top: FfSpace.sm),
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule_rounded, size: 16),
                  label: Text(FfFormat.timeOfDay(_startMin!)),
                ),
              ),

            const SizedBox(height: FfSpace.xl),
            Row(
              children: <Widget>[
                if (widget.allowDelete) ...<Widget>[
                  OutlinedButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(const BlockDraft(deleted: true)),
                    style: OutlinedButton.styleFrom(foregroundColor: p.broken),
                    child: const Text('Delete'),
                  ),
                  const SizedBox(width: FfSpace.sm),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: valid ? _save : null,
                    child: Text(widget.initial == null ? 'Add block' : 'Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final current = _startMin ?? 8 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked != null) {
      setState(() => _startMin = picked.hour * 60 + picked.minute);
    }
  }

  void _save() {
    Navigator.of(context).pop(
      BlockDraft(
        name: _name.text.trim(),
        description: _desc.text.trim(),
        durationMin: _duration,
        category: _category,
        trackEnabled: _track,
        startMin: _startMin,
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: FfType.overline.copyWith(color: context.ff.textMuted),
  );
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final FfCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    return Material(
      color: selected
          ? category.color.withValues(alpha: 0.18)
          : p.surfaceRaised,
      borderRadius: BorderRadius.circular(FfRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FfRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: FfSpace.md,
            vertical: FfSpace.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FfRadius.md),
            border: Border.all(
              color: selected ? category.color : p.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: category.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: FfSpace.sm),
              Text(
                category.label,
                style: FfType.caption.copyWith(
                  color: selected ? p.textPrimary : p.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    return Material(
      color: p.surfaceRaised,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: p.border),
          ),
          child: Icon(icon, size: 20, color: p.textPrimary),
        ),
      ),
    );
  }
}
