import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../app/app_widgets.dart';
import '../../../core/database/app_database.dart';
import '../../../core/formatting/date_timestamp.dart';
import '../../../core/formatting/money_formatter.dart';
import '../data/khata_repository.dart';

/// Lent money is owed to you (positive); borrowed money is owed by you.
Color khataDirectionColor(BuildContext context, String direction) {
  final scheme = Theme.of(context).colorScheme;
  return direction == khataLent ? scheme.positiveText : scheme.negativeText;
}

String khataDirectionLabel(String direction) =>
    direction == khataLent ? 'You gave' : 'You got';

IconData khataDirectionIcon(String direction) => direction == khataLent
    ? Icons.north_east_rounded
    : Icons.south_west_rounded;

Color personColor(KhataPersonRow person) => person.colorValue == null
    ? AppColors.pickerPalette[person.name.codeUnits.fold<int>(
            0,
            (sum, unit) => sum + unit,
          ) %
          AppColors.pickerPalette.length]
    : Color(person.colorValue!);

int todayUtcDate() {
  final now = DateTime.now();
  return DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch;
}

bool isOverdue(KhataEntryItem item) =>
    !item.isSettled &&
    item.entry.dueDate != null &&
    item.entry.dueDate! < todayUtcDate();

class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    required this.name,
    required this.color,
    super.key,
    this.size = 40,
    this.foreground,
  });

  final String name;
  final Color color;
  final double size;

  /// Initials colour; defaults to whichever of black or white reads on [color].
  final Color? foreground;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first.characters.first;
    final second = parts.length > 1 ? parts.last.characters.first : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color, Color.lerp(color, Colors.white, .28)!],
      ),
    ),
    child: Text(
      _initials,
      style: AppTypography.button.copyWith(
        color: foreground ?? readableOn(Color.lerp(color, Colors.white, .14)!),
        fontSize: size * .34,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

/// "You'll get ₹X", "You'll give ₹X" or "Settled" for a net position.
class NetPositionLabel extends StatelessWidget {
  const NetPositionLabel({
    required this.netPaise,
    required this.hidden,
    super.key,
    this.alignEnd = true,
  });

  final int netPaise;
  final bool hidden;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (netPaise == 0) {
      return StatusPill(label: 'Settled', color: scheme.onSurfaceVariant);
    }
    final get = netPaise > 0;
    final color = get ? scheme.positiveText : scheme.negativeText;
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AmountText(
          hidden
              ? hiddenAmountMask
              : MoneyFormatter.formatPaise(netPaise.abs()),
          color: color,
        ),
        Text(
          get ? "You'll get" : "You'll give",
          style: AppTypography.metadata.copyWith(color: color),
        ),
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    required this.color,
    super.key,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
        ],
        Text(
          label,
          style: AppTypography.metadata.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class RepaymentProgressBar extends StatelessWidget {
  const RepaymentProgressBar({
    required this.repaid,
    required this.total,
    required this.color,
    super.key,
    this.height = 5,
  });

  final int repaid;
  final int total;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final progress = total <= 0 ? 0.0 : (repaid / total).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(height: height, color: color.withValues(alpha: .15)),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => FractionallySizedBox(
              widthFactor: value,
              child: Container(height: height, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ledger row used on Person Details and the MyKhata activity list.
class KhataEntryTile extends StatelessWidget {
  const KhataEntryTile({
    required this.item,
    required this.hidden,
    required this.onTap,
    super.key,
    this.showPerson = false,
  });

  final KhataEntryItem item;
  final bool hidden;
  final VoidCallback onTap;
  final bool showPerson;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entry = item.entry;
    final color = khataDirectionColor(context, entry.direction);
    final title = showPerson
        ? item.personName
        : (entry.note?.isNotEmpty == true
              ? entry.note!
              : khataDirectionLabel(entry.direction));
    final overdue = isOverdue(item);
    // One spoken item per row: name, amounts and status together.
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 4,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(AppRadius.sm + 4),
                ),
                child: Icon(
                  item.isSettled
                      ? Icons.check_rounded
                      : khataDirectionIcon(entry.direction),
                  color: item.isSettled ? scheme.onSurfaceVariant : color,
                  size: 19,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.fieldValue.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${khataDirectionLabel(entry.direction)} · ${DateOnly.format(entry.entryDate)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.metadata.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (!item.isSettled && item.repaidPaise > 0) ...[
                      const SizedBox(height: 6),
                      RepaymentProgressBar(
                        repaid: item.repaidPaise,
                        total: entry.amountPaise,
                        color: color,
                        height: 4,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AmountText(
                      hidden
                          ? hiddenAmountMask
                          : MoneyFormatter.formatPaise(entry.amountPaise),
                      color: item.isSettled ? scheme.onSurfaceVariant : color,
                    ),
                    const SizedBox(height: 3),
                    if (item.isSettled)
                      StatusPill(
                        label: 'Settled',
                        color: scheme.onSurfaceVariant,
                        icon: Icons.check_rounded,
                      )
                    else if (overdue)
                      StatusPill(
                        label: 'Overdue',
                        color: scheme.negativeText,
                        icon: Icons.schedule_rounded,
                      )
                    else if (item.repaidPaise > 0)
                      Text(
                        hidden
                            ? 'Due $hiddenAmountMask'
                            : '${MoneyFormatter.formatPaise(item.outstandingPaise)} left',
                        semanticsLabel: hidden ? 'Due amount hidden' : null,
                        style: AppTypography.metadata.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
