import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/route_template_library.dart';

void main(){
 test('only a matching directly owned route can accept a template',(){
  final template={'scope_kind':'territory','scope_key':'Ben Tre|Binh Dai'};
  final route={'owner_sub':'sales-a','status':'ready','plan_status':'planned',
   'scope_kind':'territory','scope_key':'Ben Tre|Binh Dai'};
  expect(routeTemplateMatchesRoute(template,route,'sales-a'),isTrue);
  expect(routeTemplateMatchesRoute(template,route,'manager'),isFalse);
  expect(routeTemplateMatchesRoute(template,{...route,'scope_key':'Ben Tre|Ba Tri'},'sales-a'),isFalse);
  expect(routeTemplateMatchesRoute(template,{...route,'plan_status':'cancelled'},'sales-a'),isFalse);
 });
}
