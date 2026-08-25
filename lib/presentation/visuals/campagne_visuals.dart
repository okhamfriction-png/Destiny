import 'package:flutter/material.dart';

import 'entity_visuals.dart';

/// Emoji par archétype animal de la Campagne.
const Map<String, String> _emojis = {
  'aigle': '🦅',
  'tortue': '🐢',
  'renard': '🦊',
  'ours': '🐻',
  'souris': '🐭',
  'lion': '🦁',
  'chat': '🐱',
  'chien': '🐶',
  'singe': '🐵',
  'hibou': '🦉',
  'lapin': '🐰',
  'dauphin': '🐬',
  'elephant': '🐘',
  'pie': '🐦',
  'loup': '🐺',
  'paon': '🦚',
};

String emojiArchetype(String id) => _emojis[id] ?? '🎭';

/// Couleur du nom d'un archétype selon son statut (ambre / bleu / blanc).
Color couleurStatut(String statut) => EntityVisuals.colorForStatut(statut);
