import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'app_update_page.dart';
import 'api.dart';
import 'customers.dart';
import 'editor.dart';
import 'models.dart';
import 'theme.dart';
import 'session.dart';
import 'auth_gate.dart';
import 'staff_page.dart';
import 'offline_queue.dart';
import 'notifications.dart';
import 'work_hub.dart';
import 'package:http/http.dart' as http;
import 'performance.dart';
import 'orders.dart';
import 'surveys.dart';
import 'catalog.dart';
import 'stock.dart';
import 'targets.dart';
import 'dart:async';

void main() => runApp(const SalesApp());

class SalesApp extends StatefulWidget {
  const SalesApp({super.key});
  @override
  State<SalesApp> createState() => _SalesAppState();
}

class _SalesAppState extends State<SalesApp> {
  @override
  void initState() {
    super.initState();
    SalesThemePreference.mode.addListener(_themeChanged);
    unawaited(SalesThemePreference.restore());
  }

  void _themeChanged() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    SalesThemePreference.mode.removeListener(_themeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Field Work',
      theme: SalesTheme.build(width: constraints.maxWidth),
      darkTheme: SalesTheme.build(width: constraints.maxWidth, brightness: Brightness.dark),
      themeMode: SalesThemePreference.mode.value,
      home: const AuthGate(),
    ),
  );
}

class SalesHome extends StatefulWidget {
  final SalesSession session;
  final Map<String,dynamic> me;
  final RegionCatalog catalog;
  final Future<void> Function() onLogout;
  const SalesHome({super.key,required this.session,required this.me,required this.catalog,required this.onLogout});
  @override
  State<SalesHome> createState() => _SalesHomeState();
}

