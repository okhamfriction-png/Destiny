import 'dart:convert';

import '../../domain/entities/chat_message.dart';
import '../services/llm_service.dart';
import '../state/ai_settings.dart';

// Ce module est la SEULE porte par laquelle des paroles quittent l'appareil.
// Il ne connaît que : l'univers, le ton, le contexte écrit par le maître du
// jeu, les textes du méchant et du registre, et la transcription qu'il a vue
// et validée. Jamais un prénom d'enfant, jamais rien sur les joueurs : il ne
// parle que des personnages. Un test scanne ce dossier pour le vérifier.

/// Remplace chaque prénom par son rôle : mot entier uniquement, insensible à la
/// casse, en Unicode. « Naël » dans « Naelle » ne désigne pas l'enfant et n'est
/// pas touché.
String sansPrenoms(String transcription, Map<String, String> rolesParPrenom) {
  var texte = transcription;
  for (final entry in rolesParPrenom.entries) {
    final prenom = entry.key.trim();
    if (prenom.isEmpty) continue;
    final motif = RegExp(
      '(?<![\\p{L}\\p{N}])${RegExp.escape(prenom)}(?![\\p{L}\\p{N}])',
      unicode: true,
      caseSensitive: false,
    );
    texte = texte.replaceAll(motif, entry.value);
  }
  return texte;
}

/// Une entrée du registre proposée par l'IA (du texte, rien d'autre).
class NoteRegistre {
  const NoteRegistre({
    required this.categorie,
    required this.nom,
    this.detail = '',
    this.statut = '',
    this.liens = const [],
  });

  final String categorie;
  final String nom;
  final String detail;
  final String statut;
  final List<String> liens;

  /// La même entrée, prénoms remplacés par les rôles.
  NoteRegistre sansPrenoms(Map<String, String> rolesParPrenom) {
    String n(String s) => _sansPrenoms(s, rolesParPrenom);
    return NoteRegistre(
      categorie: categorie,
      nom: n(nom),
      detail: n(detail),
      statut: statut,
      liens: [for (final l in liens) n(l)],
    );
  }

  static NoteRegistre? depuis(Object? brut) {
    if (brut is! Map) return null;
    String s(Object? v) => (v ?? '').toString().trim();
    final nom = s(brut['nom']);
    if (nom.isEmpty) return null;
    return NoteRegistre(
      categorie: s(brut['categorie']),
      nom: nom,
      detail: s(brut['detail']),
      statut: s(brut['statut']),
      liens: [for (final l in (brut['liens'] as List? ?? const [])) '$l'.trim()],
    );
  }
}

String _sansPrenoms(String t, Map<String, String> r) => sansPrenoms(t, r);

/// Lit le premier objet JSON d'une réponse (un modèle peut l'entourer de
/// texte). Rend null s'il n'y en a pas.
Map<String, dynamic>? _objetJson(String reponse) {
  final debut = reponse.indexOf('{');
  final fin = reponse.lastIndexOf('}');
  if (debut < 0 || fin <= debut) return null;
  try {
    return Map<String, dynamic>.from(jsonDecode(reponse.substring(debut, fin + 1)) as Map);
  } catch (_) {
    return null;
  }
}

/// Le résumé, l'accroche et les entrées du registre tirés de la réponse du
/// modèle.
class MemoireEpisode {
  const MemoireEpisode({this.resume = '', this.suite = '', this.registre = const []});
  final String resume;
  final String suite;
  final List<NoteRegistre> registre;

  /// Lecture tolérante : on cherche le premier `{` et le dernier `}`. Un modèle
  /// qui répond en texte brut ne doit pas faire perdre le résumé — on garde
  /// alors tout comme résumé, l'accroche reste vide.
  factory MemoireEpisode.depuis(String reponse) {
    final map = _objetJson(reponse);
    if (map != null) {
      return MemoireEpisode(
        resume: (map['resume'] ?? '').toString().trim(),
        suite: (map['suite'] ?? '').toString().trim(),
        registre: [
          for (final e in (map['registre'] as List? ?? const []))
            if (NoteRegistre.depuis(e) case final n?) n,
        ],
      );
    }
    return MemoireEpisode(resume: reponse.trim());
  }

