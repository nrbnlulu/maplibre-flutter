import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:maplibre_flutter/src/rust/api/dart_types.dart';
import 'package:maplibre_flutter/src/rust/api/maplibre_api.dart' as rlib;
import 'package:maplibre_flutter/src/layer/controller.dart';
import 'package:logging/logging.dart';

import "package:rxdart/rxdart.dart" as rx;

final _log = Logger('MapLibreMapController');

/// State of a MapLibre map instance
enum MapLibreMapState {
  /// Map is being initialized
  initializing,

  /// Map is ready and rendering
  ready,

  /// Map encountered an error
  error,

  /// Map has been stopped/destroyed
  stopped,
}

/// Controller for managing a MapLibre map instance
class MapLibreMapController {
  MapSize _size;
  MapSize get size => _size;
  final MapInitConfig config;

  late final LayerController layerController;

  final List<LayerConfig> layers;

  final int sessionId;
  final rx.BehaviorSubject<MapLibreMapState> _stateBroadcast;
  final rx.BehaviorSubject<MapViewport> _renderedViewportBroadcast =
      rx.BehaviorSubject<MapViewport>();
  StreamSubscription<RenderedMapFrame>? _renderedFrameSub;
  BigInt _lastRenderedFrameSequence = BigInt.zero;
  Future<void> _eventQueue = Future<void>.value();
  int _queuedOperations = 0;
  bool _running = false;
  int _cameraOperation = 0;
  late final ValueNotifier<int?> _textureId;

  MapLibreMapController._({
    required MapSize size,
    required this.config,
    required this.layers,
    required this.sessionId,
    required rx.BehaviorSubject<MapLibreMapState> stateBroadcast,
    required int textureId,
  }) : _size = size,
       _stateBroadcast = stateBroadcast {
    layerController = LayerController(sessionId: sessionId, layers: layers);
    _textureId = ValueNotifier<int?>(textureId);
  }

  /// Stream of map state changes
  Stream<MapLibreMapState> get stateStream => _stateBroadcast.stream;

  /// Current map state
  MapLibreMapState get currentState => _stateBroadcast.value;

  /// Viewports that produced completed native texture frames.
  Stream<MapViewport> get renderedViewportStream =>
      _renderedViewportBroadcast.stream;

  /// Texture ID for rendering (null if not ready)
  int? get textureId => _textureId.value;

  ValueListenable<int?> get textureIdListenable => _textureId;

  /// Whether the map is currently running
  bool get isRunning => _running;

  /// Create a new MapLibre map controller
  static Future<(MapLibreMapController?, String?)> create({
    required MapSize size,
    required MapInitConfig config,
    List<LayerConfig> layers = const [LayerConfig.osm()],
  }) async {
    try {
      // Create the map instance
      final newSessionResp = await rlib.createNewMapSession(config: config);

      // Create state broadcast
      final stateBroadcast = rx.BehaviorSubject<MapLibreMapState>.seeded(
        MapLibreMapState.initializing,
      );

      final controller = MapLibreMapController._(
        size: size,
        config: config,
        layers: layers,
        sessionId: newSessionResp.sessionId,
        stateBroadcast: stateBroadcast,
        textureId: newSessionResp.textureId,
      );

      for (final layer in layers) {
        await controller.layerController.addLayer(layer);
      }

      controller._running = true;
      controller._startRenderedFrameStream();

      await rlib.requestMapRedraw(sessionId: controller.sessionId);

      // Start session keep-alive task
      controller._startKeepAliveTask();

      // Set state to ready
      controller._stateBroadcast.add(MapLibreMapState.ready);

      return (controller, null);
    } catch (e) {
      _log.severe('Error creating MapLibre map', e);
      return (null, e.toString());
    }
  }

  void _startRenderedFrameStream() {
    _renderedFrameSub = rlib
        .streamRenderedMapFrames(sessionId: sessionId)
        .listen(
          (frame) {
            if (!_running || frame.sequence <= _lastRenderedFrameSequence) {
              return;
            }
            _lastRenderedFrameSequence = frame.sequence;
            layerController.updateViewport(frame.viewport, frame.mapSize);
            _renderedViewportBroadcast.add(frame.viewport);
          },
          onError: (Object error, StackTrace stackTrace) {
            if (_running) {
              _log.warning('Rendered-frame stream failed', error, stackTrace);
            }
          },
        );
  }

