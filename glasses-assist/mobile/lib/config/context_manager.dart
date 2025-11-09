import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class ProfileConfig {
  final int snapshotMs; final double scoreThresh; final double nmsIou;
  final int debounceFrames; final double ttsGapSec; final double kDistance;
  final List<String> classes; final bool disabled; final bool quiet; final bool ocr; final bool modal; final String? inherit;
  ProfileConfig({required this.snapshotMs, required this.scoreThresh, required this.nmsIou,
    required this.debounceFrames, required this.ttsGapSec, required this.kDistance,
    required this.classes, this.disabled=false, this.quiet=false, this.ocr=false, this.modal=false, this.inherit});
  static ProfileConfig fromMap(Map<String,dynamic> m)=> ProfileConfig(
    snapshotMs:(m['snapshot_ms']??0) as int, scoreThresh:(m['score_thresh']??0.0).toDouble(),
    nmsIou:(m['nms_iou']??0.0).toDouble(), debounceFrames:(m['debounce_frames']??0) as int,
    ttsGapSec:(m['tts_gap_sec']??0.0).toDouble(), kDistance:(m['k_distance']??0.0).toDouble(),
    classes:(m['classes'] as List?)?.map((e)=>e.toString()).toList()??<String>[],
    disabled:(m['disabled']??false) as bool, quiet:(m['quiet']??false) as bool,
    ocr:(m['ocr']??false) as bool, modal:(m['modal']??false) as bool, inherit:m['inherit'] as String?);
  factory ProfileConfig.merge(ProfileConfig base, ProfileConfig d)=> ProfileConfig(
    snapshotMs: d.snapshotMs!=0?d.snapshotMs:base.snapshotMs,
    scoreThresh: d.scoreThresh!=0?d.scoreThresh:base.scoreThresh,
    nmsIou: d.nmsIou!=0?d.nmsIou:base.nmsIou,
    debounceFrames: d.debounceFrames!=0?d.debounceFrames:base.debounceFrames,
    ttsGapSec: d.ttsGapSec!=0?d.ttsGapSec:base.ttsGapSec,
    kDistance: d.kDistance!=0?d.kDistance:base.kDistance,
    classes: d.classes.isNotEmpty?d.classes:base.classes,
    disabled: d.disabled||base.disabled, quiet: d.quiet||base.quiet, ocr: d.ocr||base.ocr, modal: d.modal||base.modal, inherit: d.inherit??base.inherit);
}

class ContextManager {
  final Map<String,ProfileConfig> _p={};
  Future<void> load() async {
    final txt = await rootBundle.loadString('assets/config/contexts.json');
    final raw = (json.decode(txt) as Map)['profiles'] as Map<String,dynamic>;
    raw.forEach((k,v)=>_p[k]=ProfileConfig.fromMap(v));
    raw.forEach((k,v){ final inh=v['inherit']; if (inh!=null&&_p.containsKey(inh)){ _p[k]=ProfileConfig.merge(_p[inh]!, _p[k]!); }});
  }
  ProfileConfig get(String name){ final p=_p[name]; if(p==null) throw Exception('Profile $name not found'); return p; }
  List<String> list()=> _p.keys.toList();
}
