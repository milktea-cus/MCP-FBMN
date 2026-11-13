import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/work_hub.dart';
import 'package:sales_mien_tay/day_route.dart';

void main(){
 test('plan vs actual does not count check-in as completed survey',(){
  final result=WorkCounts.fromRoutes([
   {'stop_count':5,'visited_count':2,'missed_count':1,
    'survey_count':0,'lead_count':2,'unplanned_count':3,'unplanned_visited_count':1},
  ]);
  expect(result.planned,5);
  expect(result.visited,2);
  expect(result.notVisited,3);
  expect(result.missed,1);
  expect(result.withoutReason,2);
  expect(result.surveys,0);
  expect(result.leads,2);
  expect(result.unplanned,3);
  expect(result.unplannedVisited,1);
 });
 test('totals across routes do not merge plans with outside-plan visits',(){
  final result=WorkCounts.fromRoutes([
   {'stop_count':1,'visited_count':1,'survey_count':1,'lead_count':0},
   {'stop_count':3,'visited_count':1,'survey_count':0,'lead_count':2,
    'unplanned_count':1,'unplanned_visited_count':1,'missed_count':1},
  ]);
  expect(result.planned,4);
  expect(result.visited,2);
  expect(result.notVisited,2);
  expect(result.surveys,1);
  expect(result.unplannedVisited,1);
  expect(result.leads,2);
  expect(result.withoutReason,1);
 });
 test('counts from cached older routes remain nonnegative',(){
  final result=WorkCounts.fromRoutes([
   {'stop_count':1,'visited_count':2,'survey_count':null,'lead_count':-1},
  ]);
  expect(result.notVisited,0);
  expect(result.withoutReason,0);
  expect(result.leads,0);
 });
 test('missed reasons stay distinct from GPS and planned status',(){
  expect(missedReasonLabel('closed'),'Khách đóng cửa');
  expect(missedReasonLabel('unavailable'),'Không gặp được khách');
  expect(scopeSupportsExtra({'scope_kind':'territory'}),isTrue);
  expect(scopeSupportsExtra({'scope_kind':'chain'}),isTrue);
  expect(scopeSupportsExtra({'scope_kind':'customer'}),isFalse);
 });
}