  /// Start the session keep-alive task
  void _startKeepAliveTask() {
    Future.microtask(() async {
      while (_running) {
        try {
          // Ping Rust side to announce we still want the stream
          await rlib.markSessionAlive(sessionId: sessionId);
          await Future.delayed(const Duration(seconds: 1));
        } catch (e) {
          _log.severe('Error in keep-alive task', e);
          if (_running) {
            _stateBroadcast.add(MapLibreMapState.error);
          }
          break;
        }
      }
    });
  }

  /// Handle user events from the map widget
  Future<void> handleEvent(UserEvent event) {
    if (!_running) return Future<void>.value();
    switch (event) {
      case UserEvent_ButtonPressed() ||
          UserEvent_DragStarted() ||
          UserEvent_Drag():
        cancelCameraMove();
      default:
        break;
    }

    // Pointer motion only sends to the map thread. Send it immediately unless
    // a resize is in flight, when events must keep their order with the resize.
    if (_queuedOperations == 0) {
      _sendEvent(event);
      return Future<void>.value();
    }

    _queuedOperations++;
    final next = _eventQueue.then((_) => _sendEvent(event));
    _eventQueue = next.whenComplete(() => _queuedOperations--);
    return _eventQueue;
  }

  void _sendEvent(UserEvent event) {
    if (!_running) return;
    try {
      rlib.handleEventForSession(sessionId: sessionId, event: event);
    } catch (e) {
      _log.warning('Error handling event', e);
    }
  }

  Future<void> requestRedraw() async {
    await rlib.requestMapRedraw(sessionId: sessionId);
  }

  /// Get the current map viewport
  Future<MapViewport?> getViewport() async {
    return rlib.getMapViewport(sessionId: sessionId);
  }

  /// Set the map viewport
  Future<void> setViewport(MapViewport viewport) async {
    final widthMeters = viewport.xMax - viewport.xMin;
    if (!_running || widthMeters <= 0 || _size.width == 0 || _size.height == 0) {
      return;
    }
    final center = ScreenLocation(
      x: _size.width / 2,
      y: _size.height / 2,
    ).toGeographical(
      vp: viewport,
      height: _size.height.toDouble(),
      width: _size.width.toDouble(),
    );
    final zoom =
        math.log((2 * math.pi * 6378137 * _size.width) / (512 * widthMeters)) /
            math.ln2 +
        1;
    await moveCamera(center: center, zoom: zoom);
  }

  /// Moves to an absolute center and zoom using MapLibre Native's camera
  /// animation. The returned value is false if another camera move replaced it.
  Future<bool> moveCamera({
    required GeoLocation center,
    required double zoom,
    Duration duration = const Duration(milliseconds: 300),
  }) async {
    if (!_running) return false;
    final operation = ++_cameraOperation;
    await handleEvent(
      UserEvent.cameraMove(
        center: center,
        zoom: zoom,
        durationMillis: duration.inMilliseconds.clamp(0, 0xffffffff).toInt(),
      ),
    );
    if (duration > Duration.zero) await Future<void>.delayed(duration);
    return _running && operation == _cameraOperation;
  }

  /// Marks an in-flight [moveCamera] as cancelled. Native gestures also cancel
  /// the active camera transition on the render thread.
  void cancelCameraMove() {
    _cameraOperation++;
  }

  /// Resize the map
  Future<void> resize(MapSize newSize) {
    if (!_running) {
      return Future<void>.value();
    }

    _queuedOperations++;
    final next = _eventQueue.then((_) async {
      if (newSize == _size) {
        return;
      }

      try {
        final newTextureId = await rlib.resizeSession(
          sessionId: sessionId,
          newSize: newSize,
        );
        if (!_running) {
          return;
        }
        _textureId.value = newTextureId;
        _size = newSize;
      } catch (e) {
        _log.severe('Error resizing map', e);
      }
    });
    _eventQueue = next.whenComplete(() => _queuedOperations--);
    return next;
  }

  /// Dispose of the controller and clean up resources
  Future<void> dispose() async {
    _running = false;

    try {
      await rlib.destroySession(sessionId: sessionId);
      await _renderedFrameSub?.cancel();
      await _renderedViewportBroadcast.close();
      await _stateBroadcast.close();
    } catch (e) {
      _log.severe('Error disposing MapLibre map controller', e);
    }
    _textureId.dispose();
  }
}
