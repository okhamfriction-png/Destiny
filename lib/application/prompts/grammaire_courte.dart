import '../../domain/grammaire/modeles.dart';

/// La version des prompts. Elle change à chaque modification de leur texte :
/// une partie commencée avec une autre version n'est pas reprise.
const String kVersionPrompts = '2.0.0';

/// La grammaire de Destiny en version courte, générée depuis le fichier de
/// grammaire : la promesse, les paliers, les actes, le rituel, le personnage,
/// les archétypes et leur montée, les règles d'or. Rien n'est recopié à la
/// main.
String grammaireCourte(Grammaire g, {bool kids = false}) {
  final b = StringBuffer()
    ..writeln('DESTINY — « ${g.promesse} »')
    ..writeln('Un drame improvisé en huis clos : un lieu unique et ses espaces, un groupe qui se connaît, '
        'et un danger qui monte d\'un palier par acte.')
    ..writeln()
    ..writeln('LES QUATRE PALIERS DU DANGER (un par acte, il ne redescend jamais) :');
  for (final p in g.paliers) {
    b.writeln('${p.id.numero}. ${p.nom} — acte ${p.acte}, ambiance « ${p.ambiance} ».');
  }
  b
    ..writeln()
    ..writeln('LES QUATRE ACTES :');
  for (final a in g.actes) {
    b.writeln('Acte ${a.numero} (${g.palier(a.palier).nom}) : ${a.consignes.join(' ')}');
  }
  b
    ..writeln()
    ..writeln('DESTINY, LE RITUEL ENTRE DEUX ACTES (${g.rituel.quand}) : ${g.rituel.sequence.join(' → ')}. '
        '${g.rituel.reprise}')
    ..writeln('Au premier figé : ${g.rituel.premierFige}')
    ..writeln()
    ..writeln('LE PERSONNAGE, EN SIX COUCHES : ${g.personnage.couches.join(' ; ')}.')
    ..writeln('Le piège : ${g.personnage.piege}')
    ..writeln('Phrase clé : « ${g.personnage.phraseCle} »');
  for (final x in g.personnage.acteParActe) {
    b.writeln('- ${x.moment}, ${x.verbe} : ${x.consigne}');
  }
  b
    ..writeln()
    ..writeln('LES DOUZE ARCHÉTYPES (une conviction face au danger) ET LEUR MONTÉE, PALIER PAR PALIER :');
  for (final f in g.familles) {
    b.writeln('${f.nom} :');
    for (final a in g.archetypesDe(f.id)) {
      final montee = [for (final p in PalierId.values) a.monteeA(p)].where((x) => x.isNotEmpty).join(' → ');
      final animaux = g.animauxDe(a.id).map((x) => '${x.nom} (${x.posture})').join(', ');
      b.writeln('- ${a.nom} : ${a.ceQuIlFait} Montée : $montee. Corps possibles : $animaux.');
    }
  }
  b
    ..writeln()
    ..writeln('LES RÈGLES D\'OR : ${g.reglesDOr.map((r) => r.titre).join(' ; ')}.');
  if (kids) {
    b
      ..writeln()
      ..writeln('MODE ENFANT : ${g.modeKids.principe}')
      ..writeln('Ses règles : ${g.modeKids.regles.map((r) => r.titre).join(' ; ')}.')
      ..writeln('Le palier 4 sans mort : ${g.modeKids.palier4}');
  }
  return b.toString().trim();
}