  /// La même mémoire, prénoms remplacés partout (au cas où le modèle en
  /// répéterait un).
  MemoireEpisode sansPrenoms(Map<String, String> rolesParPrenom) => MemoireEpisode(
        resume: _sansPrenoms(resume, rolesParPrenom),
        suite: _sansPrenoms(suite, rolesParPrenom),
        registre: [for (final n in registre) n.sansPrenoms(rolesParPrenom)],
      );
}

/// Une entrée du registre que l'IA propose de ressortir.
class Ressorti {
  const Ressorti({required this.numero, this.comment = ''});

  /// Le numéro de l'entrée dans la liste envoyée (à partir de 1).
  final int numero;

  /// Comment la ressortir, en une phrase.
  final String comment;
}

const String _reglesCommunes =
    'Tu ne commentes ni le jeu ni les joueurs : tu ne parles que des personnages. '
    'Aucun jugement, aucune note, aucun conseil. Tu n\'écris jamais un prénom de '
    'joueur. Tu réponds uniquement par un objet JSON, sans texte autour.';

const String _consigneEnfant =
    'Tu suis une histoire de théâtre improvisée entre un parent et ses enfants, '
    'en français. Aucune violence, aucune mort, aucun personnage humilié : des '
    'frissons doux, jamais d\'effroi. Un personnage ne meurt pas, il quitte '
    'l\'histoire. $_reglesCommunes';

const String _consigneAdulte =
    'Tu suis une histoire de théâtre improvisée entre adultes, en français. '
    'Reste respectueux, sans complaisance gratuite. $_reglesCommunes';

const String _formatResume =
    ' Forme : {"resume": "...", "suite": "..."}. '
    '"resume" : au plus six phrases courtes, au passé, à la troisième personne, '
    'sur ce qui est arrivé aux personnages. '
    '"suite" : deux phrases au présent qui disent où l\'on reprend et ce que le '
    'méchant a fait depuis — de quoi commencer à jouer sans relire.';

String _formatRegistre(List<String> categories, {required bool kids}) =>
    ' Forme : {"resume": "...", "suite": "...", "registre": [{"categorie": "...", '
    '"nom": "...", "detail": "...", "statut": "présent | parti | tombé | retourné", '
    '"liens": ["..."]}]}. '
    '"resume" : au plus six phrases courtes, au passé, à la troisième personne, '
    'sur ce qui est arrivé aux personnages. '
    '"suite" : deux phrases au présent qui disent où l\'on reprend et ce que le '
    'méchant a fait depuis. '
    '"registre" : la mémoire de la série, ce qu\'on pourra ressortir plus tard. '
    'Une entrée par figurant, sbire, objet, lieu et sa sortie, secret, promesse '
    '${kids ? '' : 'ou mort '}apparu dans l\'épisode, en une phrase de détail. '
    '"categorie" est l\'un de : ${categories.join(', ')}. '
    '${kids ? 'Il n\'y a jamais de mort : un personnage qui quitte l\'histoire a le statut « parti ». ' : ''}'
    'Au plus huit entrées. Jamais rien sur les joueurs.';

/// Demande à l'IA un résumé, une accroche, les entrées du registre, les
/// présages d'un méchant et ce qu'il faut ressortir, à partir du seul
/// contexte validé.
class CampagneAssistant {
  const CampagneAssistant(this._llm);
  final LlmService _llm;

  String _entete({
    required String univers,
    required String ton,
    required String contexte,
    String lore = '',
  }) {
    final b = StringBuffer();
    if (univers.trim().isNotEmpty) b.writeln('Univers : $univers');
    if (ton.trim().isNotEmpty) b.writeln('Ton : $ton');
    if (lore.trim().isNotEmpty) {
      b.writeln('Lore/ambiance à évoquer (personnages et décor peuvent s\'en inspirer) : ${lore.trim()}');
    }
    if (contexte.trim().isNotEmpty) b.writeln('Contexte : ${contexte.trim()}');
    return b.toString();
  }

