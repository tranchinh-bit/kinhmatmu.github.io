class BearingSide { static const left='trái', center='giữa', right='phải'; }
String bearingOf(double x1,double x2,double W){ final cx=(x1+x2)/2.0; if(cx<W*0.33) return BearingSide.left; if(cx>W*0.66) return BearingSide.right; return BearingSide.center; }
String viName(String c){ switch(c){
  case 'person': return 'người'; case 'bicycle': return 'xe đạp'; case 'motorcycle': return 'xe máy'; case 'car': return 'ô tô';
  case 'bus': return 'xe buýt'; case 'truck': return 'xe tải'; case 'traffic light': return 'đèn giao thông'; case 'stop sign': return 'biển dừng';
  case 'bench': return 'băng ghế'; case 'chair': return 'ghế'; case 'dog': return 'chó'; case 'cat': return 'mèo'; case 'pole': return 'cọc';
  default: return 'vật cản'; } }
int riskLevel(String cls,double distM,String bearing,{double conf=0.9}){
  double wClass=(cls=='person')?1.0:(['bicycle','motorcycle','car'].contains(cls)?1.2:(['bus','truck'].contains(cls)?1.4:0.6));
  double wDist=distM<1.2?1.0:(distM<2.5?0.6:0.3); double wBearing=bearing=='giữa'?1.0:0.7; final c=conf.clamp(0.5,1.0);
  final s=100*wClass*wDist*wBearing*c; if(s>=55) return 3; if(s>=40) return 2; if(s>=25) return 1; return 0;
}
