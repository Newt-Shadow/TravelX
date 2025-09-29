// utils/graph_learning.dart
import 'dart:math';

/// Original Markov-style transition graph. Learns from the single previous state.
/// It's simple, fast, and efficient.
class TransitionGraph {
  final Map<String, Map<String, int>> _graph = {};
  final List<Map<String, String>> _history = [];
  double decayFactor;

  /// [decayFactor] in (0,1] — controls how past transitions are forgotten.
  /// Example: 0.9 means each update reduces old weights by 10%.
  TransitionGraph({this.decayFactor = 1.0});

  /// Add a transition from state [from] → [to].
  void addTransition(String from, String to) {
    if (!_graph.containsKey(from)) {
      _graph[from] = {};
    }

    // Apply decay if enabled
    if (decayFactor < 1.0) {
      _graph[from]!.updateAll((key, val) => (val * decayFactor).ceil());
    }

    _graph[from]![to] = (_graph[from]![to] ?? 0) + 1;

    // Record the transition event in the history list.
    _history.add({'from': from, 'to': to});
  }
  
  /// Finds the most recent transition that originated FROM the given [fromMode].
  /// Returns a map like {'from': 'walk', 'to': 'stationary'} or null if not found.
  Map<String, String>? lastTransition(String fromMode) {
    // Search the history list backwards.
    for (int i = _history.length - 1; i >= 0; i--) {
      if (_history[i]['from'] == fromMode) {
        return _history[i];
      }
    }
    // Return null if no transition from the given mode is found in the history.
    return null;
  }

  /// Returns probabilities of next states from [from].
  /// Example: { "walk": 0.7, "bus": 0.3 }
  Map<String, double> nextProbabilities(String from) {
    final map = _graph[from];
    if (map == null || map.isEmpty) return {};
    final total = map.values.fold<int>(0, (a, b) => a + b);
    return map.map((k, v) => MapEntry(k, v / total));
  }

  /// Returns the most likely next state.
  String? mostLikelyNext(String from) {
    final probs = nextProbabilities(from);
    if (probs.isEmpty) return null;
    return probs.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Returns the top [n] likely next states.
  List<MapEntry<String, double>> topNext(String from, {int n = 3}) {
    final probs = nextProbabilities(from);
    final sorted = probs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).toList();
  }

  /// Choose next state randomly, weighted by learned probabilities.
  String? randomNext(String from) {
    final probs = nextProbabilities(from);
    if (probs.isEmpty) return null;
    final r = _randDouble();
    double cum = 0.0;
    for (final e in probs.entries) {
      cum += e.value;
      if (r <= cum) return e.key;
    }
    return probs.keys.last; // fallback
  }

  /// Export graph (for saving).
  Map<String, Map<String, int>> exportGraph() => _graph;

  /// Import graph (for restoring).
  void importGraph(Map<String, dynamic> data) {
    _graph.clear();
    data.forEach((k, v) {
      _graph[k] = Map<String, int>.from(v as Map);
    });
  }

  double _randDouble() =>
      (DateTime.now().microsecondsSinceEpoch % 1000000) / 1000000.0;
}

// ------------------- NEW ADVANCED MODEL -------------------

/// An advanced, context-aware Markov-style transition graph.
/// It learns not just from the previous mode, but from a sequence of modes
/// and the time of day to make smarter, personalized predictions.
class ContextualTransitionGraph {
  final Map<String, Map<String, int>> _graph = {};
  double decayFactor;

  ContextualTransitionGraph({this.decayFactor = 1.0});

  // --- Helper to determine the time of day ---
  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'morning';
    } else if (hour >= 12 && hour < 17) {
      return 'afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'evening';
    } else {
      return 'night';
    }
  }

  // --- The new, context-aware key generation ---
  String _generateKey(String previousMode, String currentMode) {
    final timeOfDay = _getTimeOfDay();
    // The key now includes the last two modes and the time of day.
    // Example: "walk->stationary_morning"
    return '$previousMode->$currentMode\_$timeOfDay';
  }

  /// Add a transition from a sequence of states [previousMode] -> [currentMode] -> [nextMode].
  void addTransition(String? previousMode, String currentMode, String nextMode) {
    // If we don't have a previous mode (e.g., first segment of a trip),
    // we use a generic "start" state.
    final fromState = previousMode ?? 'start';
    final key = _generateKey(fromState, currentMode);

    if (!_graph.containsKey(key)) {
      _graph[key] = {};
    }

    if (decayFactor < 1.0) {
      _graph[key]!.updateAll((key, val) => (val * decayFactor).ceil());
    }

    _graph[key]![nextMode] = (_graph[key]![nextMode] ?? 0) + 1;
  }

  /// Returns the most likely next state given the context.
  String? mostLikelyNext(String? previousMode, String currentMode) {
    final fromState = previousMode ?? 'start';
    final key = _generateKey(fromState, currentMode);
    
    final transitions = _graph[key];
    if (transitions == null || transitions.isEmpty) return null;

    // Find the entry with the highest count (most frequent transition)
    return transitions.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
  
  /// Returns the total number of observed transitions from a given context.
  /// This can be used as a "confidence score".
  int totalTransitionsFrom(String? previousMode, String currentMode) {
    final fromState = previousMode ?? 'start';
    final key = _generateKey(fromState, currentMode);
    final transitions = _graph[key];
    if (transitions == null) return 0;
    return transitions.values.fold(0, (sum, count) => sum + count);
  }

  // Export and Import methods remain the same, as they work with the _graph map.
  Map<String, Map<String, int>> exportGraph() => _graph;

  void importGraph(Map<String, dynamic> data) {
    _graph.clear();
    data.forEach((k, v) {
      _graph[k] = Map<String, int>.from(v as Map);
    });
  }
}