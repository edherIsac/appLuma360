// import 'dart:convert';

class ConfigCabina {
  final int duration;
  final bool enabledVideoFilter;
  final bool enabledContornoVideo;
  final bool enabledLogo;
  final bool enabledAudioFondo;
  final String contornoVideo;
  final String audioFondo;
  final String logoPosition;
  final String whatsApp;
  final bool enabledINTERNET;
  final bool useFrontCamera; // NUEVO: Preferencia de cámara
  final String wifiName; // NUEVO: Nombre de la red WiFi
  final String videoResolution; // NUEVO: Resolución de grabación

  ConfigCabina({
    required this.duration,
    required this.enabledVideoFilter,
    required this.enabledContornoVideo,
    required this.enabledLogo,
    required this.enabledAudioFondo,
    required this.contornoVideo,
    required this.audioFondo,
    required this.logoPosition,
    required this.whatsApp,
    required this.enabledINTERNET,
    this.useFrontCamera = false, // Por defecto cámara trasera
    this.wifiName = '', // Por defecto vacío
    this.videoResolution = 'medium', // Por defecto medium
  });

  factory ConfigCabina.fromJson(Map<String, dynamic> json) {
    return ConfigCabina(
      duration: json['duration'] ?? 15,
      enabledVideoFilter: json['enabledVideoFilter'] ?? false,
      enabledContornoVideo: json['enabledContornoVideo'] ?? false,
      enabledLogo: json['enabledLogo'] ?? false,
      enabledAudioFondo: json['enabledAudioFondo'] ?? false,
      contornoVideo: json['contornoVideo'] ?? '1',
      audioFondo: json['audioFondo'] ?? '1',
      logoPosition: json['logoPosition'] ?? 'rb',
      whatsApp: json['whatsApp'] ?? '',
      enabledINTERNET: json['enabledINTERNET'] ?? false,
      useFrontCamera: json['useFrontCamera'] ?? false, // NUEVO
      wifiName: json['wifiName'] ?? '', // NUEVO
      videoResolution: json['videoResolution'] ?? 'medium', // NUEVO
    );
  }
}

class QualityChange {
  final int quality;

  QualityChange({required this.quality});

  factory QualityChange.fromJson(Map<String, dynamic> json) {
    return QualityChange(
      quality: json['quality'] ?? 2,
    );
  }
}
