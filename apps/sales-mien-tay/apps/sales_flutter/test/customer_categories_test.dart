import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/customer_categories.dart';

void main(){
  test('industry categories preserve old ids and distinguish icon plus color',(){
    expect(CustomerCategory.all.map((c)=>c.id).toSet().length,CustomerCategory.all.length);
    final byId={for(final c in CustomerCategory.all)c.id:c};
    for(final id in ['npp','dai_ly','nha_sach','van_phong_pham','sieu_thi',
        'tap_hoa','cua_hang','truong_hoc','khach_le','khac']){
      expect(byId[id],isNotNull);
      expect(byId[id]!.label,isNotEmpty);
    }
    expect(byId['npp']!.color,const Color(0xFFE48223));
    expect(byId['dai_ly']!.color,const Color(0xFF6D249E));
    expect(byId['nha_sach']!.color,const Color(0xFF2675CE));
    expect(byId['van_phong_pham']!.color,const Color(0xFF25874E));
    expect(byId['khach_le']!.icon,Icons.person_outline);
    expect(byId['khach_le']!.label,'Khách lẻ');
    expect(byId['khach_le']!.color,const Color(0xFFC13C82));
    expect(CustomerCategory.all.map((c)=>c.color).toSet().length,CustomerCategory.all.length);
    expect(CustomerCategory.all.map((c)=>c.icon).toSet().length,CustomerCategory.all.length);
    expect(byId['npp']!.icon,isNot(byId['dai_ly']!.icon));
    expect(byId['dai_ly']!.icon,isNot(byId['nha_sach']!.icon));
    expect(CustomerCategory.fromId('unknown').id,'khac');
  });
  testWidgets('customer icon and human readable label match stored id',(tester)async{
    await tester.pumpWidget(const MaterialApp(home:Scaffold(body:Column(children:[
      CustomerCategoryAvatar(category:'nha_sach'),
      CustomerCategoryLabel(category:'nha_sach'),
    ]))));
    expect(find.byIcon(Icons.menu_book_outlined),findsNWidgets(2));
    expect(find.text('Nhà sách'),findsOneWidget);
    final avatar=tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundColor,CustomerCategory.fromId('nha_sach').color.withValues(alpha:.20));
  });
}
