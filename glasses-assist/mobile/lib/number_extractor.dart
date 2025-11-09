class NumberExtractor {
  static final RegExp rePhone = RegExp(r'(0|\+84)[0-9]{8,10}');
  static final RegExp reMoney = RegExp(r'([0-9]{1,3}([.,][0-9]{3})+|[0-9]+)(\\s?)(đ|vnd|vnđ)', caseSensitive:false);
  static final RegExp rePlain = RegExp(r'[0-9]{2,}');
  static Map<String, List<String>> extractAll(String text){
    final phone = rePhone.allMatches(text).map((m)=>m.group(0)!).toSet().toList();
    final money = reMoney.allMatches(text).map((m)=>m.group(0)!).toSet().toList();
    final nums = rePlain.allMatches(text).map((m)=>m.group(0)!).where((s)=>!phone.contains(s)).toSet().toList();
    return {'phone':phone,'money':money,'numbers':nums};
  }
  static String speak(Map<String,List<String>> m){
    final parts=<String>[];
    if(m['phone']!.isNotEmpty) parts.add('Số điện thoại: ${m['phone']!.join(", ")}');
    if(m['money']!.isNotEmpty) parts.add('Giá tiền: ${m['money']!.join(", ")}');
    if(m['numbers']!.isNotEmpty) parts.add('Các số: ${m['numbers']!.take(3).join(", ")}');
    return parts.isEmpty?'Không thấy số rõ.':parts.join('. ');
  }
}
