import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'customers.dart';
import 'offline_queue.dart';
import 'planning_periods.dart';
import 'session.dart';
import 'local_scope_picker.dart';

List<DateTime> fixedMonthDays(DateTime month,int week)=>
 week>=1&&week<=5?periodDays(month,week):[];
bool fixedMonthMatches(Map<String,dynamic> rule,DateTime date)=>
 rule['active']==true&&(rule['week_no'] as num?)?.toInt()==planningPeriod(date);
String fixedMonthId(String ruleId,DateTime day,String kind)=>
 const Uuid().v5(Uuid.NAMESPACE_URL,
  'fbmn:month:'+ruleId+':'+dayKey(day)+':'+kind);
enum FixedMonthResult{created,existing}
Future<FixedMonthResult> materializeFixedMonth({
 required OfflineQueue queue,required CustomerService service,
 required Map<String,dynamic> rule,required DateTime date,
})async{
 final now=DateTime.now().toUtc().add(const Duration(hours:7));
 if(dayKey(date).compareTo(dayKey(now))<0||!fixedMonthMatches(rule,date))
  throw StateError('Ngày không thuộc tuần tháng được giao');
 final selections=localTemplateScopes(rule);
 if(selections.isEmpty||selections.length>50)
  throw StateError('Tuyến tháng chưa có phạm vi hợp lệ');
 final first=selections.first,ym=monthKey(date),d=dayKey(date),
  kind=first['scope_kind'].toString(),key=first['scope_key'].toString();
 var plans=await queue.cached('monthly-plans:'+ym);
 try{
  final uri=service.uri('/api/v1/monthly-plans',{'month':ym});
  final res=decodeApi(await (service.client?.get(uri,headers:service.headers)??
   http.get(uri,headers:service.headers)).timeout(const Duration(seconds:15)));
  plans=(res['items'] as List).map((v)=>Map<String,dynamic>.from(v as Map)).toList();
  await queue.cache('monthly-plans:'+ym,plans);
 }on ApiFailure catch(e){if(e.status==401||e.status==403)rethrow;}
 catch(_){/* Grant and uniqueness are enforced by server on replay. */}
 if(plans.any((p)=>p['owner_sub']==queue.identity&&p['status']=='planned'&&
    p['work_date'].toString().startsWith(d)&&p['scope_kind']==kind&&p['scope_key']==key)||
   queue.pending.any((p)=>p['path']=='/api/v1/monthly-plans'&&
    (p['payload'] as Map?)?['work_date']==d&&
    (p['payload'] as Map?)?['scope_kind']==kind&&
    (p['payload'] as Map?)?['scope_key']==key))return FixedMonthResult.existing;
 final id=rule['id'].toString(),name=rule['name'].toString();
 final p=fixedMonthId(id,date,'plan'),r=fixedMonthId(id,date,'route'),
  t=fixedMonthId(id,date,'trip');
 final province=first['province'],district=first['district'];
 final tripScopes=selections.map((scope)=><String,dynamic>{
  'scope_kind':scope['scope_kind'],'scope_key':scope['scope_key'],
  'province':scope['province'],'district':scope['district'],
 }).toList();
 final note='Từ tuyến cố định tháng '+id;
 await queue.enqueueTripGraph(
  plan:{'client_ref':p,'period_ym':ym,'work_date':d,
   'scope_kind':kind,'scope_key':key,'province':province,'district':district,
   'purpose':name,'target_new_customers':0,'status':'planned','note':note},
  route:{'client_ref':r,'monthly_plan_id':p,'route_date':d,
   'purpose':name,'status':'ready','note':note},
  trip:{'client_ref':t,'mutation_ref':t,'day_route_id':r,
   'start_date':d,'end_date':d,'purpose':name,'note':note,
   'scopes':tripScopes,
   'priorities':<String>[]},
 );
 return FixedMonthResult.created;
}
