import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

VideoPlayerController controllerForPickedVideo(XFile video) =>
    VideoPlayerController.networkUrl(Uri.parse(video.path));
