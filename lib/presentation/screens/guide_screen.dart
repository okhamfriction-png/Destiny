import 'package:flutter/material.dart';

import '../../application/state/guide_content.dart';
import '../../application/state/visual_settings.dart';

const Color _ink = Color(0xFF0A0818);
const Color _bgTop = Color(0xFF141029);
const Color _bgBot = Color(0xFF0A0818);

// Style de base du corps (blanc ~88 %). Const : couleur ARGB directe.
const TextStyle _bodyStyle =
    TextStyle(color: Color(0xE0FFFFFF), height: 1.5, fontSize: 14.5);

/// Une couleur d'accent par section (cycle au-delà de 15).
const List<Color> _accents = [
  Color(0xFFFFC24B), // 1  or
  Color(0xFFB79CFF), // 2  violet
  Color(0xFF5EE0C4), // 3  teal
  Color(0xFF6FB7FF), // 4  ciel
  Color(0xFFFF9EC4), // 5  rose
  Color(0xFF8BE28B), // 6  vert
  Color(0xFFFF7A6B), // 7  corail (danger)
  Color(0xFFFFB067), // 8  ambre
  Color(0xFFC9A7FF), // 9  lilas
  Color(0xFF7FE0B0), // 10 menthe
  Color(0xFFFFD166), // 11 or cinéma
  Color(0xFF7FC7FF), // 12 bleu
  Color(0xFFFF9E80), // 13 pêche
  Color(0xFFA5D6A7), // 14 sauge
  Color(0xFFEF9A9A), // 15 rouge doux
];

Color _accentFor(int i) => _accents[i % _accents.length];

/// Encadrés sémantiques : mot-clé en tête de ligne → boîte colorée + icône.
/// Les plus spécifiques d'abord (RÈGLE ABSOLUE / RÈGLE D'OR avant RÈGLE).
class _Callout {
  const _Callout(this.key, this.icon, this.color);
  final String key;
  final IconData icon;
  final Color color;
}

const List<_Callout> _callouts = [
  _Callout('RÈGLE ABSOLUE', Icons.gpp_maybe_rounded, Color(0xFFFF8A80)),
  _Callout('RÈGLE D\'OR', Icons.star_rounded, Color(0xFFFFC24B)),
  _Callout('ATTENTION', Icons.warning_amber_rounded, Color(0xFFFF7A6B)),
  _Callout('LEÇON', Icons.lightbulb_rounded, Color(0xFF5EE0C4)),
  _Callout('NOTE', Icons.info_rounded, Color(0xFF6FB7FF)),
  _Callout('TEST', Icons.checklist_rounded, Color(0xFFB79CFF)),
  _Callout('RÈGLE', Icons.gavel_rounded, Color(0xFFFFC24B)),
];

/// Le Guide Destiny : manuel de référence navigable (sections dépliables).
/// Lecture seule pour tous ; éditable uniquement en mode admin.
class GuideScreen extends StatefulWidget {
  const GuideScreen({
    required this.guide,
    required this.visualSettings,
    super.key,
  });

  final GuideContent guide;
  final VisualSettings visualSettings;

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  @override
  void initState() {
    super.initState();
    widget.guide.addListener(_onChange);
    widget.visualSettings.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.guide.removeListener(_onChange);
    widget.visualSettings.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _edit(GuideSection s) async {
    final result =
        await Navigator.of(context).push<({String title, String body})>(
      MaterialPageRoute(builder: (_) => _GuideEditPage(section: s)),
    );
    if (result != null) {
      await widget.guide
          .updateSection(s.id, title: result.title, body: result.body);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final admin = widget.visualSettings.adminMode;
    final sections = widget.guide.sections;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guide Destiny'),
        actions: [
          if (admin)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: Chip(
                  label: Text('Admin'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBot],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 2, 6, 14),
              child: Text(
                'La référence complète pour jouer Destiny. '
                '${admin ? 'Mode admin : touche ✎ pour éditer une section.' : 'Lecture seule.'}',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
              ),
            ),
            for (var i = 0; i < sections.length; i++)
              _SectionCard(
                section: sections[i],
                accent: _accentFor(i),
                admin: admin,
                onEdit: () => _edit(sections[i]),
              ),
          ],
        ),
      ),
    );
  }
}

