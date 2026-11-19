import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/mail_page.dart';
import 'package:sales_mien_tay/session.dart';

const threadId='11111111-1111-4111-8111-111111111111';
const emailId='22222222-2222-4222-8222-222222222222';
const fileId='33333333-3333-4333-8333-333333333333';

class FakeMailSession extends SalesSession {
 String signature='';
 final sendPaths=<String>[];
 Map<String,dynamic>? sentPayload;
 @override Future<Map<String,dynamic>> get(String path) async {
  if(path=='/api/v1/mail/me')return {'mailbox':'info@fbmn.vn','enabled':true,'signature':signature};
  if(path.startsWith('/api/v1/mail/threads?'))return {
   'items':[{'id':threadId,'subject':'Thư thử nghiệm','from':'customer@example.test','read':false}]
  };
  if(path=='/api/v1/mail/threads/$threadId')return {
   'emails':[{'id':emailId,'subject':'Thư thử nghiệm','from':'customer@example.test'}]
  };
  if(path=='/api/v1/mail/threads/$threadId/emails/$emailId')return {
   'item':{
    'id':emailId,'subject':'Thư thử nghiệm',
    'from':'customer@example.test','to':['info@fbmn.vn'],
    'text':'Nội dung thư','attachments':[
      {'id':fileId,'filename':'invoice.pdf','size':4096}]
   }
  };
  throw StateError('Unexpected GET $path');
 }
 @override Future<Map<String,dynamic>> post(String path,Map<String,dynamic> data) async {
  if(path=='/api/v1/mail/threads/$threadId/read')return {'ok':true};
  throw StateError('Unexpected POST $path');
 }
 @override Future<Map<String,dynamic>> postMail(String path,Map<String,dynamic> data) async {
  sendPaths.add(path);sentPayload=data;return {'status':'sent'};
 }
 @override Future<Map<String,dynamic>> putMail(String path,Map<String,dynamic> data) async {
  if(path!='/api/v1/mail/signature')throw StateError('Wrong setting path');
  signature=data['signature'].toString();
  return {'signature':signature};
 }
}

void main(){
 testWidgets('read view has visible back and reply; reply returns to thread',(tester) async {
  tester.view.physicalSize=const Size(390,844);
  tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final session=FakeMailSession();
  await tester.pumpWidget(MaterialApp(home:StaffMailPage(session:session)));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Thư thử nghiệm'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Thư thử nghiệm'));
  await tester.pumpAndSettle();

  expect(find.byTooltip('Về hội thoại'),findsOneWidget);
  expect(find.byTooltip('Trả lời thư này'),findsOneWidget);
  expect(find.text('invoice.pdf'),findsOneWidget);

  await tester.tap(find.byTooltip('Trả lời thư này'));
  await tester.pumpAndSettle();
  expect(find.text('Trả lời · info@fbmn.vn'),findsOneWidget);
  expect(find.text('Đính kèm tệp (4 tệp, tổng 5 MB)'),findsOneWidget);
  await tester.enterText(find.byType(TextField).last,'Đã nhận, cảm ơn!');
  await tester.tap(find.text('Gửi email'));
  await tester.pumpAndSettle();

  expect(session.sendPaths.single,
   '/api/v1/mail/threads/$threadId/emails/$emailId/reply');
  expect(session.sentPayload?['text'],'Đã nhận, cảm ơn!');
  expect(find.text('Về danh sách'),findsOneWidget);
  await tester.tap(find.text('Về danh sách'));
  await tester.pumpAndSettle();
  expect(find.text('Thư đến'),findsOneWidget);
 });

 testWidgets('signature setting is scoped to the active inbox and shown on compose',(tester) async{
  tester.view.physicalSize=const Size(390,844);
  tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final session=FakeMailSession();
  await tester.pumpWidget(MaterialApp(home:StaffMailPage(session:session)));
  await tester.pumpAndSettle();

  await tester.tap(find.byTooltip('Thiết lập chữ ký'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField),'Công ty FBMN - Bộ phận CSKH');
  await tester.tap(find.text('Lưu chữ ký'));
  await tester.pumpAndSettle();
  expect(session.signature,'Công ty FBMN - Bộ phận CSKH');

  await tester.tap(find.byTooltip('Soạn email'));
  await tester.pumpAndSettle();
  expect(find.text('Công ty FBMN - Bộ phận CSKH'),findsOneWidget);
  expect(find.text('Đính kèm tệp (4 tệp, tổng 5 MB)'),findsOneWidget);
 });
}