class _SalesHomeState extends State<SalesHome> with WidgetsBindingObserver {
  final List<SalesRecord> _items = [];
  late final OfflineQueue _queue;
  late final FieldNotificationStore _notifications;
  Timer? _notificationsTimer;
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed){
      unawaited(_queue.sync());unawaited(_notifications.refresh());
    }
  }
  int _lastPending=0;
  // The queue indicator listens to its own notifier. A sync tick must never
  // rebuild the current business screen during a tap or page transition.
  void _queueChanged(){
    if(!mounted)return;
    final count=_queue.pending.length;
    if(_lastPending>count)unawaited(_refresh());
    _lastPending=count;
  }
  @override void dispose(){
    WidgetsBinding.instance.removeObserver(this);_notificationsTimer?.cancel();
    _notifications.dispose();
    _queue.removeListener(_queueChanged);_queue.dispose();super.dispose();
  }
  RegionCatalog get _catalog => widget.catalog;
  String get _apiUrl => salesOrigin;
  String get _accessToken => widget.session.cookie;
  String _province = '';
  bool _loading = false, _fetchingRecords = false;
  int _selectedIndex = 0;
  String? _message;
  List<Map<String,dynamic>> _brandRows=[],_brandCustomerRows=[],_brandEntries=[];
  List<String> _brandCatalog=[];
  bool _brandLoaded=false;
  List<int> get _visibleMenuIndices=>[for(var i=0;i<_sections.length;i++)if(widget.me['role']=='admin'||i!=2)i];

  List<String> get _sections => ['Tổng quan', 'Khách hàng / Điểm bán', ...moduleKinds.map((e) => e=='survey'?'Quản trị khảo sát':e=='visit'?'Công tác':moduleLabels[e]!), 'Báo cáo tháng', 'Danh mục SKU', 'Tra tồn', 'Ra đơn'];
  List<IconData> get _icons => const [
    Icons.dashboard_outlined, Icons.storefront_outlined, Icons.store_outlined, Icons.flag_outlined,
    Icons.payments_outlined, Icons.route_outlined, Icons.handshake_outlined,
    Icons.policy_outlined, Icons.support_agent_outlined, Icons.analytics_outlined, Icons.inventory_2_outlined, Icons.inventory_outlined,Icons.shopping_cart_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _queue=OfflineQueue(widget.session,widget.me['identity'].toString(),widget.me['scope_revision'].toString());
    WidgetsBinding.instance.addObserver(this);
    _queue.addListener(_queueChanged);unawaited(_queue.start());
    _notifications=FieldNotificationStore(widget.session,_queue);
    unawaited(_notifications.start());
    _notificationsTimer=Timer.periodic(const Duration(seconds:60),
      (_)=>unawaited(_notifications.refresh()));
    _refresh();
    unawaited(_refreshBrands());
  }

  Future<void> _refreshBrands()async{
    const catalogKey='market-brands-v1',coverageKey='market-brand-coverage-v1',
      customersKey='market-brand-customer-counts-v1';
    try{
      final cached=await Future.wait([
       _queue.cached(catalogKey),_queue.cached(coverageKey),_queue.cached(customersKey)]);
      if(mounted)setState((){
       _brandEntries=cached[0];
        _brandCatalog=cached[0].map((e)=>e['name'].toString()).toList();
       _brandRows=cached[1];_brandCustomerRows=cached[2];
       _brandLoaded=cached[0].isNotEmpty||cached[1].isNotEmpty;
      });
      final service=_customerService;
      final results=await Future.wait([
       http.get(service.uri('/api/v1/market/brands'),
        headers:service.headers).timeout(const Duration(seconds:18)),
       http.get(service.uri('/api/v1/market/coverage'),
        headers:service.headers).timeout(const Duration(seconds:18)),
      ]);
      final brands=decodeApi(results[0]),coverage=decodeApi(results[1]);
      final names=(brands['items'] as List)
       .map((e)=>Map<String,dynamic>.from(e as Map)).toList();
      final rows=(coverage['items'] as List)
       .map((e)=>Map<String,dynamic>.from(e as Map)).toList();
      final counts=(coverage['customers'] as List)
       .map((e)=>Map<String,dynamic>.from(e as Map)).toList();
      await _queue.cache(catalogKey,names);
      await _queue.cache(coverageKey,rows);
      await _queue.cache(customersKey,counts);
      if(mounted)setState((){
       _brandEntries=names;
        _brandCatalog=names.map((e)=>e['name'].toString()).toList();
       _brandRows=rows;_brandCustomerRows=counts;_brandLoaded=true;
      });
    }catch(e){
      if(e is ApiFailure&&(e.status==401||e.status==403)){
       if(mounted)setState((){_brandRows=[];_brandCatalog=[];_brandEntries=[];
        _brandCustomerRows=[];_brandLoaded=false;});
      }
    }
  }

  void _notify(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refresh() async {
    if(_fetchingRecords)return;
    _fetchingRecords=true;
    unawaited(_refreshBrands());
    if(mounted)setState(()=>_loading=true);
    try {
      // First paint: restore the account/revision-scoped snapshots; never
      // hold the dashboard waiting for seven independent network requests.
      final snapshots=await Future.wait(moduleKinds.map((kind) async {
        try{
          return (await _queue.cached('records:$kind'))
              .map(SalesRecord.fromJson).toList();
        }catch(_){
          return <SalesRecord>[];
        }
      }));
      if(!mounted)return;
      if(_items.isEmpty){
        setState((){
          _items..clear()..addAll(snapshots.expand((items)=>items));
        });
      }
      // Background requests remain bounded. The app bar/drawer are usable.
      setState(()=>_loading=false);
      final api=SalesApi(_apiUrl,_accessToken,
          identity:_queue.identity,revision:_queue.revision);
      var cachedRead=false;
      final lists=await Future.wait(moduleKinds.map((kind) async {
        try{
          final items=await api.list(kind);
          try{
            await _queue.cache('records:$kind',
                items.map((r)=>r.toJson()).toList());
          }catch(_){}
          return items;
        }catch(e){
          if(e is ApiFailure&&(e.status==401||e.status==403))rethrow;
          cachedRead=true;
          try{
            return (await _queue.cached('records:$kind'))
                .map(SalesRecord.fromJson).toList();
          }catch(_){
            return <SalesRecord>[];
          }
        }
      }));
      if(!mounted)return;
      setState((){
        _items..clear()..addAll(lists.expand((items)=>items));
        _message=cachedRead
            ? 'Đang dùng dữ liệu lưu máy · chưa cập nhật đầy đủ.'
            : null;
      });
    }catch(e){
      if(!mounted)return;
      final denied=e is ApiFailure&&(e.status==401||e.status==403);
      setState((){
        if(denied)_items.clear();
        _message=denied
          ? 'Phiên hoặc quyền truy cập đã thay đổi.'
          : 'Không đồng bộ được. Dữ liệu đã lưu trên máy vẫn còn.';
      });
    }finally{
      _fetchingRecords=false;
      if(mounted)setState(()=>_loading=false);
    }
  }

  Future<void> _profile() async {
    await showDialog<void>(context:context,builder:(c)=>AlertDialog(title:const Text('Hồ sơ nhân viên'),content:Text(widget.me['full_name'].toString()+'\n'+widget.me['email'].toString()+'\nVai trò: '+widget.me['role'].toString()+'\nĐịa bàn: '+_catalog.provinces.join(', ')),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Đóng')),FilledButton(onPressed:()async{
      Navigator.pop(c);
      if(_notifications.pushEnabled)await _notifications.disablePush();
      await widget.onLogout();
    },child:const Text('Đăng xuất'))]));
  }

  Future<void> _addRecord(String kind) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecordEditor(
      kind: kind, catalog: _catalog, onSave: (record) async {
        await _queue.enqueue('/api/v1/records',record);
        _notify('Đã lưu trên máy · chờ đồng bộ');
      },
    )));
  }

  Future<void> _editPlan(SalesRecord record)async{
    await Navigator.push(context,MaterialPageRoute(builder:(_)=>RecordEditor(kind:record.kind,catalog:_catalog,initial:record,onSave:(data)async{
      await _queue.enqueue('/api/v1/records/${record.id}',{'data':data['data'],'version':record.version},method:'PATCH');_notify('Đã lưu thay đổi trên máy · chờ đồng bộ');
    })));
  }
  String _money(num value) {
    final digits = value.round().toString();
    return '${digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')} đ';
  }
  List<SalesRecord> _ofKind(String kind) => _items.where((e) => e.kind == kind && (_province.isEmpty || e.province == _province)).toList();

  Widget _coverageTable(List<SalesRecord> surveys) => SalesBrandCoverageTable(
    surveys: surveys,brandNames:_brandCatalog,brandEntries:_brandEntries,
     service:_customerService,verifiedRows:_brandRows,
    customerCounts:_brandCustomerRows,verifiedData:_brandLoaded,
    provinces: _catalog.provinces.where((p) => _province.isEmpty || p == _province).toList(),
  );

  Widget _overview() {
    final surveys = _ofKind('survey');
    final forecasts = _ofKind('forecast');
    final planned = forecasts.fold<double>(0, (sum, e) => sum + e.forecastTotal);
    final presentCustomers=_brandLoaded?
      _brandRows.fold<int>(0,(sum,r)=>sum+((r['customers'] as num?)?.toInt()??0)):0;
    return ListView(padding: const EdgeInsets.all(18), children: [
      Text('Tổng quan', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 7),
      const SizedBox(height: 16),
      SalesOverviewKpis(
        surveyed: surveys.length,
        planned: _money(planned),
        brandPresence: presentCustomers,
        onTarget: () => setState(() => _selectedIndex = 3),
      ),
      const SizedBox(height: 18),
      Text('Phân hệ nghiệp vụ', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      SalesModuleGrid(
        sections: _sections,
        icons: _icons,
        hiddenIndices:widget.me['role']=='admin'?const {}:const {2},
        onSelect: (index) => setState(() => _selectedIndex = index),
      ),
      const SizedBox(height: 20),
      _coverageTable(surveys),
      const SizedBox(height: 10),
      const SizedBox(height: 14),
    ]);
  }

  Widget _records(String kind,{bool readOnly=false}) {
    final items = _ofKind(kind);
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(18, 16, 18, 6), child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(moduleLabels[kind]!, style: Theme.of(context).textTheme.headlineSmall),
          Text('${items.length} bản ghi', style: Theme.of(context).textTheme.bodySmall),
        ])),
        if(!readOnly)FilledButton.icon(onPressed: () => _addRecord(kind),
          icon: const Icon(Icons.add), label: const Text('Thêm mới')),
      ])),
      Expanded(child: items.isEmpty
        ? Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.inbox_outlined, size: 52, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Chưa có dữ liệu'),
            const SizedBox(height: 10),
            if(!readOnly)FilledButton.tonal(onPressed: () => _addRecord(kind),
              child: const Text('Nhập biểu mẫu đầu tiên')),
          ])))
        : ListView.builder(padding: const EdgeInsets.all(12), itemCount: items.length,
          itemBuilder: (context, index) {
            final record = items[index];
            String detail = record.subtitle;
            if (kind == 'forecast') detail = '${_money(record.forecastTotal)} · $detail';
            if (kind == 'survey') {
              detail = 'NPP: ${record.data['distributorCount'] ?? 0} · '
                  'Nhãn: ${record.data['brandCount'] ?? 0} · $detail';
            }
            return Card(child: ListTile(
              title: Text(record.title),
              subtitle: Text(detail.isEmpty ? (record.data['notes']?.toString() ?? 'Chưa có ghi chú') : detail),
              leading: Icon(_icons[_selectedIndex], color: SalesTheme.brand),
              trailing: ['target','forecast'].contains(kind)&&record.owner==_queue.identity?IconButton(tooltip:'Sửa kế hoạch',icon:const Icon(Icons.edit_outlined),onPressed:()=>_editPlan(record)):const Icon(Icons.cloud_done_outlined),
            ));
          })),
    ]);
  }

  CustomerService get _customerService=>CustomerService(_apiUrl,_accessToken,province:_province,identity:_queue.identity,revision:_queue.revision);

  // Open diagnostics independently of the network/sync state.
  Widget _syncBanner()=>SyncQueueBanner(
    queue:_queue,onDetails:()=>showSyncQueueDetails(context,_queue),
  );

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 850;
    return Scaffold(
      appBar: SalesLiveHomeBar(
        loading:_loading,
        store:_notifications,
        onNotifications:()=>Navigator.push(context,MaterialPageRoute(
          builder:(_)=>FieldNotificationInbox(store:_notifications))),
      ),
      bottomNavigationBar: narrow ? NavigationBar(
        selectedIndex: const [0,1,5,9].contains(_selectedIndex)?const [0,1,5,9].indexOf(_selectedIndex):0,
        onDestinationSelected:(i)=>setState(()=>_selectedIndex=const [0,1,5,9][i]),
        destinations:const [NavigationDestination(icon:Icon(Icons.dashboard_outlined),label:'Tổng quan'),NavigationDestination(icon:Icon(Icons.storefront_outlined),label:'Khách hàng'),NavigationDestination(icon:Icon(Icons.route_outlined),label:'Công tác'),NavigationDestination(icon:Icon(Icons.analytics_outlined),label:'Báo cáo')],
      ):null,
      drawer: SalesHomeDrawer(
        admin:widget.me['role']=='admin', loading:_loading, selectedIndex:_selectedIndex,
        sections:_sections, icons:_icons,
        onSection:(i)=>setState(()=>_selectedIndex=i),
        onRefresh:(){unawaited(_queue.sync());_refresh();},
        onStaff:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>StaffPage(session:widget.session))),
        onProfile:_profile,
        onUpdate:!kIsWeb&&defaultTargetPlatform==TargetPlatform.android
          ?()=>Navigator.push(context,MaterialPageRoute(
            builder:(_)=>AppUpdatePage(session:widget.session)))
          :null,
        themeMode: SalesThemePreference.mode.value,
        onThemeModeChanged: (value) => unawaited(SalesThemePreference.select(value)),
      ),
      body: Row(children: [
        if (!narrow) NavigationRail(
          scrollable: true,
          extended: MediaQuery.of(context).size.width > 1200,
          selectedIndex: _visibleMenuIndices.indexOf(_selectedIndex)<0?0:_visibleMenuIndices.indexOf(_selectedIndex),
          onDestinationSelected: (i) => setState(() => _selectedIndex = _visibleMenuIndices[i]),
          labelType: MediaQuery.of(context).size.width > 1200 ? NavigationRailLabelType.none
            : NavigationRailLabelType.selected,
          destinations: [for (final i in _visibleMenuIndices)
            NavigationRailDestination(icon: Icon(_icons[i]), label: Text(_sections[i]))],
        ),
        Expanded(child: Column(children: [
          if(_selectedIndex!=3&&_selectedIndex!=5&&_selectedIndex!=10&&_selectedIndex!=11&&_selectedIndex!=12)Padding(padding:const EdgeInsets.all(12),child:DropdownButtonFormField<String>(initialValue:_province,isExpanded:true,decoration:const InputDecoration(labelText:'Địa bàn'),items:[const DropdownMenuItem(value:'',child:Text('Tất cả địa bàn của tôi')),for(final p in _catalog.provinces)DropdownMenuItem(value:p,child:Text(p))],onChanged:(p)=>setState(()=>_province=p??''))),
          _syncBanner(),
          if (_message != null) Material(color: const Color(0xFFFBE8E7),
            child: Padding(padding: const EdgeInsets.all(10), child: Text(_message!))),
          Expanded(child: _selectedIndex == 0 ? _overview() : _selectedIndex == 1
              ? CustomerDirectoryPage(key:ValueKey('customers:${_queue.namespace}:$_province'),service:CustomerService(_apiUrl,_accessToken,province:_province,identity:_queue.identity,revision:_queue.revision),regions:_catalog,queue:_queue)
              : _selectedIndex==2?SurveyPage(key:ValueKey('survey:$_province'),queue:_queue,service:_customerService,regions:_catalog,admin:widget.me['role']=='admin',legacy:(_)=>Scaffold(appBar:AppBar(title:const Text('Biểu mẫu khảo sát cũ')),body:_records('survey',readOnly:true)))
              : _selectedIndex==3?TargetPage(key:ValueKey('target:${_queue.namespace}'),queue:_queue)
              : _selectedIndex==12?OrdersPage(key:ValueKey('orders:${_queue.namespace}'),queue:_queue,admin:widget.me['role']=='admin')
              : _selectedIndex==11?StockPage(key:ValueKey('stock:${_queue.namespace}'),queue:_queue,service:CustomerService(_apiUrl,_accessToken,identity:_queue.identity,revision:_queue.revision))
              : _selectedIndex==10?CatalogPage(queue:_queue,service:CustomerService(_apiUrl,_accessToken,identity:_queue.identity,revision:_queue.revision),admin:widget.me['role']=='admin')
              : _selectedIndex==9?PerformancePage(key:ValueKey('report:${_queue.namespace}'),queue:_queue,regions:_catalog,service:_customerService)
              : _selectedIndex==5?WorkHubPage(key:ValueKey('field:${_queue.namespace}'),queue:_queue,service:CustomerService(_apiUrl,_accessToken,identity:_queue.identity,revision:_queue.revision)):_records(moduleKinds[_selectedIndex - 2])),
        ])),
      ]),
    );
  }
}




