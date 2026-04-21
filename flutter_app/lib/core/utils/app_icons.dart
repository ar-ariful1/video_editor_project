// lib/core/utils/app_icons.dart
// All icon constants used throughout the app

import 'package:flutter/material.dart';

class AppIcons {
  // ── Editor Tools ──────────────────────────────────────────────────────────
  static const IconData timeline = Icons.timeline;
  static const IconData text = Icons.text_fields_rounded;
  static const IconData effects = Icons.auto_awesome;
  static const IconData audio = Icons.music_note_rounded;
  static const IconData color = Icons.palette_rounded;
  static const IconData sticker = Icons.emoji_emotions_rounded;
  static const IconData ai = Icons.smart_toy_rounded;
  static const IconData speed = Icons.speed_rounded;
  static const IconData crop = Icons.crop_rounded;
  static const IconData keyframe = Icons.linear_scale_rounded;
  static const IconData transition = Icons.blur_linear_rounded;
  static const IconData adjust = Icons.tune_rounded;
  static const IconData beauty = Icons.face_retouching_natural_rounded;
  static const IconData chromaKey = Icons.auto_fix_high_rounded;
  static const IconData mask = Icons.filter_b_and_w_rounded;
  static const IconData pip = Icons.picture_in_picture_alt_rounded;
  static const IconData tts = Icons.record_voice_over_rounded;
  static const IconData voiceover = Icons.mic_rounded;

  // ── Playback ──────────────────────────────────────────────────────────────
  static const IconData play = Icons.play_arrow_rounded;
  static const IconData pause = Icons.pause_rounded;
  static const IconData stop = Icons.stop_rounded;
  static const IconData rewind = Icons.fast_rewind_rounded;
  static const IconData forward = Icons.fast_forward_rounded;
  static const IconData skipPrev = Icons.skip_previous_rounded;
  static const IconData skipNext = Icons.skip_next_rounded;
  static const IconData loop = Icons.loop_rounded;

  // ── Timeline ops ─────────────────────────────────────────────────────────
  static const IconData split = Icons.content_cut_rounded;
  static const IconData duplicate = Icons.copy_all_rounded;
  static const IconData delete = Icons.delete_rounded;
  static const IconData lock = Icons.lock_rounded;
  static const IconData unlock = Icons.lock_open_rounded;
  static const IconData mute = Icons.volume_off_rounded;
  static const IconData unmute = Icons.volume_up_rounded;
  static const IconData addTrack = Icons.add_box_rounded;
  static const IconData undo = Icons.undo_rounded;
  static const IconData redo = Icons.redo_rounded;

  // ── Export ────────────────────────────────────────────────────────────────
  static const IconData export_ = Icons.upload_rounded;
  static const IconData share = Icons.share_rounded;
  static const IconData download = Icons.download_rounded;
  static const IconData quality = Icons.hd_rounded;

  // ── Navigation ────────────────────────────────────────────────────────────
  static const IconData home = Icons.home_rounded;
  static const IconData projects = Icons.folder_rounded;
  static const IconData templates = Icons.auto_stories_rounded;
  static const IconData profile = Icons.person_rounded;
  static const IconData settings = Icons.settings_rounded;
  static const IconData back = Icons.arrow_back_ios_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData menu = Icons.more_vert_rounded;
  static const IconData search = Icons.search_rounded;
  static const IconData filter = Icons.filter_list_rounded;

  // ── Plan / Subscription ───────────────────────────────────────────────────
  static const IconData crown = Icons.workspace_premium_rounded;
  static const IconData star = Icons.star_rounded;
  static const IconData upgrade = Icons.rocket_launch_rounded;
  static const IconData checkmark = Icons.check_circle_rounded;

  // ── AI ────────────────────────────────────────────────────────────────────
  static const IconData caption = Icons.closed_caption_rounded;
  static const IconData bgRemove = Icons.person_remove_rounded;
  static const IconData tracking = Icons.track_changes_rounded;
  static const IconData upscale = Icons.zoom_out_map_rounded;
  static const IconData beatDetect = Icons.music_note_rounded;
  static const IconData smartCrop = Icons.crop_free_rounded;

  // ── File & Media ──────────────────────────────────────────────────────────
  static const IconData video = Icons.videocam_rounded;
  static const IconData image = Icons.image_rounded;
  static const IconData music = Icons.library_music_rounded;
  static const IconData camera = Icons.photo_camera_rounded;
  static const IconData gallery = Icons.photo_library_rounded;
  static const IconData folder = Icons.folder_open_rounded;

