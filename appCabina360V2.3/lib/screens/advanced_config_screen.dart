import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/advanced_config_service.dart';

/// Pantalla de configuración avanzada
/// Permite gestionar presets, importar/exportar configuraciones y validar parámetros
class AdvancedConfigScreen extends StatefulWidget {
  const AdvancedConfigScreen({super.key});

  @override
  State<AdvancedConfigScreen> createState() => _AdvancedConfigScreenState();
}

class _AdvancedConfigScreenState extends State<AdvancedConfigScreen> {
  final AdvancedConfigService _configService = AdvancedConfigService.instance;
  // final UsabilityService _usabilityService = UsabilityService.instance; // No se usa en esta pantalla

  Map<String, dynamic>? _currentConfig;
  List<Map<String, dynamic>> _customPresets = [];
  List<ConfigurationHistory> _configHistory = [];
  Map<String, dynamic> _usageStats = {};

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Cargar datos iniciales
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _configService.initialize();

      _currentConfig = _configService.currentConfig;
      _customPresets = await _configService.getCustomPresets();
      _configHistory = _configService.configHistory;
      _usageStats = _configService.getUsageStats();

      setState(() {});
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar configuración: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Aplicar preset
  Future<void> _applyPreset(String presetId) async {
    try {
      await _configService.applyPreset(presetId);
      await _loadData();

      setState(() {
        _successMessage = 'Preset aplicado exitosamente';
      });

      // Limpiar mensaje después de 3 segundos
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al aplicar preset: $e';
      });
    }
  }

  /// Exportar configuración
  Future<void> _exportConfig() async {
    try {
      final filename =
          'cabina360_config_${DateTime.now().millisecondsSinceEpoch}';
      final file = await _configService.exportConfigToFile(filename);

      setState(() {
        _successMessage = 'Configuración exportada a: ${file.path}';
      });

      // Limpiar mensaje después de 3 segundos
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al exportar: $e';
      });
    }
  }

  /// Importar configuración
  Future<void> _importConfig() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final file = result.files.first;
        if (file.path != null) {
          await _configService.importConfigFromFile(File(file.path!));
          await _loadData();

          setState(() {
            _successMessage = 'Configuración importada exitosamente';
          });

          // Limpiar mensaje después de 3 segundos
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _successMessage = null;
              });
            }
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al importar: $e';
      });
    }
  }

  /// Crear preset personalizado
  Future<void> _createCustomPreset() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentConfig == null) return;

    try {
      await _configService.createCustomPreset(
        _nameController.text,
        _descriptionController.text,
        _currentConfig!,
      );

      await _loadData();

      // Limpiar formulario
      _nameController.clear();
      _descriptionController.clear();

      setState(() {
        _successMessage = 'Preset personalizado creado exitosamente';
      });

      // Limpiar mensaje después de 3 segundos
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al crear preset: $e';
      });
    }
  }

  /// Eliminar preset personalizado
  Future<void> _deleteCustomPreset(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content:
            Text('¿Estás seguro de que quieres eliminar el preset "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _configService.deleteCustomPreset(name);
        await _loadData();

        setState(() {
          _successMessage = 'Preset eliminado exitosamente';
        });

        // Limpiar mensaje después de 3 segundos
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _successMessage = null;
            });
          }
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'Error al eliminar preset: $e';
        });
      }
    }
  }

  /// Mostrar diálogo de creación de preset
  void _showCreatePresetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear Preset Personalizado'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Preset',
                  hintText: 'Ej: Mi Evento Especial',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa un nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Describe el tipo de evento',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa una descripción';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _createCustomPreset();
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración Avanzada'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mensajes de estado
                  if (_errorMessage != null)
                    _buildMessageCard(_errorMessage!, Colors.red, Icons.error),
                  if (_successMessage != null)
                    _buildMessageCard(
                        _successMessage!, Colors.green, Icons.check_circle),

                  // Presets predefinidos
                  _buildPresetsSection(),

                  const SizedBox(height: 24),

                  // Presets personalizados
                  _buildCustomPresetsSection(),

                  const SizedBox(height: 24),

                  // Importar/Exportar
                  _buildImportExportSection(),

                  const SizedBox(height: 24),

                  // Historial de configuraciones
                  _buildHistorySection(),

                  const SizedBox(height: 24),

                  // Estadísticas de uso
                  _buildStatsSection(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePresetDialog,
        tooltip: 'Crear Preset Personalizado',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Construir tarjeta de mensaje
  Widget _buildMessageCard(String message, Color color, IconData icon) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          message,
          style: TextStyle(color: color),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            setState(() {
              _errorMessage = null;
              _successMessage = null;
            });
          },
        ),
      ),
    );
  }

  /// Construir sección de presets predefinidos
  Widget _buildPresetsSection() {
    final presets = _configService.availablePresets;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Presets Predefinidos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...presets.entries.map((entry) {
              final preset = entry.value;
              return ListTile(
                title: Text(preset['name'] as String),
                subtitle: Text(preset['description'] as String),
                trailing: ElevatedButton(
                  onPressed: () => _applyPreset(entry.key),
                  child: const Text('Aplicar'),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  /// Construir sección de presets personalizados
  Widget _buildCustomPresetsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Presets Personalizados',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_customPresets.isEmpty)
              const Center(
                child: Text(
                  'No hay presets personalizados',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ..._customPresets.map((preset) {
                return ListTile(
                  title: Text(preset['name'] as String),
                  subtitle: Text(preset['description'] as String),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () =>
                            _configService.updateCurrentConfig(preset),
                        child: const Text('Aplicar'),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            _deleteCustomPreset(preset['name'] as String),
                        tooltip: 'Eliminar',
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  /// Construir sección de importar/exportar
  Widget _buildImportExportSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.import_export, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Importar/Exportar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _exportConfig,
                    icon: const Icon(Icons.upload),
                    label: const Text('Exportar Configuración'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _importConfig,
                    icon: const Icon(Icons.download),
                    label: const Text('Importar Configuración'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Construir sección de historial
  Widget _buildHistorySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Colors.purple),
                const SizedBox(width: 8),
                const Text(
                  'Historial de Configuraciones',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    await _configService.clearHistory();
                    await _loadData();
                  },
                  child: const Text('Limpiar'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_configHistory.isEmpty)
              const Center(
                child: Text(
                  'No hay historial de configuraciones',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ..._configHistory.take(10).map((entry) {
                return ListTile(
                  title: Text(entry.description),
                  subtitle: Text(
                    '${entry.timestamp.day}/${entry.timestamp.month}/${entry.timestamp.year} '
                    '${entry.timestamp.hour}:${entry.timestamp.minute}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.visibility),
                    onPressed: () => _showConfigDetails(entry),
                    tooltip: 'Ver detalles',
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  /// Construir sección de estadísticas
  Widget _buildStatsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.indigo),
                const SizedBox(width: 8),
                const Text(
                  'Estadísticas de Uso',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatItem('Total de Configuraciones',
                _usageStats['totalConfigurations']?.toString() ?? '0'),
            _buildStatItem('Presets Personalizados',
                _usageStats['customPresetsCreated']?.toString() ?? '0'),
            _buildStatItem('Preset Más Usado',
                _usageStats['mostUsedPreset']?.toString() ?? 'N/A'),
            _buildStatItem('Última Configuración',
                _usageStats['lastConfiguration']?.toString() ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  /// Construir item de estadística
  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  /// Mostrar detalles de configuración
  void _showConfigDetails(ConfigurationHistory entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry.description),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Fecha: ${entry.timestamp.toString()}'),
              const SizedBox(height: 16),
              const Text('Configuración:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                _formatConfigForDisplay(entry.config),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Formatear configuración para mostrar
  String _formatConfigForDisplay(Map<String, dynamic> config) {
    final buffer = StringBuffer();
    _formatMap(config, buffer, 0);
    return buffer.toString();
  }

  /// Formatear mapa recursivamente
  void _formatMap(Map<String, dynamic> map, StringBuffer buffer, int indent) {
    for (final entry in map.entries) {
      buffer.write('${'  ' * indent}${entry.key}: ');
      if (entry.value is Map) {
        buffer.writeln('{');
        _formatMap(entry.value as Map<String, dynamic>, buffer, indent + 1);
        buffer.write('${'  ' * indent}}');
      } else {
        buffer.writeln(entry.value.toString());
      }
    }
  }
}