String _syncTime(Object? value){
    if(value is! num)return 'Chưa rõ';
    final dt=DateTime.fromMillisecondsSinceEpoch(value.toInt()).toLocal();
    return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')} '
      '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }
void showSyncQueueDetails(BuildContext context,OfflineQueue queue)=>showDialog<void>(
   context:context,
   builder:(dialogContext)=>AlertDialog(
    title:const Text('Hàng đợi đồng bộ trên máy'),
    // The iPhone dialog must fit inside the system safe area and keyboard.
    content:SizedBox(
     width:(MediaQuery.sizeOf(dialogContext).width-96).clamp(200,420).toDouble(),
     child:AnimatedBuilder(animation:queue,
     builder:(context,_)=>ConstrainedBox(constraints:const BoxConstraints(maxHeight:460),
      child:ListView(shrinkWrap:true,children:[
       Text('Tác vụ chờ: ${queue.pending.length} · Bị từ chối: ${queue.blockedCount}'
        ' · Cách ly: ${queue.quarantined}'),
       if(queue.error!=null)Padding(padding:const EdgeInsets.only(top:8),
        child:SelectableText(queue.error!)),
       if(queue.nextRetryAt!=null&&!queue.syncing)Padding(
        padding:const EdgeInsets.only(top:6),
        child:Text('Thử tự động lúc ${_syncTime(queue.nextRetryAt!.millisecondsSinceEpoch)}')),
       if(queue.pending.isEmpty)const Padding(padding:EdgeInsets.only(top:8),
        child:Text('Không còn thao tác chờ của tài khoản này.')),
       for(final job in queue.pending)Card(child:Padding(
        padding:const EdgeInsets.all(10),child:Column(
         crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(queue.describe(job),style:Theme.of(context).textTheme.titleSmall),
          Text(job['status']=='blocked'?'Máy chủ từ chối · cần xử lý':'Đã lưu trên máy · chờ gửi',
           style:TextStyle(color:job['status']=='blocked'?
            Theme.of(context).colorScheme.error:null)),
          Text('Tạo lúc ${_syncTime(job['created'])} · Đã thử ${job['attempts']??0} lần'),
          if(job['last_error_at']!=null)
           Text('Lỗi gần nhất: ${job['last_error_at']}',
            style:Theme.of(context).textTheme.bodySmall),
          if(job['error']!=null)SelectableText(job['error'].toString()),
          if((job['depends_on'] as List? ?? []).isNotEmpty)
           const Text('Có thao tác cần hoàn tất trước mục này.'),
          if(job['status']=='blocked')
           Align(alignment:Alignment.centerRight,child:TextButton.icon(
            onPressed:queue.syncing?null:()=>unawaited(
             queue.retryBlocked(job['key'].toString())),
            icon:const Icon(Icons.refresh),label:const Text('Thử gửi lại'))),
         ]))),
       const SizedBox(height:8),
       const Text('Thao tác chưa được gửi không bị tự xóa. '
        'Nếu gặp lỗi 403/409, xem nguyên nhân trước khi gửi lại.',
        style:TextStyle(fontSize:12)),
      ])))),
    actions:[
     TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Đóng')),
     FilledButton.icon(onPressed:queue.syncing?null:()=>unawaited(queue.retryNow()),
      icon:const Icon(Icons.sync),label:const Text('Thử ngay')),
    ],
   ),
  );

