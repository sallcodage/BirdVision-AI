/// Modèles d'IA proposés par le backend.
class DetectorModel {
  final String id;
  final String name;
  final String description;

  const DetectorModel(this.id, this.name, this.description);

  static const all = [
    DetectorModel('rtdetr-x', 'RT-DETR-X', 'Transformer · très précis'),
    DetectorModel('yolo26s', 'YOLO26s', 'Le plus rapide'),
    DetectorModel('dfine-x', 'D-FINE-X', 'Très fin · plus lent'),
  ];

  static String nameOf(String? id) {
    for (final model in all) {
      if (model.id == id) return model.name;
    }
    return id ?? '—';
  }
}

class BirdDetection {
  final double confidence;
  final double x1, y1, x2, y2;

  const BirdDetection({
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  factory BirdDetection.fromJson(Map<String, dynamic> json) {
    final box = (json['box'] as Map?) ?? const {};
    double d(Object? v) => double.tryParse(v.toString()) ?? 0;
    return BirdDetection(
      confidence: d(json['confidence']),
      x1: d(box['x1']),
      y1: d(box['y1']),
      x2: d(box['x2']),
      y2: d(box['y2']),
    );
  }
}

class ImageDetectionResult {
  final String model;
  final int birdCount;
  final double confidenceThreshold;
  final List<BirdDetection> detections;
  final String? resultImageUrl;

  const ImageDetectionResult({
    required this.model,
    required this.birdCount,
    required this.confidenceThreshold,
    required this.detections,
    this.resultImageUrl,
  });

  double? get averageConfidence {
    if (detections.isEmpty) return null;
    final sum = detections.fold<double>(0, (s, d) => s + d.confidence);
    return sum / detections.length;
  }

  factory ImageDetectionResult.fromJson(Map<String, dynamic> json) {
    final detections = ((json['detections'] as List?) ?? const [])
        .whereType<Map>()
        .map((d) => BirdDetection.fromJson(Map<String, dynamic>.from(d)))
        .toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    return ImageDetectionResult(
      model: json['model']?.toString() ?? '',
      birdCount: int.tryParse(json['bird_count'].toString()) ??
          detections.length,
      confidenceThreshold:
          double.tryParse(json['confidence_threshold'].toString()) ?? 0,
      detections: detections,
      resultImageUrl: json['result_image']?.toString(),
    );
  }
}

class VideoDetectionResult {
  final String model;
  final double confidenceThreshold;
  final int framesTotal;
  final int framesAnalyzed;
  final double? durationSeconds;
  final int totalBirdDetections;
  final int maxBirdsInFrame;
  final String resultVideoUrl;

  const VideoDetectionResult({
    required this.model,
    required this.confidenceThreshold,
    required this.framesTotal,
    required this.framesAnalyzed,
    required this.durationSeconds,
    required this.totalBirdDetections,
    required this.maxBirdsInFrame,
    required this.resultVideoUrl,
  });

  factory VideoDetectionResult.fromJson(Map<String, dynamic> json) {
    int i(Object? v) => int.tryParse(v.toString()) ?? 0;
    final analyzed = i(json['frames_analyzed']);
    return VideoDetectionResult(
      model: json['model']?.toString() ?? '',
      confidenceThreshold:
          double.tryParse(json['confidence_threshold'].toString()) ?? 0,
      framesTotal: json['frames_total'] == null
          ? analyzed
          : i(json['frames_total']),
      framesAnalyzed: analyzed,
      durationSeconds:
          double.tryParse(json['duration_seconds']?.toString() ?? ''),
      totalBirdDetections: i(json['total_bird_detections']),
      maxBirdsInFrame: i(json['max_birds_in_frame']),
      resultVideoUrl: json['result_video'].toString(),
    );
  }
}
