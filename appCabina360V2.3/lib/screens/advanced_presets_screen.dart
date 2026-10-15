import 'package:flutter/material.dart';
import 'package:cabina360_v2_2/services/advanced_presets_manager.dart';
import 'package:cabina360_v2_2/services/advanced_video_editing_service.dart';

/// Pantalla para gestionar presets avanzados de video
/// Muestra presets organizados por categoría, búsqueda y detalles
class AdvancedPresetsScreen extends StatefulWidget {
  const AdvancedPresetsScreen({super.key});

  @override
  State<AdvancedPresetsScreen> createState() => _AdvancedPresetsScreenState();
}

class _AdvancedPresetsScreenState extends State<AdvancedPresetsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  late AdvancedPresetsManager _presetsManager;
  List<AdvancedPreset> _filteredPresets = [];
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _presetsManager = AdvancedPresetsManager.instance;
    _tabController = TabController(length: 2, vsync: this);
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    try {
      await _presetsManager.initialize();
      _filterPresets();
      setState(() {});
    } catch (e) {
      print('❌ Error inicializando pantalla: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterPresets() {
    List<AdvancedPreset> presets;
    
    if (_selectedCategory == 'all') {
      presets = _presetsManager.availablePresets;
    } else {
      presets = _presetsManager.getPresetsByCategory(_selectedCategory);
    }
    
    if (_searchQuery.isNotEmpty) {
      presets = _presetsManager.searchPresets(_searchQuery);
    }
    
    setState(() {
      _filteredPresets = presets;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _filterPresets();
  }

  void _onCategoryChanged(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _filterPresets();
  }

  Future<void> _selectPreset(AdvancedPreset preset) async {
    try {
      await _presetsManager.selectPreset(preset);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎬 Preset seleccionado: ${preset.name}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Regresar a la pantalla anterior
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error seleccionando preset: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎬 Presets Avanzados'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '📁 Presets', icon: Icon(Icons.video_library)),
            Tab(text: '🔍 Búsqueda', icon: Icon(Icons.search)),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPresetsTab(),
          _buildSearchTab(),
        ],
      ),
    );
  }

  Widget _buildPresetsTab() {
    final categories = ['all', ..._presetsManager.getAvailableCategories()];
    
    return Column(
      children: [
        // Filtro de categorías
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = _selectedCategory == category;
              
              return Container(
                margin: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(
                    category == 'all' ? 'Todos' : _getCategoryDisplayName(category),
                    style: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight: isSelected ? FontWeight.bold : null,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) => _onCategoryChanged(category),
                  backgroundColor: Colors.grey[200],
                  selectedColor: Theme.of(context).colorScheme.primary,
                ),
              );
            },
          ),
        ),
        
        // Lista de presets
        Expanded(
          child: _filteredPresets.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredPresets.length,
                  itemBuilder: (context, index) {
                    final preset = _filteredPresets[index];
                    return _buildPresetCard(preset);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        // Barra de búsqueda
        Container(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: '🔍 Buscar presets...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
        ),
        
        // Resultados de búsqueda
        Expanded(
          child: _filteredPresets.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredPresets.length,
                  itemBuilder: (context, index) {
                    final preset = _filteredPresets[index];
                    return _buildPresetCard(preset);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPresetCard(AdvancedPreset preset) {
    final isSelected = _presetsManager.selectedPreset?.name == preset.name;
    final difficulty = preset.metadata['difficulty'] ?? 'medium';
    final estimatedTime = preset.metadata['estimatedTime'] ?? '2x video duration';
    final category = preset.metadata['category'] ?? 'general';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isSelected ? 8 : 2,
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: () => _showPresetDetails(preset),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con nombre y estado
              Row(
                children: [
                  Expanded(
                    child: Text(
                      preset.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : null,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Descripción
              Text(
                preset.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8) : null,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Metadatos
              Row(
                children: [
                  _buildMetadataChip('📁', _getCategoryDisplayName(category)),
                  const SizedBox(width: 8),
                  _buildMetadataChip('⚡', _getDifficultyDisplayName(difficulty)),
                  const SizedBox(width: 8),
                  _buildMetadataChip('⏱️', estimatedTime),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Información de bloques
              Text(
                '📦 ${preset.blocks.length} bloque${preset.blocks.length != 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7) : Colors.grey[600],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isSelected ? null : () => _selectPreset(preset),
                      icon: Icon(isSelected ? Icons.check : Icons.play_arrow),
                      label: Text(isSelected ? 'Seleccionado' : 'Seleccionar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected 
                            ? Colors.grey 
                            : Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _showPresetDetails(preset),
                    icon: const Icon(Icons.info_outline),
                    tooltip: 'Ver detalles',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataChip(String icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No se encontraron presets',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Intenta cambiar la categoría o la búsqueda',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showPresetDetails(AdvancedPreset preset) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPresetDetailsSheet(preset),
    );
  }

  Widget _buildPresetDetailsSheet(AdvancedPreset preset) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    preset.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          // Contenido
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Descripción
                  Text(
                    'Descripción',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    preset.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Metadatos
                  Text(
                    'Información',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailsMetadata(preset),
                  
                  const SizedBox(height: 24),
                  
                  // Bloques
                  Text(
                    'Bloques de Video',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildBlocksList(preset),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          
          // Botón de acción
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _selectPreset(preset);
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Seleccionar Preset'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsMetadata(AdvancedPreset preset) {
    final metadata = preset.metadata;
    
    return Column(
      children: [
        _buildMetadataRow('Categoría', _getCategoryDisplayName(metadata['category'] ?? 'general')),
        _buildMetadataRow('Dificultad', _getDifficultyDisplayName(metadata['difficulty'] ?? 'medium')),
        _buildMetadataRow('Tiempo Estimado', metadata['estimatedTime'] ?? '2x video duration'),
        if (metadata['createdAt'] != null)
          _buildMetadataRow('Creado', _formatDate(metadata['createdAt'])),
      ],
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildBlocksList(AdvancedPreset preset) {
    return Column(
      children: preset.blocks.asMap().entries.map((entry) {
        final index = entry.key;
        final block = entry.value;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Text('Bloque ${index + 1} (${_formatRange(block.range)})'),
            subtitle: Text('${block.effects.length} efecto${block.effects.length != 1 ? 's' : ''}'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rango: ${_formatRange(block.range)}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text('Efectos:'),
                    ...block.effects.map((effect) => Padding(
                      padding: const EdgeInsets.only(left: 16, top: 4),
                      child: Row(
                        children: [
                          Icon(
                            _getEffectIcon(effect.type),
                            size: 16,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_getEffectDisplayName(effect.type)),
                          ),
                          if (effect.intensity != 1.0)
                            Text(
                              '(${effect.intensity.toStringAsFixed(1)}x)',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Utilidades

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'creative': return 'Creativo';
      case 'dynamic': return 'Dinámico';
      case 'artistic': return 'Artístico';
      case 'fun': return 'Diversión';
      case 'cinematic': return 'Cinematográfico';
      case 'custom': return 'Personalizado';
      default: return category;
    }
  }

  String _getDifficultyDisplayName(String difficulty) {
    switch (difficulty) {
      case 'easy': return 'Fácil';
      case 'medium': return 'Medio';
      case 'hard': return 'Difícil';
      case 'expert': return 'Experto';
      case 'custom': return 'Personalizado';
      default: return difficulty;
    }
  }

  String _formatRange(VideoRange range) {
    final start = (range.startPercentage * 100).round();
    final end = (range.endPercentage * 100).round();
    return '$start% - $end%';
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return isoString;
    }
  }

  IconData _getEffectIcon(EffectType type) {
    switch (type) {
      case EffectType.boomerang: return Icons.replay;
      case EffectType.vhs: return Icons.video_library;
      case EffectType.zoom: return Icons.zoom_in;
      case EffectType.slowMotion: return Icons.slow_motion_video;
      case EffectType.reverse: return Icons.fast_rewind;
      case EffectType.colorFilter: return Icons.palette;
    }
  }

  String _getEffectDisplayName(EffectType type) {
    switch (type) {
      case EffectType.boomerang: return 'Boomerang';
      case EffectType.vhs: return 'Efecto VHS';
      case EffectType.zoom: return 'Zoom';
      case EffectType.slowMotion: return 'Cámara Lenta';
      case EffectType.reverse: return 'Reversa';
      case EffectType.colorFilter: return 'Filtro de Color';
    }
  }
}