/// Sync detail is always accessible, even when an iOS PWA network request
/// is suspended. The trailing button never starts another write operation.
class SyncQueueBanner extends StatelessWidget{
 final OfflineQueue queue;
 final VoidCallback onDetails;
 const SyncQueueBanner({super.key,required this.queue,required this.onDetails});
 @override Widget build(BuildContext context)=>AnimatedBuilder(
  animation:queue,
  builder:(context,_){
   if(queue.pending.isEmpty&&queue.quarantined==0&&queue.error==null){
    return const SizedBox.shrink();
   }
   final blocked=queue.blockedCount;
   final subtitle=queue.isStalled
    ?queue.error??'Đồng bộ đã treo · mở chi tiết để xử lý'
    :queue.syncing
     ?'Đang gửi: ${queue.activePath??'kiểm tra phiên đăng nhập'}'
     :queue.error??(blocked>0
      ?'$blocked thao tác bị từ chối'
      :queue.nextRetryAt!=null
       ?'Đang tạm nghỉ sau lỗi mạng'
       :'Đã lưu trên máy, chưa gửi');
   final colors=Theme.of(context).colorScheme;
   return Material(color:colors.primaryContainer,
    child:InkWell(
     key:const ValueKey('sync-banner-tap'),
     onTap:onDetails,
     child:Padding(
      padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       Row(children:[
        Icon(blocked>0?Icons.error_outline:Icons.cloud_upload_outlined,
         color:colors.onPrimaryContainer,size:24),
        const SizedBox(width:10),
        Expanded(child:Text(
         'Chờ đồng bộ: ${queue.pending.length} · Cách ly: ${queue.quarantined}',
         maxLines:2,style:TextStyle(color:colors.onPrimaryContainer,
          fontWeight:FontWeight.w600))),
        const SizedBox(width:6),
        OutlinedButton.icon(
         key:const ValueKey('sync-details-button'),
         onPressed:onDetails,
         icon:const Icon(Icons.info_outline,size:18),
         label:const Text('Chi tiết'),
         style:OutlinedButton.styleFrom(
          foregroundColor:colors.onPrimaryContainer,
          padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),
          visualDensity:VisualDensity.compact,
         ),
        ),
       ]),
       const SizedBox(height:4),
       Text(subtitle,maxLines:3,overflow:TextOverflow.ellipsis,
        style:TextStyle(color:colors.onPrimaryContainer)),
      ]),
     ),
    ),
   );
  },
 );
}

