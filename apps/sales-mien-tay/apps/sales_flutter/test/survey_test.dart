import 'package:flutter_test/flutter_test.dart';
import '../lib/surveys.dart';
void main(){
 test('required checklist accepts false and zero but rejects missing or invalid answers',(){
  final qs=<Map<String,dynamic>>[{'id':'b','label':'B','type':'boolean','required':true},{'id':'n','label':'N','type':'number','required':true},{'id':'c','label':'C','type':'choice','required':true,'options':['A','B']}];
  expect(checklistError(qs,{'b':false,'n':0,'c':'A'}),isNull);
  expect(checklistError(qs,{'b':false,'n':-1,'c':'A'}),isNotNull);
  expect(checklistError(qs,{'b':false,'n':0,'c':'X'}),isNotNull);
  expect(checklistError(qs,{}),isNotNull);
 });
 test('offline completion is not verified completion',(){
  expect(surveyStatus({'status':'completed_pending','server_status':'in_progress'}),'Chờ xác minh hoàn thành');
  expect(surveyStatus({'status':'completed_pending','server_status':'completed'}),'Hoàn thành');
 });
}
