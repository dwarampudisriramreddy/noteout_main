import 'dart:math';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'editor_screen.dart';

class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<_GraphNodeData> _nodes = [];
  List<_GraphEdgeData> _edges = [];
  late AnimationController _controller;
  Map<String, Offset> _positions = {};
  Map<String, Offset> _velocities = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addListener(_tick);
    _buildGraph();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _buildGraph() async {
    final allNotes = await StorageService.getAllNotes();
    _nodes = [];
    _edges = [];
    _positions = {};
    _velocities = {};

    final titleToId = <String, String>{};
    final rng = Random(42);

    for (final note in allNotes) {
      final title = note.title.isEmpty ? 'untitled' : note.title;
      titleToId[title.toLowerCase()] = note.id;
      _nodes.add(_GraphNodeData(id: note.id, label: title));
      _positions[note.id] = Offset(
        200 + rng.nextDouble() * 200,
        200 + rng.nextDouble() * 200,
      );
      _velocities[note.id] = Offset.zero;
    }

    for (final note in allNotes) {
      for (final link in note.outgoingLinks) {
        final targetId = titleToId[link.toLowerCase()];
        if (targetId != null && targetId != note.id) {
          _edges.add(_GraphEdgeData(source: note.id, target: targetId));
        }
      }
    }

    setState(() => _isLoading = false);
    _controller.forward(from: 0);
  }

  void _tick() {
    if (!mounted) return;
    const double repulsion = 5000;
    const double attraction = 0.005;
    const double damping = 0.9;
    const double centerForce = 0.01;

    final center = const Offset(250, 250);
    final newPositions = <String, Offset>{};
    final newVelocities = <String, Offset>{};

    for (final node in _nodes) {
      var force = Offset.zero;

      for (final other in _nodes) {
        if (other.id == node.id) continue;
        final delta = _positions[node.id]! - _positions[other.id]!;
        final dist = delta.distance.clamp(1.0, 300.0);
        force += (delta / dist) * (repulsion / (dist * dist));
      }

      for (final edge in _edges) {
        String? neighborId;
        if (edge.source == node.id) neighborId = edge.target;
        if (edge.target == node.id) neighborId = edge.source;
        if (neighborId != null) {
          final delta = _positions[neighborId]! - _positions[node.id]!;
          force += delta * attraction;
        }
      }

      force += (center - _positions[node.id]!) * centerForce;

      final vel = (_velocities[node.id]! + force) * damping;
      newVelocities[node.id] = vel;
      newPositions[node.id] = _positions[node.id]! + vel;
    }

    setState(() {
      _positions = newPositions;
      _velocities = newVelocities;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'graph',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: context.nText,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(strokeWidth: 1.5, color: context.nText),
            )
          : _nodes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_tree_outlined,
                          size: 48, color: context.nSubtle),
                      const SizedBox(height: 12),
                      Text('no notes to graph',
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              color: context.nFaint)),
                    ],
                  ),
                )
              : InteractiveViewer(
                  boundaryMargin: const EdgeInsets.all(100),
                  minScale: 0.2,
                  maxScale: 3.0,
                  child: SizedBox(
                    width: 500,
                    height: 500,
                    child: Stack(
                      children: [
                        CustomPaint(
                          size: const Size(500, 500),
                          painter: _EdgePainter(
                            edges: _edges,
                            positions: _positions,
                            lineColor: context.nMuted,
                          ),
                        ),
                        for (final node in _nodes)
                          _buildNodeWidget(node),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildNodeWidget(_GraphNodeData node) {
    final pos = _positions[node.id] ?? Offset.zero;
    final hasEdges = _edges.any(
      (e) => e.source == node.id || e.target == node.id,
    );

    return Positioned(
      left: pos.dx - 40,
      top: pos.dy - 14,
      child: GestureDetector(
        onTap: () async {
          _controller.stop();
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditorScreen(noteId: node.id),
            ),
          );
          await _buildGraph();
        },
                        child: Container(
          constraints: const BoxConstraints(minWidth: 80),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: hasEdges
                ? Theme.of(context).colorScheme.primary
                : context.nPanel,
            borderRadius: BorderRadius.circular(4),
            border: hasEdges
                ? null
                : Border.all(color: context.nLine, width: 0.5),
          ),
          child: Text(
            node.label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: hasEdges
                  ? Theme.of(context).colorScheme.onPrimary
                  : context.nMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _GraphNodeData {
  final String id;
  final String label;
  _GraphNodeData({required this.id, required this.label});
}

class _GraphEdgeData {
  final String source;
  final String target;
  _GraphEdgeData({required this.source, required this.target});
}

class _EdgePainter extends CustomPainter {
  final List<_GraphEdgeData> edges;
  final Map<String, Offset> positions;
  final Color lineColor;

  _EdgePainter({
    required this.edges,
    required this.positions,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final edge in edges) {
      final from = positions[edge.source];
      final to = positions[edge.target];
      if (from != null && to != null) {
        canvas.drawLine(from, to, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) => true;
}