/// Compact KPI tiles; fixed row extents prevent giant single-column cards on phones.
class SalesOverviewKpis extends StatelessWidget {
  final int surveyed,brandPresence;
  final String planned;
  final VoidCallback onTarget;
  const SalesOverviewKpis({super.key, required this.surveyed, required this.planned,
    required this.brandPresence, required this.onTarget});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
    final columns = size.maxWidth >= 900 ? 4 : size.maxWidth >= 285 ? 2 : 1;
    final items = <Widget>[
      const _KpiTile(label: 'Điểm bán đã khảo sát', value: '', icon: Icons.store_outlined),
      _KpiTile(label: 'Quản lý Target', value: 'Xem chỉ tiêu', icon: Icons.flag_outlined,
        onTap: onTarget),
      _KpiTile(label: 'Doanh thu dự kiến', value: planned, icon: Icons.payments_outlined),
      _KpiTile(label: 'Cặp khách–nhãn thị trường', value: '$brandPresence', icon: Icons.analytics_outlined),
    ];
    items[0] = _KpiTile(label: 'Điểm bán đã khảo sát', value: '$surveyed', icon: Icons.store_outlined);
    return GridView.count(
      crossAxisCount: columns,
      mainAxisSpacing: 8, crossAxisSpacing: 8,
      mainAxisExtent: 124,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items,
    );
  });
}

