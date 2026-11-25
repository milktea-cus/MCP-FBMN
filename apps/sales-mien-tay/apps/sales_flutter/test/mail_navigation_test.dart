import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_mien_tay/mail_page.dart';
import 'package:sales_mien_tay/session.dart';

const threadId='11111111-1111-4111-8111-111111111111';
const emailId='22222222-2222-4222-8222-222222222222';
const fileId='33333333-3333-4333-8333-333333333333';

class FakeMailSession extends SalesSession {
 final sendPaths=<String>[];
 Map<String,dynamic>? sentPayload;
 @override Future<Map<String,dynamic>> get(String path) async {
  if(path=='/api/v1/mail/me')return {'mailbox':'info@fbmn.vn','enabled':true};
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
  sendPaths.add(path);sentPayload=data;return {'status':'sent','id':emailId};
 }

}

const otherThread='44444444-4444-4444-8444-444444444444';
const otherEmail='55555555-5555-4555-8555-555555555555';
class PagingMailSession extends FakeMailSession{
 final slow=Completer<Map<String,dynamic>>();
 final reads=<String>[];
 @override Future<Map<String,dynamic>> get(String path)async{
  if(path=='/api/v1/mail/threads?folder=inbox')return {
   'items':[{'id':threadId,'subject':'Hội thoại đầu'}],'has_more':true,'next_cursor':threadId};
  if(path=='/api/v1/mail/threads?folder=inbox&after=$threadId')return {
   'items':[{'id':threadId,'subject':'Hội thoại đầu'},{'id':otherThread,'subject':'Hội thoại sau'}],'has_more':false};
  if(path=='/api/v1/mail/threads/$threadId')return {
   'emails':[{'id':emailId,'subject':'Thư chậm'},{'id':otherEmail,'subject':'Thư nhanh'}],
   'has_more':true,'next_cursor':otherEmail};
  if(path=='/api/v1/mail/threads/$threadId?after=$otherEmail')return {
   'emails':[{'id':fileId,'subject':'Thư trang tiếp'}],'has_more':false};
  if(path=='/api/v1/mail/threads/$threadId/emails/$emailId')return slow.future;
  if(path=='/api/v1/mail/threads/$threadId/emails/$otherEmail')return {
   'item':{'id':otherEmail,'subject':'Thư nhanh','text':'Nội dung đúng'}};
  return super.get(path);
 }
 @override Future<Map<String,dynamic>> post(String path,Map<String,dynamic> data)async{
  reads.add(path);return super.post(path,data);
 }
}
class RetryMailSession extends FakeMailSession{
 final attempts=<Map<String,dynamic>>[];
 @override Future<Map<String,dynamic>> postMail(String path,Map<String,dynamic> data)async{
  attempts.add(Map<String,dynamic>.from(data));
  if(attempts.length==1)return {'error':'Malformed provider success'};
  if(attempts.length<5)throw const ApiFailure(503,'Chưa xác nhận');
  return {'status':'sent','id':emailId};
 }
}
void main(){
 testWidgets('refresh preserves exact message and thread',(tester)async{
  final session=FakeMailSession();
  await tester.pumpWidget(MaterialApp(home:StaffMailPage(session:session)));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Thư thử nghiệm'));await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Làm mới'));await tester.pumpAndSettle();
  expect(find.text('Hội thoại'),findsOneWidget);
  await tester.tap(find.text('Thư thử nghiệm'));await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Làm mới'));await tester.pumpAndSettle();
  expect(find.text('Đọc email'),findsOneWidget);
  expect(find.text('Nội dung thư'),findsOneWidget);
 });
 testWidgets('mail malformed success retains composer and retry UUID follows content',(tester)async{
  final session=RetryMailSession();
  await tester.pumpWidget(MaterialApp(home:StaffMailPage(session:session)));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Soạn email'));await tester.pumpAndSettle();
  final fields=find.byType(TextField);
  await tester.enterText(fields.at(0),'client@example.test');
  await tester.enterText(fields.at(1),'Subject');
  await tester.enterText(fields.at(2),'Original');
  Future<void> send()async{
   await tester.tap(find.text('Gửi email'));await tester.pumpAndSettle();
  }
  await send();
  expect(find.textContaining('Chưa xác nhận gửi thư thành công'),findsOneWidget);
  await send();
  await tester.enterText(fields.at(2),'Changed');await send();
  await tester.enterText(fields.at(2),'Original');await send();
  expect(session.attempts[0]['request_id'],session.attempts[1]['request_id']);
  expect(session.attempts[0]['request_id'],isNot(session.attempts[2]['request_id']));
  expect(session.attempts[0]['request_id'],session.attempts[3]['request_id']);
  await send();
  expect(find.text('Soạn thư · info@fbmn.vn'),findsNothing);
  expect(session.attempts[0]['request_id'],session.attempts[4]['request_id']);
 });

 testWidgets('mail pagination merges IDs and stale message completion cannot overwrite current mail',(tester)async{
  final session=PagingMailSession();
  await tester.pumpWidget(MaterialApp(home:StaffMailPage(session:session)));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tải thêm hội thoại'));await tester.pumpAndSettle();
  expect(find.text('Hội thoại đầu'),findsOneWidget);
  expect(find.text('Hội thoại sau'),findsOneWidget);
  await tester.tap(find.text('Hội thoại đầu'));await tester.pumpAndSettle();
  await tester.tap(find.text('Tải thêm thư'));await tester.pumpAndSettle();
  expect(find.text('Thư trang tiếp'),findsOneWidget);
  await tester.tap(find.text('Thư chậm'));await tester.pump();
  await tester.tap(find.text('Thư nhanh'));await tester.pumpAndSettle();
  expect(find.text('Nội dung đúng'),findsOneWidget);
  session.slow.complete({'item':{'id':emailId,'text':'Nội dung cũ'}});
  await tester.pumpAndSettle();
  expect(find.text('Nội dung cũ'),findsNothing);
  expect(find.text('Nội dung đúng'),findsOneWidget);
  expect(session.reads.length,1);
 });

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

 testWidgets('mail composer has no signature editor and sends only authored content',(tester) async{
  tester.view.physicalSize=const Size(390,844);
  tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final session=FakeMailSession();
  await tester.pumpWidget(MaterialApp(home:StaffMailPage(session:session)));
  await tester.pumpAndSettle();
  expect(find.byTooltip('Thiết lập chữ ký'),findsNothing);
  await tester.tap(find.byTooltip('Soạn email'));
  await tester.pumpAndSettle();
  expect(find.text('Chữ ký tự động'),findsNothing);
  expect(find.text('Đính kèm tệp (4 tệp, tổng 5 MB)'),findsOneWidget);
  final fields=find.byType(TextField);
  await tester.enterText(fields.at(0),'client@example.test');
  await tester.enterText(fields.at(1),'Chào hỏi');
  await tester.enterText(fields.at(2),'Xin chào anh!');
  await tester.tap(find.text('Gửi email'));
  await tester.pumpAndSettle();
  expect(session.sendPaths.single,'/api/v1/mail/send');
  expect(session.sentPayload?['text'],'Xin chào anh!');
  expect(session.sentPayload?.containsKey('signature'),false);
 });

}
