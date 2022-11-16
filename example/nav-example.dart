import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';
import 'dart:io' show Platform;

void main() {
  final startPoint = WayPoint(
      name: 'start',
      latitude: 29.299523639921834,
      longitude: 31.041632408316595);
  final destinationPoint = WayPoint(
      name: 'destination',
      latitude: 30.85856693507345,
      longitude: 31.239386298296502);
  WidgetsFlutterBinding.ensureInitialized();

  runApp(StartNavigation(startPoint, destinationPoint));
}

class StartNavigation extends StatefulWidget {
  WayPoint startPoint;
  WayPoint destinationPoint;
  StartNavigation(this.startPoint, this.destinationPoint);

  @override
  _StartNavigationState createState() => _StartNavigationState();
}

class _StartNavigationState extends State<StartNavigation> {
  String _platformVersion = 'Unknown';
  String _instruction = "";

  late MapBoxNavigation _directions;
  late MapBoxOptions _options;

  final bool _isMultipleStop = false;
  double _distanceRemaining = 0.0, _durationRemaining = 0.0;
  MapBoxNavigationViewController? _controller;
  bool _routeBuilt = false;
  bool _isNavigating = false;

  @override
  void dispose() {
    _controller?.finishNavigation();
    _controller?.clearRoute();

    super.dispose();
  }

  @override
  void initState() {
    initialize();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Container(
          height: 500,
          // width: 100.w,
          color: Colors.grey,
          child: Platform.isIOS
              ? MapBoxNavigationView(
                  options: _options,
                  onRouteEvent: (e) async {
                    _onEmbeddedRouteEvent(e);
                    // print('event type ${e.eventType}');
                    if (e.eventType == MapBoxEvent.milestone_event) {
                      _controller?.finishNavigation();
                      print('Do something when finished');
                    }
                  },
                  onCreated: (MapBoxNavigationViewController controller) async {
                    _controller = controller;

                    _controller?.initialize();

                    _controller?.clearRoute();
                    var wayPoints = <WayPoint>[];
                    wayPoints.add(widget.startPoint);
                    wayPoints.add(widget.destinationPoint);
                    await _controller?.buildRoute(
                      wayPoints: wayPoints,
                      options: _options,
                    );
                    await _controller?.startNavigation(options: _options);
                  })
              : const SizedBox.shrink(),
        ),
        bottomSheet: Center(
          child: ElevatedButton(
            onPressed: navigateToFullScreenView,
            child: const Text('FullScreenView'),
          ),
        ),
      ),
    );
  }

  void navigateToFullScreenView() async {
    var wayPoints = <WayPoint>[];
    wayPoints.add(widget.startPoint);
    wayPoints.add(widget.destinationPoint);

    await _directions.startNavigation(
      wayPoints: wayPoints,
      options: _options,
    );
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initialize() async {
    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    _directions = MapBoxNavigation(onRouteEvent: _onEmbeddedRouteEvent);
    _options = MapBoxOptions(
      //initialLatitude: 36.1175275,
      //initialLongitude: -115.1839524,
      tilt: 0.0,
      bearing: 0.0,
      enableRefresh: false,
      alternatives: false,
      voiceInstructionsEnabled: true,
      bannerInstructionsEnabled: true,
      allowsUTurnAtWayPoints: true,
      mode: MapBoxNavigationMode.drivingWithTraffic,
      units: VoiceUnits.metric,
      simulateRoute: false,
      animateBuildRoute: true,
      language: "en",
      mapStyleUrlNight: 'your_night_map_style_url',
      mapStyleUrlDay: 'your_map_style_url',
    );

    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      platformVersion = await _directions.platformVersion;
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  Future<void> _onEmbeddedRouteEvent(e) async {
    _distanceRemaining = await _directions.distanceRemaining ?? 0;
    _durationRemaining = await _directions.durationRemaining ?? 0;
    // print(e.eventType);
    switch (e.eventType) {
      case MapBoxEvent.progress_change:
        var progressEvent = e.data as RouteProgressEvent;
        if (progressEvent.currentStepInstruction != null) {
          _instruction = progressEvent.currentStepInstruction ?? '';
        }
        break;
      case MapBoxEvent.route_building:
      case MapBoxEvent.route_built:
        _routeBuilt = true;
        break;
      case MapBoxEvent.route_build_failed:
        _routeBuilt = false;
        break;
      case MapBoxEvent.navigation_running:
        _isNavigating = true;
        break;
      case MapBoxEvent.on_arrival:
        if (!_isMultipleStop) {
          await _controller?.finishNavigation();
        } else {}
        break;
      case MapBoxEvent.navigation_finished:
      case MapBoxEvent.navigation_cancelled:
        _routeBuilt = false;
        _isNavigating = false;
        break;
      default:
        break;
    }
    setState(() {});
  }
}