class _KpiTile extends StatelessWidget {
  final String label,value;
  final IconData icon;
  final VoidCallback? onTap;
  const _KpiTile({required this.label,required this.value,required this.icon,this.onTap});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(11),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: colors.primary, size: 19),
            const SizedBox(height: 5),
            SizedBox(height: 29, width: double.infinity,
              child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                child: Text(value, maxLines: 1, softWrap: false,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)))),
            const SizedBox(height: 4),
            Flexible(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall)),
          ])),
      ),
    );
  }
}


/// Market intelligence: observations at each real customer, never product SKU.
class SalesBrandCoverageTable extends StatefulWidget{
 final List<SalesRecord> surveys;
 final List<String> provinces,brandNames;
 final List<Map<String,dynamic>> verifiedRows,customerCounts,brandEntries;
 final bool verifiedData;
 final CustomerService? service;
 const SalesBrandCoverageTable({super.key,required this.surveys,
  required this.provinces,this.brandNames=const [],this.verifiedRows=const [],
  this.customerCounts=const [],this.brandEntries=const [],
  this.verifiedData=false,this.service});
 @override State<SalesBrandCoverageTable> createState()=>_SalesBrandCoverageTableState();
}
class _SalesBrandCoverageTableState extends State<SalesBrandCoverageTable>{
 final search=TextEditingController();
 String brand='',area='',lookupError='';
 bool searching=false,hasSearched=false,truncated=false;
 List<Map<String,dynamic>> matches=[];
 int generation=0;
 @override void dispose(){search.dispose();super.dispose();}
 String get selectedProvince=>area.isEmpty?'':area.split('||').first;
 String get selectedDistrict=>area.isEmpty?'':area.split('||').last;
 List<String> get names{
  final values={...widget.brandNames,...widget.verifiedRows
    .map((r)=>r['brand']?.toString()??'').where((s)=>s.isNotEmpty)}.toList()..sort();
  return values;
 }
 List<String> get areas{
  final list=<String>{};
  for(final row in widget.customerCounts){
   final province=row['province']?.toString()??'';
   final district=row['district']?.toString()??'';
   if(province.isNotEmpty&&district.isNotEmpty&&widget.provinces.contains(province))
    list.add('$province||$district');
  }
  return list.toList()..sort();
 }
 Future<void> findCustomers({String? byBrand,String? province,String? district})async{
  if(widget.service==null)return;
  final request=++generation;
  final targetBrand=byBrand??brand;
  final brandEntry=widget.brandEntries.where((b)=>b['name']==targetBrand).firstOrNull;
  final selectedId=brandEntry?['id']?.toString()??
   widget.verifiedRows.where((row)=>row['brand']==targetBrand).firstOrNull?['brand_id']?.toString()??'';
  final options=<String,String>{
   if(targetBrand.isNotEmpty&&selectedId.isNotEmpty)'brand_id':selectedId,
   if(province!=null&&province.isNotEmpty)'province':province
   else if(selectedProvince.isNotEmpty)'province':selectedProvince
   else if(widget.provinces.length==1)'province':widget.provinces.single,
   if(district!=null&&district.isNotEmpty)'district':district
   else if(selectedDistrict.isNotEmpty)'district':selectedDistrict,
   if(search.text.trim().isNotEmpty)'q':search.text.trim(),
   'limit':'150',
  };
  setState((){searching=true;lookupError='';hasSearched=true;matches=[];truncated=false;});
  try{
   final payload=decodeApi(await http.get(widget.service!.uri(
     '/api/v1/market/customers',options),
     headers:widget.service!.headers).timeout(const Duration(seconds:18)));
   if(mounted&&generation==request)setState((){
    matches=(payload['items'] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
    truncated=payload['truncated']==true;
   });
  }catch(e){
   if(mounted&&generation==request)setState(()=>lookupError='Không tải được khách theo nhãn: $e');
  }finally{
   if(mounted&&generation==request)setState(()=>searching=false);
  }
 }
 @override Widget build(BuildContext context){
  final allNames=names;
  final visibleNames=brand.isEmpty?allNames:[brand];
  final availableAreas=areas;
  // Keep old filters safe if the permitted area list changes on scope revoke.
  final activeArea=availableAreas.contains(area)?area:'';
  final provinces=widget.provinces.where((p)=>activeArea.isEmpty||
   activeArea.startsWith('$p||')).toList();
  final rows=provinces.map((province){
   final records=widget.verifiedRows.where((r)=>r['province']==province&&
    (activeArea.isEmpty||r['district']==activeArea.split('||').last)).toList();
   final total=widget.customerCounts.where((r)=>r['province']==province&&
    (activeArea.isEmpty||r['district']==activeArea.split('||').last))
    .fold<int>(0,(s,r)=>s+((r['customers'] as num?)?.toInt()??0));
   final rowProvince=activeArea.isEmpty?province:
    '${activeArea.split('||').last} · $province';
   return DataRow(cells:[
    DataCell(Text(rowProvince)),DataCell(Text('$total')),
    for(final name in visibleNames)DataCell(
     Text('${records.where((r)=>r['brand']==name)
      .fold<int>(0,(s,r)=>s+((r['customers'] as num?)?.toInt()??0))}'),
     onTap:widget.service==null?null:()=>findCustomers(
      byBrand:name,province:province,
      district:activeArea.isEmpty?null:activeArea.split('||').last)),
   ]);
  }).toList();
  return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(
   crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text('Nhãn hàng thị trường theo khách và khu vực',
     style:Theme.of(context).textTheme.titleMedium),
    const SizedBox(height:5),
    const Text('Một khách có MGP hoặc Thành Đạt được tính 1 lần cho mỗi nhãn '
      'trong khu vực. Khảo sát lại chỉ cập nhật ghi nhận, không cộng dồn lượt. '
      'Dữ liệu từ phiên công tác, không từ SKU Futurebook.',
      style:TextStyle(fontSize:12)),
    const SizedBox(height:10),
    Wrap(spacing:8,runSpacing:8,children:[
     SizedBox(width:230,child:DropdownButtonFormField<String>(
      key:ValueKey('market-brand:$brand'),initialValue:allNames.contains(brand)?brand:'',
      isExpanded:true,decoration:const InputDecoration(labelText:'Nhãn hàng',isDense:true),
      items:[const DropdownMenuItem(value:'',child:Text('Tất cả nhãn hàng')),
       for(final name in allNames)DropdownMenuItem(value:name,
        child:Text(name,overflow:TextOverflow.ellipsis))],
      onChanged:(v)=>setState(()=>brand=v??''))),
     SizedBox(width:230,child:DropdownButtonFormField<String>(
      key:ValueKey('market-area:$activeArea'),initialValue:activeArea,
      isExpanded:true,decoration:const InputDecoration(labelText:'Địa bàn',isDense:true),
      items:[const DropdownMenuItem(value:'',child:Text('Tất cả huyện')),
       for(final key in availableAreas)DropdownMenuItem(value:key,
        child:Text('${key.split('||').last} · ${key.split('||').first}',
         overflow:TextOverflow.ellipsis))],
      onChanged:(v)=>setState(()=>area=v??''))),
    ]),
    const SizedBox(height:7),
    Row(children:[
     Expanded(child:TextField(controller:search,
      decoration:const InputDecoration(prefixIcon:Icon(Icons.search),
       isDense:true,labelText:'Tên khách / mã khách / nhãn hàng'),
      onSubmitted:(_)=>findCustomers())),
     const SizedBox(width:6),
     FilledButton.icon(onPressed:searching||widget.service==null?null:()=>findCustomers(),
      icon:const Icon(Icons.search),label:const Text('Tìm')),
    ]),
    if(!widget.verifiedData)const Padding(padding:EdgeInsets.all(8),
     child:Text('Chưa cập nhật được thống kê thị trường; đang dùng dữ liệu lưu trên máy.')),
    if(allNames.isEmpty)const Padding(padding:EdgeInsets.all(8),
     child:Text('Chưa có nhãn hàng thị trường. Ghi MGP, Thành Đạt hoặc nhãn khác '
      'tại phiên khảo sát khách; sau khi đồng bộ sẽ hiện ở đây.')),
    SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(
     columnSpacing:20,columns:[
      const DataColumn(label:Text('Tỉnh / Huyện')),
      const DataColumn(label:Text('Khách')),
      for(final name in visibleNames)DataColumn(label:Text(name)),
     ],rows:rows)),
    if(searching)const LinearProgressIndicator(minHeight:2),
    if(lookupError.isNotEmpty)Text(lookupError),
    if(hasSearched&&!searching)...[
     Padding(padding:const EdgeInsets.symmetric(vertical:8),
      child:Text('Khách phù hợp: ${matches.length}${truncated?' (còn kết quả khác)':''}',
       style:Theme.of(context).textTheme.titleSmall)),
     if(matches.isEmpty)const Text('Không có khách phù hợp nhãn và khu vực đã chọn.'),
     for(final row in matches.take(150))ListTile(
      dense:true,
      leading:const Icon(Icons.storefront_outlined),
      title:Text(row['customer_name']?.toString()??''),
      subtitle:Text('${row['brand']??''} · ${row['district']??''}, ${row['province']??''}'),
      trailing:Text(row['field_code']?.toString()??'',
       style:Theme.of(context).textTheme.bodySmall)),
    ],
   ],
  )));
 }
}