  // ── Text ─────────────────────────────────────────────────────────────────
  static const IconData bold = Icons.format_bold_rounded;
  static const IconData italic = Icons.format_italic_rounded;
  static const IconData alignLeft = Icons.format_align_left_rounded;
  static const IconData alignCenter = Icons.format_align_center_rounded;
  static const IconData alignRight = Icons.format_align_right_rounded;
  static const IconData fontColor = Icons.format_color_text_rounded;
  static const IconData shadow = Icons.blur_on_rounded;

  // ── Misc ─────────────────────────────────────────────────────────────────
  static const IconData info = Icons.info_outline_rounded;
  static const IconData warning = Icons.warning_rounded;
  static const IconData error = Icons.error_rounded;
  static const IconData success = Icons.check_circle_rounded;
  static const IconData refresh = Icons.refresh_rounded;
  static const IconData cloud = Icons.cloud_done_rounded;
  static const IconData cloudSync = Icons.cloud_sync_rounded;
  static const IconData analytics_rounded = Icons.analytics_rounded;
  static const IconData history_rounded = Icons.history_rounded;
  static const IconData edit_rounded = Icons.edit_rounded;
}

// ── Asset paths ───────────────────────────────────────────────────────────────
class AppAssets {
  // Fonts
  static const String fontInter = 'assets/fonts/Inter-Regular.ttf';
  static const String fontInterBold = 'assets/fonts/Inter-Bold.ttf';

  // Animations
  static const String animLoading = 'assets/animations/loading.json';
  static const String animSuccess = 'assets/animations/success.json';
  static const String animExport = 'assets/animations/export.json';
  static const String animEmpty = 'assets/animations/empty.json';
  static const String animAI = 'assets/animations/ai_processing.json';

  // LUTs
  static const String lutCinematic = 'assets/luts/cinematic.cube';
  static const String lutWarm = 'assets/luts/warm.cube';
  static const String lutCool = 'assets/luts/cool.cube';
  static const String lutVintage = 'assets/luts/vintage.cube';
  static const String lutMatte = 'assets/luts/matte.cube';
  static const String lutKodak = 'assets/luts/kodak.cube';
  static const String lutFuji = 'assets/luts/fuji.cube';
  static const String lutTealOrange = 'assets/luts/teal_orange.cube';

  // Sound effects
  static const String sfxSplit = 'assets/sounds/split.mp3';
  static const String sfxDelete = 'assets/sounds/delete.mp3';
  static const String sfxSuccess = 'assets/sounds/success.mp3';
  static const String sfxExportDone = 'assets/sounds/export_done.mp3';
}

// ── App Strings ───────────────────────────────────────────────────────────────
class AppStrings {
  // App
  static const String appName = 'ClipCut';
  static const String tagline = 'Professional editing in your pocket';

  // Auth
  static const String signIn = 'Sign In';
  static const String signUp = 'Sign Up';
  static const String signOut = 'Sign Out';
  static const String continueWith = 'Continue with';
  static const String google = 'Google';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String forgotPass = 'Forgot password?';

  // Editor
  static const String newProject = 'New Project';
  static const String untitled = 'Untitled Project';
  static const String exportVideo = 'Export Video';
  static const String addMedia = 'Add Media';
  static const String addText = 'Add Text';
  static const String addAudio = 'Add Audio';

  // Plans
  static const String free = 'Free';
  static const String pro = 'Pro';
  static const String premium = 'Premium';
  static const String upgradePro = 'Upgrade to Pro';
  static const String upgradePremium = 'Upgrade to Premium';
  static const String proPrice = '\$4.99/month';
  static const String premiumPrice = '\$9.99/month';

  // AI
  static const String autoCaptions = 'Auto Captions';
  static const String bgRemoval = 'Background Removal';
  static const String objectTrack = 'Object Tracking';
  static const String upscale4k = '4K AI Upscaling';
  static const String beatDetect = 'Beat Detection';
  static const String smartCrop = 'Smart Crop';

  // Errors
  static const String networkError = 'No internet connection';
  static const String genericError = 'Something went wrong. Please try again.';
  static const String selectClip = 'Select a clip on the timeline first';
}