/// Carte d'une section : badge numéroté coloré, bordure d'accent, corps mis en
/// forme (voir [_GuideBody]).
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.accent,
    required this.admin,
    required this.onEdit,
  });

  final GuideSection section;
  final Color accent;
  final bool admin;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numMatch = RegExp(r'^\s*(\d+)').firstMatch(section.title);
    final number = numMatch?.group(1) ?? '';
    final title = section.title.replaceFirst(RegExp(r'^\s*\d+\.\s*'), '');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF171233).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          backgroundColor: accent.withValues(alpha: 0.05),
          collapsedBackgroundColor: Colors.transparent,
          iconColor: accent,
          collapsedIconColor: accent.withValues(alpha: 0.85),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: _NumberBadge(number: number, accent: accent),
          title: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          trailing: admin
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Éditer',
                      icon: Icon(Icons.edit, size: 20, color: accent),
                      onPressed: onEdit,
                    ),
                    Icon(Icons.expand_more, color: accent),
                  ],
                )
              : null,
          children: [
            // Filet dégradé sous le titre.
            Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.0)],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _GuideBody(body: section.body, accent: accent),
          ],
        ),
      ),
    );
  }
}

/// Badge carré-arrondi avec le numéro de section, en dégradé d'accent.
class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.number, required this.accent});
  final String number;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, accent.withValues(alpha: 0.55)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.40),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        number,
        style: const TextStyle(
          color: _ink,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    );
  }
}