/// Responsive home shortcuts. All routes retain their original indices.
class SalesModuleGrid extends StatelessWidget {
  final List<String> sections;
  final List<IconData> icons;
  final ValueChanged<int> onSelect;
  final Set<int> hiddenIndices;
  const SalesModuleGrid({super.key, required this.sections, required this.icons,
    this.hiddenIndices=const {},required this.onSelect});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
    final columns = size.maxWidth >= 1000 ? 6
      : size.maxWidth >= 650 ? 4 : size.maxWidth >= 315 ? 3 : 2;
    final available=[for(var i=1;i<sections.length;i++)if(!hiddenIndices.contains(i))i];
    return GridView.builder(
      primary: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: available.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns, mainAxisSpacing: 10, crossAxisSpacing: 10,
        mainAxisExtent: 110,
      ),
      itemBuilder: (context, slot) {
        final index = available[slot];
        final label = index == 1 ? 'Khách hàng'
          : index == 9 ? 'Báo cáo' : sections[index];
        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('module-grid-$index'),
            onTap: () => onSelect(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icons[index], color: Theme.of(context).colorScheme.primary, size: 28),
                const SizedBox(height: 9),
                Text(label, textAlign: TextAlign.center, maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        );
      },
    );
  });
}

/// Only the notification icon rebuilds on unread/push changes. The selected
/// module and its forms must not be rebuilt by periodic notification polling.
class SalesLiveHomeBar extends StatelessWidget implements PreferredSizeWidget {
  final FieldNotificationStore store;
  final bool loading;
  final VoidCallback onNotifications;
  const SalesLiveHomeBar({
    super.key,required this.store,required this.loading,
    required this.onNotifications,
  });
  @override
  Size get preferredSize=>Size.fromHeight(kToolbarHeight+(loading?2:0));
  @override
  Widget build(BuildContext context)=>AnimatedBuilder(
    animation:store,
    builder:(context,_)=>SalesHomeBar(
      loading:loading,
      unreadCount:store.unread,
      onNotifications:onNotifications,
    ),
  );
}

