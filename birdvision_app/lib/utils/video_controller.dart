import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'video_controller_web.dart'
    if (dart.library.io) 'video_controller_io.dart' as platform;

/// Crée un lecteur pour une vidéo choisie avec image_picker.
///
/// - Web : `XFile.path` est une URL blob → `networkUrl`.
/// - Android / iOS / desktop : c'est un vrai fichier → `file`.
VideoPlayerController controllerForPickedVideo(XFile video) =>
    platform.controllerForPickedVideo(video);
