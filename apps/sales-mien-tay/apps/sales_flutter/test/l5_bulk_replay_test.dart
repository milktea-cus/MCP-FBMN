import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_shim.dart';
import 'bulk_replay_fixture.dart';
void main(){
 test('L5 20 customer mutations 60 photos 5 durable drafts; restart and retry',
   ()=>exerciseBulkReplay(newIdbFactoryMemory()));
}