class SalesHomeBar extends StatelessWidget implements PreferredSizeWidget {
  final bool loading;
  final int unreadCount;
  final VoidCallback onNotifications;
  const SalesHomeBar({super.key,required this.loading,required this.onNotifications,
    this.unreadCount=0});
  @override Size get preferredSize=>Size.fromHeight(kToolbarHeight+(loading?2:0));
  @override Widget build(BuildContext context)=>AppBar(
    centerTitle:false, titleSpacing:0,
    title:Row(mainAxisSize:MainAxisSize.min,children:[
      Image.asset('assets/fbmn-transparent-logo.webp',height:28,width:88,fit:BoxFit.contain,
        semanticLabel:'Futurebook'),
      const SizedBox(width:6),
      const Flexible(child:Text('Field Work',maxLines:1,overflow:TextOverflow.ellipsis,
        style:TextStyle(fontWeight:FontWeight.w700,fontSize:18))),
    ]),
    bottom:loading?const PreferredSize(preferredSize:Size.fromHeight(2),
      child:LinearProgressIndicator(minHeight:2)):null,
    actions:[IconButton(
      tooltip:'Thông báo',
      icon:unreadCount>0?Badge.count(
        count:unreadCount>99?99:unreadCount,
        backgroundColor:Theme.of(context).colorScheme.error,
        child:const Icon(Icons.notifications_none_outlined),
      ):const Icon(Icons.notifications_none_outlined),
      onPressed:onNotifications)],
  );
}

/// All secondary actions live in the same navigation drawer on every width.
class SalesHomeDrawer extends StatelessWidget {
  final bool admin,loading;
  final int selectedIndex;
  final List<String> sections;
  final List<IconData> icons;
  final ValueChanged<int> onSection;
  final VoidCallback onRefresh,onStaff,onProfile;
  final VoidCallback? onUpdate;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  const SalesHomeDrawer({super.key,required this.admin,required this.loading,
    required this.selectedIndex,required this.sections,required this.icons,
    required this.onSection,required this.onRefresh,required this.onStaff,required this.onProfile,
    this.onUpdate,this.themeMode = ThemeMode.light, this.onThemeModeChanged});
  @override Widget build(BuildContext context){
    void run(VoidCallback action){Navigator.of(context).pop();action();}
    Widget section(int i)=>ListTile(leading:Icon(icons[i]),title:Text(sections[i]),
      selected:selectedIndex==i,onTap:()=>run(()=>onSection(i)));
    return Drawer(child:SafeArea(child:ListView(padding:EdgeInsets.zero,children:[
      const ListTile(title:Text('PHÂN HỆ SALES')),
      if(admin)ListTile(leading:const Icon(Icons.manage_accounts_outlined),
        title:const Text('Quản lý nhân viên'),onTap:()=>run(onStaff)),
      ListTile(leading:const Icon(Icons.account_circle_outlined),
        title:const Text('Hồ sơ / Đăng xuất'),onTap:()=>run(onProfile)),
      if(onUpdate!=null)ListTile(
        key:const Key('android-update-menu'),
        leading:const Icon(Icons.system_update_alt_outlined),
        title:const Text('Cập nhật ứng dụng'),
        onTap:()=>run(onUpdate!)),
      if (onThemeModeChanged != null) SwitchListTile(
        secondary: Icon(themeMode == ThemeMode.dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
        title: const Text('Chế độ tối'),
        value: themeMode == ThemeMode.dark,
        onChanged: (enabled) => onThemeModeChanged!(
          enabled ? ThemeMode.dark : ThemeMode.light)),
      ListTile(leading:const Icon(Icons.sync),title:const Text('Tải lại dữ liệu'),
        enabled:!loading,onTap:loading?null:()=>run(onRefresh)),
      const Divider(),
      for(final i in [10,11,12])section(i),
      const Divider(),
      for(var i=0;i<sections.length;i++)if(i!=10&&i!=11&&i!=12&&(admin||i!=2))section(i),
    ])));
  }
}