/// Rendu enrichi du corps d'une section. Le contenu reste du texte simple
/// (éditable) ; ce widget l'interprète ligne par ligne pour lui donner de la
/// couleur et de la forme, sans jamais modifier la donnée stockée.
class _GuideBody extends StatelessWidget {
  const _GuideBody({required this.body, required this.accent});

  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final blocks = <Widget>[];
    for (final raw in body.split('\n')) {
      final t = raw.trim();
      if (t.isEmpty) {
        blocks.add(const SizedBox(height: 9));
        continue;
      }
      if (t.startsWith('━')) {
        blocks.add(_banner(t));
        continue;
      }
      if (t.startsWith('• ')) {
        blocks.add(_bullet(t.substring(2)));
        continue;
      }
      if (t.startsWith('– ') || t.startsWith('- ')) {
        blocks.add(_subdash(t.substring(2)));
        continue;
      }
      final callout = _matchCallout(t);
      if (callout != null) {
        blocks.add(_calloutBox(callout, t));
        continue;
      }
      if (_isChain(t)) {
        blocks.add(_chain(t));
        continue;
      }
      if (_isHeading(t)) {
        blocks.add(_heading(t));
        continue;
      }
      blocks.add(_paragraph(t));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  // ------------------------------------------------------------- classifieurs
  _Callout? _matchCallout(String t) {
    for (final c in _callouts) {
      if (t == c.key ||
          t.startsWith('${c.key} ') ||
          t.startsWith('${c.key}:')) {
        return c;
      }
    }
    return null;
  }

  bool _isChain(String t) {
    if (!t.contains('→')) return false;
    final letters = t.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
    return letters.length > 2 && letters.toUpperCase() == letters;
  }

  bool _isHeading(String t) {
    final letters = t.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
    if (letters.length >= 2 && letters.toUpperCase() == letters && t.length <= 48) {
      return true;
    }
    if (t.endsWith(':')) {
      final b = t.substring(0, t.length - 1);
      if (b.length <= 60 && !b.contains('. ') && !b.contains(';')) return true;
    }
    return false;
  }

  bool _isCaps(String w) {
    final letters = w.replaceAll(RegExp(r'[^A-Za-zÀ-ÿŒœÆæ]'), '');
    if (letters.length < 2) return false;
    if (letters.toLowerCase() == letters) return false;
    return letters.toUpperCase() == letters;
  }

  // ------------------------------------------------------------------ blocs
  Widget _banner(String t) {
    final text = t.replaceAll('━', '').trim();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 2, bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB79CFF), Color(0xFFFFC24B)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.movie_filter_rounded, size: 18, color: _ink),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                letterSpacing: 0.8,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heading(String t) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 16,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Text(
              t,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
                letterSpacing: 0.3,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chain(String t) {
    final parts = t
        .split('→')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final chips = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      chips.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: accent.withValues(alpha: 0.5)),
        ),
        child: Text(
          parts[i],
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
          ),
        ),
      ));
      if (i < parts.length - 1) {
        chips.add(Icon(Icons.arrow_right_alt_rounded,
            size: 18, color: accent.withValues(alpha: 0.8)));
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: chips,
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(top: 7, right: 10),
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          Expanded(
            child: SelectableText.rich(
              TextSpan(children: _inline(text, bold: true)),
              style: _bodyStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _subdash(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1, right: 8),
            child: Text('–',
                style: TextStyle(color: accent, fontWeight: FontWeight.w800)),
          ),
          Expanded(
            child: SelectableText.rich(
              TextSpan(children: _inline(text, bold: false)),
              style: _bodyStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paragraph(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SelectableText.rich(
        TextSpan(children: _inline(t, bold: false)),
        style: _bodyStyle,
      ),
    );
  }

  Widget _calloutBox(_Callout c, String t) {
    String label;
    String rest;
    final idx = t.indexOf(':');
    if (idx > 0) {
      label = t.substring(0, idx).trim();
      rest = t.substring(idx + 1).trim();
    } else {
      label = c.key;
      rest = t.length > c.key.length ? t.substring(c.key.length).trim() : '';
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 7),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: c.color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: c.color, width: 3),
          top: BorderSide(color: c.color.withValues(alpha: 0.18)),
          right: BorderSide(color: c.color.withValues(alpha: 0.18)),
          bottom: BorderSide(color: c.color.withValues(alpha: 0.18)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(c.icon, size: 18, color: c.color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: SelectableText.rich(
              TextSpan(children: [
                TextSpan(
                  text: label.toUpperCase(),
                  style: TextStyle(
                    color: c.color,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                if (rest.isNotEmpty) const TextSpan(text: '  '),
                ..._inline(rest, bold: false),
              ]),
              style: _bodyStyle,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- style en ligne
  /// Colore les jetons remarquables (→ ✓ ✗ ·) et met en gras les mots en
  /// CAPITALES. Pour les puces, met aussi en avant le libellé de tête.
  List<InlineSpan> _inline(String text, {required bool bold}) {
    final spans = <InlineSpan>[];
    var rest = text;

    if (bold) {
      final m = RegExp(r'^(.{2,42}?)(\s—\s|\s:\s|\s\()').firstMatch(text);
      if (m != null) {
        spans.add(TextSpan(
          text: m.group(1),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700),
        ));
        rest = text.substring(m.group(1)!.length);
      }
    }

    final words = rest.split(' ');
    for (var i = 0; i < words.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: ' '));
      final w = words[i];
      if (w.isEmpty) continue;
      if (w.startsWith('→')) {
        spans.add(TextSpan(
            text: w,
            style: TextStyle(color: accent, fontWeight: FontWeight.w800)));
      } else if (w.startsWith('✓')) {
        spans.add(TextSpan(
            text: w,
            style: const TextStyle(
                color: Color(0xFF7BE38A), fontWeight: FontWeight.w800)));
      } else if (w.startsWith('✗')) {
        spans.add(TextSpan(
            text: w,
            style: const TextStyle(
                color: Color(0xFFFF7A6B), fontWeight: FontWeight.w800)));
      } else if (w == '·') {
        spans.add(const TextSpan(
            text: '·', style: TextStyle(color: Color(0x59FFFFFF))));
      } else if (_isCaps(w)) {
        spans.add(TextSpan(
            text: w,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)));
      } else {
        spans.add(TextSpan(text: w));
      }
    }
    return spans;
  }
}

/// Éditeur plein écran d'une section du Guide (admin uniquement).
class _GuideEditPage extends StatefulWidget {
  const _GuideEditPage({required this.section});
  final GuideSection section;

  @override
  State<_GuideEditPage> createState() => _GuideEditPageState();
}

class _GuideEditPageState extends State<_GuideEditPage> {
  late final TextEditingController _title =
      TextEditingController(text: widget.section.title);
  late final TextEditingController _body =
      TextEditingController(text: widget.section.body);

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Éditer la section'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
                context, (title: _title.text.trim(), body: _body.text)),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBot],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Titre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _body,
              maxLines: null,
              minLines: 12,
              decoration: const InputDecoration(
                labelText: 'Contenu',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
