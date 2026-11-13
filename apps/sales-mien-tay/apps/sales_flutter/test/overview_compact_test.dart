import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/main.dart';
import 'package:sales_mien_tay/models.dart';

void main() {
  for (final width in [320.0,360.0,390.0,780.0,1280.0,1440.0]) {
    testWidgets('overview KPIs stay compact at $width',(tester)async{
      tester.view.devicePixelRatio=1;
      tester.view.physicalSize=Size(width,860);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var targetTaps=0;
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(
        child:Padding(padding:const EdgeInsets.all(18),
          child:SalesOverviewKpis(surveyed:11,planned:'125.000.000 đ',
            brandPresence:3,onTarget:()=>targetTaps++))))));
      expect(tester.takeException(),isNull);
      expect(find.text('11'),findsOneWidget);
      expect(find.text('3'),findsOneWidget);
      expect(find.text('125.000.000 đ'),findsOneWidget);
      final view=tester.widget<GridView>(find.byType(GridView));
      final grid=view.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(grid.crossAxisCount,width>=936?4:width>=321?2:1);
      expect(grid.mainAxisExtent,124);
      // Height must not depend on width, so a 360px phone cannot show 260px tiles.
      expect(tester.getSize(find.byType(Card).first).height,124);
      await tester.tap(find.text('Xem chỉ tiêu'));
      expect(targetTaps,1);
    });
  }
  testWidgets('market footprint counts customer-brand pairs, never SKU or survey volume',(tester)async{
    const legacy=<SalesRecord>[SalesRecord(id:'1',kind:'survey',province:'Sóc Trăng',
      data:{'brands':['MGP'],'distributors':['NPP']})];
    await tester.pumpWidget(const MaterialApp(home:Scaffold(body:SingleChildScrollView(child:
      SalesBrandCoverageTable(surveys:legacy,provinces:['Sóc Trăng'],
       verifiedData:true,brandNames:['MGP','Thành Đạt'],
       customerCounts:[{'province':'Sóc Trăng','district':'Mỹ Xuyên','customers':5}],
       verifiedRows:[
        {'province':'Sóc Trăng','district':'Mỹ Xuyên','brand':'MGP','customers':1},
        {'province':'Sóc Trăng','district':'Mỹ Xuyên','brand':'Thành Đạt','customers':1},
       ]))))));
    expect(tester.takeException(),isNull);
    final table=tester.widget<DataTable>(find.byType(DataTable));
    expect(table.columns.map((c)=>(c.label as Text).data).toList(),
      ['Tỉnh / Huyện','Khách','MGP','Thành Đạt']);
    expect((table.rows.single.cells[1].child as Text).data,'5');
    expect((table.rows.single.cells[2].child as Text).data,'1');
    expect((table.rows.single.cells[3].child as Text).data,'1');
    expect(find.textContaining('không cộng dồn lượt'),findsOneWidget);
    expect(find.textContaining('Đã đặt'),findsNothing);
  });
}
