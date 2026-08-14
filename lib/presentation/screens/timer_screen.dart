import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({required this.audioService, super.key});

  final AudioService audioService;

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerPreset {
  const _TimerPreset(this.label, this.seconds);
  final String label;
  final int seconds;
}

class _TimerScreenState extends State<TimerScreen> {
  static const List<_TimerPreset> _presets = [
    _TimerPreset('30 secondes', 30),
    _TimerPreset('3 minutes', 180),
    _TimerPreset('5 minutes', 300),
  ];

  // Fréquences possibles pour le son DestinyStorm (0 = désactivé).
  static const List<int> _frequencies = [0, 300, 600];

  Timer? _ticker;
  int _totalSeconds = 180;
  int _remainingSeconds = 180;
  bool _running = false;
  int _stormFrequency = 0; // secondes; 0 = désactivé

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _selectPreset(int seconds) {
    _ticker?.cancel();
    setState(() {
      _totalSeconds = seconds;
      _remainingSeconds = seconds;
      _running = false;
    });
  }

  void _toggleRun() {
    if (_running) {
      _pause();
    } else {
      _start();
    }
  }

  void _start() {
    if (_remainingSeconds <= 0) {
      _remainingSeconds = _totalSeconds;
    }
    setState(() => _running = true);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _pause() {
    _ticker?.cancel();
    setState(() => _running = false);
  }

  void _reset() {
    _ticker?.cancel();
    setState(() {
      _remainingSeconds = _totalSeconds;
      _running = false;
    });
  }

  void _onTick() {
    setState(() {
      _remainingSeconds = (_remainingSeconds - 1).clamp(0, _totalSeconds);
    });

    final elapsed = _totalSeconds - _remainingSeconds;

    if (_remainingSeconds <= 0) {
      _ticker?.cancel();
      setState(() => _running = false);
      widget.audioService.playStorm();
      return;
    }

    // Son DestinyStorm à la fréquence choisie.
    if (_stormFrequency > 0 &&
        elapsed > 0 &&
        elapsed % _stormFrequency == 0) {
      widget.audioService.playStorm();
    }
  }

  String _format(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _frequencyLabel(int freq) {
    if (freq == 0) return 'Désactivé';
    if (freq % 60 == 0) return 'Toutes les ${freq ~/ 60} min';
    return 'Toutes les ${freq}s';
  }

  Future<void> _customDuration() async {
    var minutes = (_totalSeconds ~/ 60).clamp(0, 60);
    var seconds = _totalSeconds % 60;
    final minCtrl = TextEditingController(text: '$minutes');
    final secCtrl = TextEditingController(text: '$seconds');

    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        );

    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            void setMinutes(int v) {
              minutes = v.clamp(0, 60);
              minCtrl.text = '$minutes';
              setLocal(() {});
            }

            void setSeconds(int v) {
              seconds = v.clamp(0, 59);
              secCtrl.text = '$seconds';
              setLocal(() {});
            }

            return AlertDialog(
              title: const Text('Durée personnalisée'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Saisie au clavier numérique.
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 26),
                          decoration: deco('Minutes'),
                          onChanged: (v) {
                            minutes = (int.tryParse(v.trim()) ?? 0).clamp(0, 60);
                            setLocal(() {});
                          },
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(':', style: TextStyle(fontSize: 26)),
                      ),
                      Expanded(
                        child: TextField(
                          controller: secCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 26),
                          decoration: deco('Secondes'),
                          onChanged: (v) {
                            seconds = (int.tryParse(v.trim()) ?? 0).clamp(0, 59);
                            setLocal(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Réglage au curseur.
                  Row(
                    children: [
                      SizedBox(width: 64, child: Text('Min : $minutes')),
                      Expanded(
                        child: Slider(
                          value: minutes.toDouble(),
                          min: 0,
                          max: 60,
                          divisions: 60,
                          label: '$minutes',
                          onChanged: (v) => setMinutes(v.round()),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      SizedBox(width: 64, child: Text('Sec : $seconds')),
                      Expanded(
                        child: Slider(
                          value: seconds.toDouble(),
                          min: 0,
                          max: 59,
                          divisions: 59,
                          label: '$seconds',
                          onChanged: (v) => setSeconds(v.round()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, minutes * 60 + seconds),
                  child: const Text('Valider'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result != null && result > 0) {
      _selectPreset(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _totalSeconds == 0
        ? 0.0
        : _remainingSeconds / _totalSeconds;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Compte à rebours',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 18),
        Center(
          child: GestureDetector(
            onTap: _running ? null : _customDuration,
            child: SizedBox(
              width: 240,
              height: 240,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 12,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _format(_remainingSeconds),
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [],
                        ),
                      ),
                      if (!_running)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit,
                                size: 13, color: Colors.white38),
                            const SizedBox(width: 4),
                            Text('Modifier',
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: Colors.white38)),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _toggleRun,
                icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                label: Text(_running ? 'Pause' : 'Démarrer'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.replay),
                label: const Text('Réinitialiser'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Préréglages', style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final preset in _presets)
              ChoiceChip(
                label: Text(preset.label),
                selected: _totalSeconds == preset.seconds && !_isCustom(),
                onSelected: (_) => _selectPreset(preset.seconds),
              ),
            ActionChip(
              avatar: const Icon(Icons.tune, size: 18),
              label: const Text('Personnalisé'),
              onPressed: _customDuration,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Son DestinyStorm', style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final freq in _frequencies)
              ChoiceChip(
                label: Text(_frequencyLabel(freq)),
                selected: _stormFrequency == freq,
                onSelected: (_) => setState(() => _stormFrequency = freq),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            onPressed: widget.audioService.playStorm,
            icon: const Icon(Icons.volume_up),
            label: const Text('Tester le son'),
          ),
        ),
      ],
    );
  }

  bool _isCustom() =>
      !_presets.any((preset) => preset.seconds == _totalSeconds);
}
