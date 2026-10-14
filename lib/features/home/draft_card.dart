import 'package:flutter/material.dart';

import '../../core/relative_time.dart';
import '../../domain/models.dart';
import '../../domain/month_names.dart';
import '../../templates/poster_template.dart';
import '../../templates/registry.dart';
import '../preview/poster_thumbnail.dart';

/// `جمادى الأول 1448` — one line, unlike [MonthPoster.hijriHeader].
String posterTitle(MonthPoster p) {
  final i = p.hijriMonthIndex;
  if (i < 0 || i >= hijriMonthsAr.length) return '${p.hijriYear}';
  return '${hijriMonthsAr[i]} ${p.hijriYear}';
}

enum DraftAction { edit, duplicate, delete }

/// Inner padding around the thumbnail inside a card.
const kDraftThumbPadding = 10.0;

/// Height the home grid reserves for the text under the thumbnail in a tile
/// [tileWidth] wide, so the thumbnail keeps its poster ratio. The card's
/// footer takes its natural height and the thumbnail absorbs any difference,
/// so an estimate that is slightly off never overflows.
double draftCardFooterHeight(TextScaler scaler, double tileWidth) {
  // The title may wrap to two lines when text is enlarged or tiles are
  // narrow, so the year is never cut off.
  final titleLines = scaler.scale(1) > 1.05 || tileWidth < 160 ? 2 : 1;
  // Title (14) + template line + last-edit line (12 each) with generous line
  // heights + paddings; never below the 48dp menu button + padding.
  final text =
      titleLines * scaler.scale(14) * 1.7 + 2 * scaler.scale(12) * 1.7 + 22;
  return text < 64 ? 64 : text;
}

/// One draft in the home grid: cached raster thumbnail ([PosterThumbnail]), title, template name
/// with last-edit time, and an overflow menu.
class DraftCard extends StatefulWidget {
  const DraftCard({super.key, required this.poster, required this.onAction});

  final MonthPoster poster;
  final ValueChanged<DraftAction> onAction;

  @override
  State<DraftCard> createState() => _DraftCardState();
}

class _DraftCardState extends State<DraftCard> {
  late Widget _thumb;

  @override
  void initState() {
    super.initState();
    _thumb = _Thumbnail(poster: widget.poster);
  }

  @override
  void didUpdateWidget(DraftCard old) {
    super.didUpdateWidget(old);
    // Reusing the same widget instance lets Flutter skip rebuilding the
    // (expensive) poster when only unrelated state changed.
    if (!identical(old.poster, widget.poster)) {
      _thumb = _Thumbnail(poster: widget.poster);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final p = widget.poster;
    final title = posterTitle(p);
    final PosterTemplate template = templateById(p.templateId);
    final edited = relativeTimeAr(p.updatedAt, DateTime.now());

    return Semantics(
      container: true,
      label: 'تقويم $title',
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: cs.surfaceContainerLowest,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: InkWell(
          onTap: () => widget.onAction(DraftAction.edit),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ColoredBox(
                  color: cs.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(kDraftThumbPadding),
                    child: Center(child: _thumb),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 2, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            _MetaLine(text: template.nameAr),
                            _MetaLine(
                              text: edited,
                              icon: Icons.history_rounded,
                            ),
                          ],
                        ),
                      ),
                      _Menu(title: title, onSelected: widget.onAction),
                    ],
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

/// A small secondary line under the title (template name / last edit).
/// Kept on separate lines so nothing is cut off in narrow phone tiles.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.text, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: color,
      fontSize: 12,
    );
    final label = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    if (icon == null) return label;
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(child: label),
      ],
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.title, required this.onSelected});
  final String title;
  final ValueChanged<DraftAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    PopupMenuItem<DraftAction> item(
      DraftAction a,
      IconData icon,
      String label, {
      Color? color,
    }) => PopupMenuItem(
      value: a,
      height: 48,
      child: Row(
        children: [
          Icon(icon, size: 22, color: color ?? cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Flexible(
            child: Text(label, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
    return PopupMenuButton<DraftAction>(
      tooltip: 'خيارات تقويم $title',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: onSelected,
      itemBuilder: (_) => [
        item(DraftAction.edit, Icons.edit_outlined, 'تعديل'),
        item(DraftAction.duplicate, Icons.copy_all_outlined, 'نسخ كشهر تالٍ'),
        const PopupMenuDivider(),
        item(
          DraftAction.delete,
          Icons.delete_outline_rounded,
          'حذف',
          color: cs.error,
        ),
      ],
    );
  }
}

/// The poster scaled down, at a fixed 1000:2200 ratio, with rounded corners
/// and a soft shadow. Isolated in a [RepaintBoundary]. Drawn from a cached
/// low-resolution raster, so the Home grid never lays out live posters.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.poster});
  final MonthPoster poster;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: kPosterSize.width / kPosterSize.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: ExcludeSemantics(
              child: Hero(
                tag: posterHeroTag(poster.id),
                flightShuttleBuilder: posterHeroShuttle(poster),
                child: PosterThumbnail(poster: poster),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
