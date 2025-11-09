import 'dart:convert'; import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SavedPlace { final String name; final double lat,lon; final DateTime createdAt;
  SavedPlace({required this.name,required this.lat,required this.lon,required this.createdAt});
  Map<String,dynamic> toJson()=>{'name':name,'lat':lat,'lon':lon,'createdAt':createdAt.toIso8601String()};
  static SavedPlace fromJson(Map<String,dynamic> j)=>SavedPlace(name:j['name'],lat:(j['lat']as num).toDouble(),lon:(j['lon']as num).toDouble(),createdAt:DateTime.parse(j['createdAt']));
}
class PlacesService{
  static const _fileName='places.json'; File? _file; final List<SavedPlace> _items=[];
  Future<void> init() async {
    final dir=await getApplicationDocumentsDirectory(); _file=File('${dir.path}/$_fileName');
    if(await _file!.exists()){ final raw=await _file!.readAsString(); final j=json.decode(raw) as List; _items.addAll(j.map((e)=>SavedPlace.fromJson(e))); }
  }
  List<SavedPlace> list()=>List.unmodifiable(_items);
  Future<void> _flush() async { await _file!.writeAsString(json.encode(_items.map((e)=>e.toJson()).toList())); }
  Future<void> savePlace(String name,double lat,double lon) async { _items.removeWhere((e)=>e.name==name); _items.add(SavedPlace(name:name,lat:lat,lon:lon,createdAt:DateTime.now())); await _flush(); }
  Future<void> delete(String name) async { _items.removeWhere((e)=>e.name==name); await _flush(); }
}
