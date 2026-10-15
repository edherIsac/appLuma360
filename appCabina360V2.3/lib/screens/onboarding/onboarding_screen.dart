import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:cabina360_v2_2/models/permission_config.dart';
import 'package:cabina360_v2_2/screens/onboarding/widgets/permission_item_widget.dart';
import 'package:cabina360_v2_2/services/permission_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const OnboardingScreen({required this.onFinished, super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  final PageController _controller = PageController();
  int _currentPage = 0;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check permissions when the user returns from settings
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
    }
  }

  Future<void> _initPermissions() async {
    await PermissionService.instance.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _refreshPermissions() async {
    await PermissionService.instance.recheckOnResume();
    if (mounted) setState(() {});
  }

  Future<void> _markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);
    widget.onFinished();
  }

  Future<void> _requestSinglePermission(Permission permission) async {
    setState(() => _isRequesting = true);
    await PermissionService.instance.requestPermission(permission);
    if (mounted) setState(() => _isRequesting = false);
  }

  Future<void> _requestAllPermissions() async {
    setState(() => _isRequesting = true);
    await PermissionService.instance.requestAll();
    if (mounted) setState(() => _isRequesting = false);
  }

  bool get _allRequiredGranted =>
      PermissionService.instance.areAllRequiredGranted();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Page indicator dots
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? Theme.of(context).primaryColor
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildWelcomePage(context),
                  _buildFeaturesPage(context),
                  _buildPermissionsPage(context),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ── Page 1: Welcome ────────────────────────────────────

  Widget _buildWelcomePage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.photo_camera,
              size: 64,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Bienvenido a Cabina 360',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Graba, procesa y comparte videos 360 fácilmente desde tu dispositivo.',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Page 2: Features ───────────────────────────────────

  Widget _buildFeaturesPage(BuildContext context) {
    final features = [
      {
        'icon': Icons.videocam,
        'title': 'Grabación programada',
        'desc': 'Configura la duración y graba automáticamente.',
      },
      {
        'icon': Icons.movie_filter,
        'title': 'Procesado con FFmpeg',
        'desc': 'Aplica efectos, marcos, logos y audio de fondo.',
      },
      {
        'icon': Icons.share,
        'title': 'Compartir fácilmente',
        'desc': 'Comparte videos por WiFi o redes sociales.',
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Funciones principales',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      f['icon'] as IconData,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f['title'] as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          f['desc'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Page 3: Permissions ────────────────────────────────

  Widget _buildPermissionsPage(BuildContext context) {
    final service = PermissionService.instance;
    final requiredConfigs = service.requiredConfigs;
    final optionalConfigs = service.optionalConfigs;
    final statuses = service.getAllStatuses();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          const Text(
            'Permisos necesarios',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'La aplicación necesita los siguientes permisos para funcionar correctamente.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // "Grant all" button
          if (!_allRequiredGranted)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isRequesting ? null : _requestAllPermissions,
                  icon: _isRequesting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isRequesting
                        ? 'Solicitando...'
                        : 'Conceder todos los permisos',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          // Required permissions list
          Expanded(
            child: ListView(
              children: [
                if (requiredConfigs.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6, top: 4),
                    child: Text(
                      'Requeridos',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  ...requiredConfigs.map(
                    (config) => PermissionItemWidget(
                      config: config,
                      status:
                          statuses[config.permission] ??
                          PermissionStatus.denied,
                      onRequest: () =>
                          _requestSinglePermission(config.permission),
                    ),
                  ),
                ],
                if (optionalConfigs.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6, top: 12),
                    child: Text(
                      'Opcionales',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  ...optionalConfigs.map(
                    (config) => PermissionItemWidget(
                      config: config,
                      status:
                          statuses[config.permission] ??
                          PermissionStatus.denied,
                      onRequest: () =>
                          _requestSinglePermission(config.permission),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Status message
          if (_allRequiredGranted)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Todos los permisos requeridos están concedidos',
                    style: TextStyle(
                      color: Colors.green[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Bottom Navigation Bar ──────────────────────────────

  Widget _buildBottomBar() {
    final isLastPage = _currentPage == 2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button (hidden on first page)
          if (_currentPage > 0)
            TextButton(
              onPressed: () {
                _controller.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.ease,
                );
              },
              child: const Text('Atrás'),
            )
          else
            const SizedBox(width: 80), // Balance spacing
          // Next / Start button
          if (isLastPage)
            ElevatedButton(
              onPressed: _allRequiredGranted ? _markSeen : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Comenzar'),
            )
          else
            ElevatedButton(
              onPressed: () {
                _controller.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.ease,
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Siguiente'),
            ),
        ],
      ),
    );
  }
}
