import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class GpsService {
  bool _inited=false;
  Future<void> init() async {
    if(_inited) return;
    bool ok = await Geolocator.isLocationServiceEnabled();
    var perm = await Geolocator.checkPermission();
    if(perm==LocationPermission.denied){ perm = await Geolocator.requestPermission(); }
    _inited=true;
  }
  Future<Position?> current() async {
    try { return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best); }
    catch(_){ return null; }
  }
  Future<String?> reverse(double lat,double lon) async {
    try {
      final p = await placemarkFromCoordinates(lat,lon);
      if(p.isEmpty) return null;
      final f=p.first; final parts=[f.street,f.subLocality,f.locality,f.administrativeArea];
      return parts.where((e)=> (e??'').trim().isNotEmpty).join(', ');
    } catch(_){ return null; }
  }
  static String speakable(double lat,double lon)=> "Vị trí hiện tại: vĩ độ ${lat.toStringAsFixed(5)}, kinh độ ${lon.toStringAsFixed(5)}.";
}