  /// Le résumé de l'épisode. Avec des [categoriesRegistre], l'IA rend aussi
  /// les entrées du registre.
  Future<MemoireEpisode> resumer({
    required AiSettings settings,
    required String univers,
    required String ton,
    required String contexte,
    required String transcription,
    String public = 'enfant',
    String lore = '',
    List<String> categoriesRegistre = const [],
  }) async {
    final kids = public != 'adulte';
    final contenu = StringBuffer(_entete(univers: univers, ton: ton, contexte: contexte, lore: lore))
      ..writeln('Transcription :')
      ..write(transcription.trim());
    final consigne = (kids ? _consigneEnfant : _consigneAdulte) +
        (categoriesRegistre.isEmpty ? _formatResume : _formatRegistre(categoriesRegistre, kids: kids));
    final reponse = await _llm.complete(
      settings: settings,
      system: consigne,
      messages: [ChatMessage(role: 'user', content: contenu.toString())],
    );
    return MemoireEpisode.depuis(reponse);
  }

  /// Les quatre présages d'un méchant de saison : il se signale, il enferme,
  /// il envahit, il bloque les sorties. Le maître du jeu les valide ou les
  /// réécrit.
  Future<List<String>> proposerPresages({
    required AiSettings settings,
    required String univers,
    required String ton,
    required String contexte,
    required String mechant,
    required List<String> paliers,
    String public = 'enfant',
  }) async {
    final kids = public != 'adulte';
    final contenu = StringBuffer(_entete(univers: univers, ton: ton, contexte: contexte))
      ..writeln('Le méchant de la saison :')
      ..writeln(mechant.trim())
      ..writeln('Les quatre paliers de sa machination :');
    for (final (i, p) in paliers.indexed) {
      contenu.writeln('${i + 1}. $p');
    }
    final reponse = await _llm.complete(
      settings: settings,
      system: '${kids ? _consigneEnfant : _consigneAdulte} '
          'Tu proposes les quatre présages d\'une saison de quatre épisodes : un par '
          'épisode, un par palier. Le méchant reste dans l\'ombre : on voit ses coups '
          'et ses sbires, pas lui, jusqu\'au final de l\'épisode 4. Chaque présage est '
          'une phrase courte, au présent, que les joueurs peuvent voir ou entendre. '
          'Forme : {"presages": ["...", "...", "...", "..."]}.',
      messages: [ChatMessage(role: 'user', content: contenu.toString())],
    );
    final map = _objetJson(reponse);
    final liste = [for (final p in (map?['presages'] as List? ?? const [])) '$p'.trim()];
    return [for (var i = 0; i < 4; i++) i < liste.length ? liste[i] : ''];
  }

  /// Deux ou trois entrées du registre à ressortir dans l'épisode à venir.
  Future<List<Ressorti>> proposerRessortis({
    required AiSettings settings,
    required String univers,
    required String ton,
    required String contexte,
    required List<String> entrees,
    String prochainEpisode = '',
    String public = 'enfant',
  }) async {
    if (entrees.isEmpty) return const [];
    final kids = public != 'adulte';
    final contenu = StringBuffer(_entete(univers: univers, ton: ton, contexte: contexte));
    if (prochainEpisode.trim().isNotEmpty) contenu.writeln('Le prochain épisode : ${prochainEpisode.trim()}');
    contenu.writeln('Le registre de la série :');
    for (final (i, e) in entrees.indexed) {
      contenu.writeln('${i + 1}. $e');
    }
    final reponse = await _llm.complete(
      settings: settings,
      system: '${kids ? _consigneEnfant : _consigneAdulte} '
          'Tu proposes au maître du jeu deux ou trois entrées du registre à ressortir '
          'dans le prochain épisode (un témoin qui revient, un objet oublié qui '
          'réapparaît, une promesse qui coûte). Pour chacune, une phrase qui dit '
          'comment la ressortir. Forme : {"choix": [{"numero": 1, "comment": "..."}]}.',
      messages: [ChatMessage(role: 'user', content: contenu.toString())],
    );
    final map = _objetJson(reponse);
    final choix = <Ressorti>[];
    for (final c in (map?['choix'] as List? ?? const [])) {
      if (c is! Map) continue;
      final n = int.tryParse('${c['numero']}');
      if (n == null || n < 1 || n > entrees.length || choix.any((x) => x.numero == n)) continue;
      choix.add(Ressorti(numero: n, comment: '${c['comment'] ?? ''}'.trim()));
      if (choix.length == 3) break;
    }
    return choix;
  }
}
