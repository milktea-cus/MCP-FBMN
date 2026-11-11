import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'models.dart';
import 'session.dart';
import 'offline_queue.dart';
import 'editor.dart';
import 'surveys.dart';
import 'customer_categories.dart';
import 'customer_assortment.dart';
import 'survey_media.dart';
import 'package:url_launcher/url_launcher.dart';

class FieldCustomer {
  final String id, name, address, province, district, category, status;
  final String? phone, contact, note, owner, code, fieldCode;
  final double? latitude, longitude;
  final int version;
  Map<String,dynamic> toJson()=>{'id':id,'owner_sub':owner,'name':name,'code':code,'field_code':fieldCode,'address_line':address,'province':province,'district':district,'category':category,'status':status,'phone':phone,'contact_name':contact,'note':note,'latitude':latitude,'longitude':longitude,'version':version};
  FieldCustomer.fromJson(Map<String, dynamic> j)
      : id = j['id'].toString(), name = j['name'].toString(),
        owner = j['owner_sub'] as String?, code = j['code'] as String?,fieldCode=j['field_code'] as String?, address = j['address_line'].toString(), province = j['province'].toString(),
        district = j['district'].toString(), category = j['category'].toString(),
        status = j['status'].toString(), phone = j['phone'] as String?,
        contact = j['contact_name'] as String?, note = j['note'] as String?,
        latitude = (j['latitude'] as num?)?.toDouble(),
        longitude = (j['longitude'] as num?)?.toDouble(),
        version = (j['version'] as num?)?.toInt() ?? 1;
}

class CustomerService {
  final String endpoint, token;
  final String province;
  final String? identity,revision;
  final http.Client? client;
  // Short bounded wait for the list, while retaining scoped local snapshots.
  final Duration listTimeout;
  const CustomerService(this.endpoint, this.token,{
    this.province='',this.identity,this.revision,
    this.client,this.listTimeout=const Duration(seconds:7),
  });
  Uri uri(String path, [Map<String, String>? query]) {
    final url = Uri.parse('${endpoint.replaceFirst(RegExp(r'/$'), '')}$path');
    if (url.scheme != 'https' && url.host != 'localhost' && url.host != '127.0.0.1') {
      throw StateError('API phải sử dụng HTTPS');
    }
    return url.replace(queryParameters: query);
  }
  Map<String, String> get headers => {...sessionHeaders(token),if(identity!=null)'X-Sync-Identity':identity!,if(revision!=null)'X-Sync-Revision':revision!};
  Map<String, dynamic> decode(http.Response res, [int ok = 200]) {
    final data = decodeApi(res);
    if (res.statusCode != ok && !(ok == 201 && res.statusCode == 200)) {
      throw StateError(data['error']?.toString() ?? 'Lỗi ${res.statusCode}');
    }
    return data;
  }
  Future<List<FieldCustomer>> list({
    void Function(List<FieldCustomer> partial)? onPage,
  }) async {
    final items=<FieldCustomer>[];
    for(var offset=0;offset<=10000;offset+=100){
      final request=uri('/api/v1/customers',{'province':province,'limit':'100','offset':'$offset'});
      final response=await (client?.get(request,headers:headers) ??
          http.get(request,headers:headers)).timeout(listTimeout);
      final data=decode(response);
      final page=(data['items'] as List)
          .map((e)=>FieldCustomer.fromJson(Map<String,dynamic>.from(e as Map)))
          .toList();
      items.addAll(page);
      onPage?.call(List<FieldCustomer>.unmodifiable(items));
      if(page.length<100)break;
    }
    return items;
  }
  Future<FieldCustomer> add(Map<String, dynamic> data) async {
    final res = await http.post(uri('/api/v1/customers'), headers: headers, body: jsonEncode(data));
    return FieldCustomer.fromJson(decode(res, 201)['item'] as Map<String, dynamic>);
  }
  Future<FieldCustomer> update(FieldCustomer customer, Map<String,dynamic> data) async {
    final res=await http.patch(uri('/api/v1/customers/${customer.id}'),headers:headers,body:jsonEncode({...data,'version':customer.version})).timeout(const Duration(seconds:30));
    return FieldCustomer.fromJson(decode(res)['item'] as Map<String,dynamic>);
  }
  Future<void> checkin(String customerId, Position pos, String ref) async {
    final data = {'client_ref': ref, 'latitude': pos.latitude, 'longitude': pos.longitude,
      'accuracy_m': pos.accuracy};
    final res = await http.post(uri('/api/v1/customers/$customerId/visits'),
      headers: headers, body: jsonEncode(data));
    decode(res, 201);
  }
  Future<void> uploadPhoto(String customerId, XFile photo) async {
    final media=compressSurveyMedia(await photo.readAsBytes());
    final res=await http.post(uri('/api/v1/customers/$customerId/photos'),
      headers:{...headers,'Content-Type':'application/json','X-Upload-Id':const Uuid().v4()},
      body:jsonEncode({'image':base64Encode(media.image),'thumbnail':base64Encode(media.thumbnail),
        'sha256':media.hash,'thumbnail_sha256':media.thumbnailHash})).timeout(const Duration(seconds:30));
    decode(res,201);
  }
  Future<void> setCover(String customerId,String photoId) async {
    final res=await http.patch(uri('/api/v1/customers/$customerId/cover'),
      headers:{...headers,'Content-Type':'application/json'},
      body:jsonEncode({'photo_id':photoId})).timeout(const Duration(seconds:20));
    decode(res);
  }
  Future<List<Map<String,dynamic>>> media(String customerId) async {
    final res=await http.get(uri('/api/v1/customers/$customerId/media'),headers:headers).timeout(const Duration(seconds:20));
    final data=decode(res);
    return (data['items'] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  }
  Future<List<Map<String,dynamic>>> sessions(String customerId) async {
    final res=await http.get(uri('/api/v1/sessions',{'customer_id':customerId}),headers:headers).timeout(const Duration(seconds:20));
    final data=decode(res);
    return (data['items'] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  }
  Future<Uint8List> mediaBytes(String customerId, Map<String,dynamic> media,{bool thumbnail=true}) async {
    final source=media['source'];
    final path=source=='survey'
      ?'/api/v1/sessions/${media['session_id']}/photos/${media['id']}'
      :'/api/v1/customers/$customerId/photos/${media['id']}';
    final res=await http.get(uri(path,thumbnail?{'thumbnail':'1'}:null),headers:headers).timeout(const Duration(seconds:20));
    if(res.statusCode!=200){checkSessionStatus(res);throw StateError('Không tải được ảnh');}
    return res.bodyBytes;
  }
  Future<List<Map<String,dynamic>>> visits(String customerId) async {
    final data=decode(await http.get(uri('/api/v1/customers/$customerId/visits'),headers:headers).timeout(const Duration(seconds:20)));
    return (data['items'] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  }
  Future<List<String>> photos(String customerId) async {
    final data = decode(await http.get(uri('/api/v1/customers/$customerId/photos'), headers: headers));
    return (data['items'] as List<dynamic>).map((e) => (e as Map<String, dynamic>)['id'].toString()).toList();
  }
  Future<Uint8List> photoBytes(String customerId, String photoId) async {
    final res = await http.get(uri('/api/v1/customers/$customerId/photos/$photoId'), headers: headers);
    if (res.statusCode != 200) {checkSessionStatus(res);throw StateError('Không tải được ảnh');}
    return res.bodyBytes;
  }
}

Future<Position> captureGps(BuildContext context) async {
  final confirmed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
    title: const Text('Sử dụng vị trí'),
    content: const Text('Ứng dụng sẽ lấy GPS một lần để lưu tọa độ điểm bán hoặc xác minh check-in. Không theo dõi vị trí liên tục. Anh có đồng ý?'),
    actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Không')),
      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Đồng ý'))],
  ));
  if (confirmed != true) throw StateError('Chưa được đồng ý dùng vị trí');
  if (!await Geolocator.isLocationServiceEnabled()) throw StateError('Chưa bật GPS');
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
    throw StateError('Chưa cấp quyền vị trí');
  }
  return Geolocator.getCurrentPosition(locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)));
}

class CustomerDirectoryPage extends StatefulWidget {
  final CustomerService service;
  final RegionCatalog regions;
  final OfflineQueue? queue;
  const CustomerDirectoryPage({super.key, required this.service, required this.regions,this.queue});
  @override
  State<CustomerDirectoryPage> createState() => _CustomerDirectoryPageState();
}

class _CustomerDirectoryPageState extends State<CustomerDirectoryPage> {
  List<FieldCustomer> customers = [];
  List<FieldCustomer>? completeSnapshot;
  bool loading = false, openingCache = true;
  String? error;
  String get cacheKey => 'customers:${widget.service.province}';

  @override
  void initState() {
    super.initState();
    // Render account-scoped IndexedDB/SQLite before contacting the server.
    unawaited(_openDirectory());
  }

  Future<void> _openDirectory() async {
    if(widget.queue!=null){
      try{
        final cached=await widget.queue!.cached(cacheKey);
        if(mounted){
          final snapshot=cached.map(FieldCustomer.fromJson).toList();
          completeSnapshot=snapshot;
          setState(()=>customers=snapshot);
        }
      }catch(_){
        // A local storage error must not block the authorized server request.
      }
    }
    if(!mounted)return;
    setState(()=>openingCache=false);
    await refresh();
  }

  Future<void> refresh() async {
    if(loading)return;
    setState(() {loading=true;error=null;});
    try {
      final items=await widget.service.list(onPage:(partial){
        if(mounted)setState(()=>customers=partial);
      });
      if(!mounted)return;
      setState(() {customers=items;completeSnapshot=items;error=null;});
      // Local cache write failure must never mask a successful server result.
      if(widget.queue!=null){
        try{
          await widget.queue!.cache(cacheKey,items.map((r)=>r.toJson()).toList());
        }catch(_){}
      }
    } catch(e) {
      if(!mounted)return;
      final denied=e is ApiFailure&&(e.status==401||e.status==403);
      setState((){
        if(denied){
          customers=[];
          completeSnapshot=null;
          error='Phiên hoặc quyền truy cập đã thay đổi.';
        } else {
          if(completeSnapshot!=null)customers=completeSnapshot!;
          error=customers.isEmpty
              ? 'Không tải được khách hàng. Kiểm tra mạng rồi thử lại.'
              : 'Đang xem dữ liệu lưu máy · chưa làm mới.';
        }
      });
    } finally {
      if(mounted)setState(()=>loading=false);
    }
  }
  Future<void> add() async {
    final created = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) =>
        CustomerEditor(service: widget.service, regions: widget.regions,queue:widget.queue)));
    if (created == true) refresh();
  }
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder:(context,constraints) {
      final narrow=constraints.maxWidth<480;
      return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(12,12,12,8), child: Row(children: [
        Expanded(child:Text(narrow?'Khách hàng':'Khách hàng / Điểm bán',
          maxLines:1,overflow:TextOverflow.ellipsis,
          style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold))),
        IconButton(onPressed:loading?null:refresh,tooltip:'Làm mới khách hàng',icon:const Icon(Icons.refresh)),
        if(narrow) IconButton(onPressed:add,tooltip:'Thêm điểm bán',icon:const Icon(Icons.add_circle_outline))
        else FilledButton.icon(onPressed:add,icon:const Icon(Icons.add),label:const Text('Thêm điểm bán')),
      ])),
      if (error != null) Padding(padding: const EdgeInsets.symmetric(horizontal:12,vertical:6),
        child: Row(children:[
          Expanded(child:Text(error!,style:Theme.of(context).textTheme.bodySmall)),
          if(!loading) TextButton(onPressed:refresh,child:const Text('Thử lại')),
        ])),
      if (loading) const LinearProgressIndicator(minHeight:2),
      Expanded(child: customers.isEmpty
        ? Center(child:Text(loading||openingCache
            ? 'Đang tải khách hàng…'
            : error!=null ? 'Chưa có dữ liệu đã lưu.' : 'Chưa có điểm bán trong phạm vi được cấp'))
      : ListView.builder(itemCount: customers.length, itemBuilder: (ctx,i) {
        final c = customers[i];
        final category = CustomerCategory.fromId(c.category);
        return Card(child: ListTile(
          leading: CustomerCategoryAvatar(category:c.category),
          title: Text(c.name,maxLines:2,overflow:TextOverflow.ellipsis),
          subtitle: Text('${c.fieldCode??'Đang cấp mã'} · ${category.label} · ${c.district}, ${c.province} · ${c.address}',
            maxLines:3,overflow:TextOverflow.ellipsis),
          trailing: c.owner!=widget.service.identity?const Icon(Icons.chevron_right):IconButton(tooltip:'Sửa thông tin',icon:const Icon(Icons.edit_outlined),onPressed:() async {final changed=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>CustomerEditor(service:widget.service,regions:widget.regions,customer:c,queue:widget.queue)));if(changed==true&&mounted)refresh();}),
          onTap: () async {final changed=await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) =>
            CustomerDetail(service: widget.service, customer: c,regions:widget.regions,queue:widget.queue)));if(changed==true&&mounted)refresh();},
        ));
      })),
    ]);
    });
  }
}

class CustomerEditor extends StatefulWidget {
  final CustomerService service;
  final RegionCatalog regions;
  final FieldCustomer? customer;
  final OfflineQueue? queue;
  const CustomerEditor({super.key, required this.service, required this.regions,this.customer,this.queue});
  @override State<CustomerEditor> createState() => _CustomerEditorState();
}
class _CustomerEditorState extends State<CustomerEditor> {
  final key = GlobalKey<FormState>();
  final name = TextEditingController(), address = TextEditingController(), contact = TextEditingController(),
    phone = TextEditingController(), note = TextEditingController(), companyCode = TextEditingController();
  final clientRef = const Uuid().v4();
  String? province, district;
  String category = 'tap_hoa';
  Position? position;
  XFile? photo;
  bool saving = false;
  String? error;
  @override void initState(){super.initState();final c=widget.customer;if(c!=null){name.text=c.name;companyCode.text=c.code??'';address.text=c.address;contact.text=c.contact??'';phone.text=c.phone??'';note.text=c.note??'';province=c.province;district=c.district;category=CustomerCategory.fromId(c.category).id;}}
  @override void dispose() {name.dispose(); address.dispose();contact.dispose();phone.dispose();note.dispose();companyCode.dispose();super.dispose();}
  Future<void> gps() async {
    try {final p = await captureGps(context); if (mounted) setState(() {position = p; error = null;});}
    catch (e) {if (mounted) setState(() => error = e.toString());}
  }
  Future<void> choosePhoto() async {
    try {final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
      if (x != null && mounted) setState(() {photo = x; error = null;});}
    catch(e){if(mounted)setState(()=>error='$e');}
  }
  Future<void> save() async {
    if(saving)return;
    if (!key.currentState!.validate() || province == null || district == null) {
      setState(() => error = 'Vui lòng điền thông tin và chọn tỉnh/huyện'); return;
    }
    setState(() => saving = true);
    try {
      final data=<String,dynamic>{if(widget.customer==null)'client_ref':clientRef,'name':name.text.trim(),'code':companyCode.text.trim().isEmpty?null:companyCode.text.trim(),
        'address_line':address.text.trim(),'contact_name':contact.text.trim().isEmpty?null:contact.text.trim(),
        'phone':phone.text.trim().isEmpty?null:phone.text.trim(),'note':note.text.trim().isEmpty?null:note.text.trim(),
        'province':province,'district':district,'category':category,
        if(widget.customer==null||position!=null)...{'location_consent':position != null,'latitude':position?.latitude,'longitude':position?.longitude,'location_accuracy_m':position?.accuracy}};
      if(widget.queue!=null){
        final compressed=photo==null?null:compressSurveyMedia(await photo!.readAsBytes());
        await widget.queue!.enqueue(widget.customer==null?'/api/v1/customers':'/api/v1/customers/${widget.customer!.id}',{...data,if(widget.customer!=null)'version':widget.customer!.version,'client_ref':clientRef},
          photo:compressed?.image,thumbnail:compressed?.thumbnail,
          sha256:compressed?.hash,thumbnailSha256:compressed?.thumbnailHash,
          mime:compressed==null?null:'image/jpeg',method:widget.customer==null?'POST':'PATCH');
        if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Đã lưu điểm bán trên máy · chờ đồng bộ')));Navigator.pop(context,true);}return;
      }
      final created=widget.customer==null?await widget.service.add(data):await widget.service.update(widget.customer!,data);
      if (photo != null) {try{await widget.service.uploadPhoto(created.id, photo!);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Đã lưu điểm bán, nhưng chưa tải được ảnh: $e')));}}
      if (mounted) Navigator.pop(context, true);
    } catch(e){if(mounted)setState(()=>error='$e');}
    finally {if(mounted)setState(()=>saving=false);}
  }
  @override Widget build(BuildContext context) => Scaffold(appBar:AppBar(title:Text(widget.customer==null?'Thêm điểm bán':'Sửa điểm bán')),
    body: Form(key:key, child:ListView(padding:const EdgeInsets.all(16),children:[
      TextFormField(controller:name,decoration:const InputDecoration(labelText:'Tên điểm bán *'),
        validator:(v)=>(v??'').trim().length<2?'Tên ít nhất 2 ký tự':null),
      const SizedBox(height:12),
      InputDecorator(decoration:const InputDecoration(labelText:'Mã Field Work (tự động)'),
       child:Text(widget.customer?.fieldCode??'Được cấp sau khi đồng bộ · 6 ký tự in hoa')),
      const SizedBox(height:12),
      TextFormField(controller:companyCode,decoration:const InputDecoration(labelText:'Mã khách CTY (nếu có)',helperText:'Dùng đối chiếu với app công ty; không phải mã Field Work'),
       validator:(v)=>(v??'').trim().length>80?'Mã khách tối đa 80 ký tự':null),
      const SizedBox(height:12),
      DropdownButtonFormField<String>(initialValue:province,decoration:const InputDecoration(labelText:'Tỉnh/TP (địa giới cũ) *'),
        items:widget.regions.provinces.map((p)=>DropdownMenuItem(value:p,child:Text(p))).toList(),
        onChanged:(v)=>setState(() {province=v;district=null;})),
      const SizedBox(height:12),
      DropdownButtonFormField<String>(key:ValueKey(province),initialValue:district,
        decoration:const InputDecoration(labelText:'Huyện/Quận *'),
        items:(widget.regions.districts[province]??<String>[]).map((d)=>DropdownMenuItem(value:d,child:Text(d))).toList(),
        onChanged:province==null?null:(v)=>setState(()=>district=v)),
      const SizedBox(height:12),
      TextFormField(controller:address,decoration:const InputDecoration(labelText:'Địa chỉ chi tiết *'),
        validator:(v)=>(v??'').trim().length<3?'Vui lòng nhập địa chỉ':null),
      const SizedBox(height:12),
      DropdownButtonFormField<String>(
        key:ValueKey('customer-category-$category'),
        initialValue:category,
        isExpanded:true,
        decoration:const InputDecoration(labelText:'Loại điểm bán'),
        items:[for(final option in CustomerCategory.all)
          DropdownMenuItem(value:option.id,child:Row(children:[
            Icon(option.icon,size:20,color:option.color),
            const SizedBox(width:10),
            Flexible(child:Text(option.label,overflow:TextOverflow.ellipsis)),
          ]))],
        onChanged:(v)=>setState(()=>category=v??category)),
      const SizedBox(height:12),
      TextFormField(controller:contact,decoration:const InputDecoration(labelText:'Người liên hệ / Chủ cửa hàng')),
      const SizedBox(height:12),
      TextFormField(controller:phone,keyboardType:TextInputType.phone,
        decoration:const InputDecoration(labelText:'Số điện thoại'),
        validator:(v)=>(v??'').trim().isNotEmpty && !RegExp(r'^[0-9+(). -]{8,20}$').hasMatch(v!.trim())?'SĐT không hợp lệ':null),
      const SizedBox(height:12),
      TextFormField(controller:note,maxLines:3,decoration:const InputDecoration(labelText:'Ghi chú')),
      const SizedBox(height:12),
      OutlinedButton.icon(onPressed:gps,icon:const Icon(Icons.location_on_outlined),label:Text(position==null?'Lấy GPS điểm bán':'GPS: ${position!.latitude.toStringAsFixed(5)}, ${position!.longitude.toStringAsFixed(5)}')),
      OutlinedButton.icon(onPressed:choosePhoto,icon:const Icon(Icons.photo_camera_outlined),
        label:Text(photo==null?'Chọn ảnh điểm bán':'Đã chọn: ${photo!.name}')),
      if(error!=null)Padding(padding:const EdgeInsets.all(8),child:Text(error!,style:const TextStyle(color:Colors.red))),
      const SizedBox(height:12),
      FilledButton(onPressed:saving?null:save,child:Text(saving?'Đang lưu...':'Lưu điểm bán')),
    ])));
}

class CustomerDetail extends StatefulWidget {
  final CustomerService service;
  final FieldCustomer customer;
  final RegionCatalog regions;
  final OfflineQueue? queue;
  const CustomerDetail({super.key,required this.service,required this.customer,required this.regions,this.queue});
  @override State<CustomerDetail> createState()=>_CustomerDetailState();
}

class _CustomerDetailState extends State<CustomerDetail> {
  List<Map<String,dynamic>> gallery=[],visits=[];
  String? selectedCoverId;
  final Map<String,Future<Uint8List>> imageTasks={};
  String? message;
  bool busy=false;
  @override void initState(){
    super.initState();
    widget.queue?.addListener(_queueChanged);
    unawaited(load());
  }
  @override void dispose(){
    widget.queue?.removeListener(_queueChanged);
    super.dispose();
  }
  void _queueChanged(){if(mounted)setState((){});}
  String _date(Object? source){
    final d=DateTime.tryParse(source?.toString()??'')?.toLocal();
    if(d==null)return 'Chưa xác định';
    final day='${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
    return '$day · ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  }
  String _label(Map<String,dynamic> item)=>item['source']=='customer'
    ?'Ảnh điểm bán'
    :photoLabels[item['kind']]??'Ảnh khảo sát';
  List<Map<String,dynamic>> get pendingPhotos{
    final prefix='/api/v1/customers/${widget.customer.id}';
    return (widget.queue?.pending??[]).where((r)=>
      r['photo'] is List && (r['path']=='$prefix/photos'||r['path']==prefix)).toList();
  }
  Future<void> load() async {
    final cid=widget.customer.id;
    try{
      final pictures=await widget.service.media(cid);
      final history=await widget.service.visits(cid);
      final queue=widget.queue;
      if(queue!=null){
        await queue.cache('customer-media:$cid',pictures);
        await queue.cache('visits:$cid',history);
      }
      if(mounted)setState((){gallery=pictures;visits=history;selectedCoverId=null;imageTasks.clear();message=null;});
    }catch(e){
      if(e is ApiFailure&&(e.status==401||e.status==403)){
        if(mounted)setState((){gallery=[];visits=[];imageTasks.clear();message='Không có quyền xem dữ liệu này';});
        return;
      }
      final queue=widget.queue;
      if(queue!=null){
        try{
          final cachedMedia=await queue.cached('customer-media:$cid');
          final cachedVisits=await queue.cached('visits:$cid');
          if(mounted)setState((){gallery=cachedMedia;visits=cachedVisits;message='Đang ngoại tuyến · hiển thị dữ liệu đã lưu trên máy';});
          return;
        }catch(_){}
      }
      if(mounted)setState(()=>message='$e');
    }
  }
  Future<Uint8List> _bytes(Map<String,dynamic> item,{bool thumbnail=true})async{
    final cid=widget.customer.id;
    final key='customer-image:$cid:${item['source']}:${item['id']}:${thumbnail?'thumb':'full'}';
    final queue=widget.queue;
    if(queue!=null){
      final cached=await queue.cached(key);
      if(cached.isNotEmpty&&cached.first['bytes'] is List){
        return Uint8List.fromList((cached.first['bytes'] as List).cast<int>());
      }
    }
    final bytes=await widget.service.mediaBytes(cid,item,thumbnail:thumbnail);
    if(queue!=null){
      try{await queue.cache(key,[{'bytes':bytes}]);}catch(_){}
    }
    return bytes;
  }
  Future<Uint8List> _thumbnail(Map<String,dynamic> item)=>
    imageTasks.putIfAbsent('${item['source']}:${item['id']}',()=>_bytes(item));
  Future<void> _fullScreen(Map<String,dynamic> item,{Uint8List? local}) async{
    await showDialog<void>(context:context,builder:(dialogContext)=>AlertDialog(
      title:Text(local!=null?'Ảnh chờ đồng bộ':_label(item)),
      content:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:540,maxHeight:600),
        child:local!=null?Image.memory(local,fit:BoxFit.contain):FutureBuilder<Uint8List>(
          future:_bytes(item,thumbnail:false),
          builder:(context,snapshot)=>snapshot.hasData
            ?Image.memory(snapshot.data!,fit:BoxFit.contain)
            :Text(snapshot.hasError?'Không tải được ảnh gốc':'Đang tải ảnh gốc…'),
        ),
      ),
      actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Đóng'))],
    ));
  }
  Future<void> addRecord(String kind)async{
    final queue=widget.queue;if(queue==null)return;
    await Navigator.push(context,MaterialPageRoute(builder:(_)=>RecordEditor(
      kind:kind,catalog:widget.regions,linkedCustomer:widget.customer.toJson(),
      onSave:(data)async{await queue.enqueue('/api/v1/records',data);},
    )));
  }
  Future<void> addPhoto(ImageSource source)async{
    if(busy)return;
    setState(()=>busy=true);
    try{
      final photo=await ImagePicker().pickImage(source:source,maxWidth:1600,imageQuality:85);
      if(photo==null)return;
      final queue=widget.queue;
      if(queue!=null){
        final media=compressSurveyMedia(await photo.readAsBytes());
        await queue.enqueue('/api/v1/customers/${widget.customer.id}/photos',{},
          photo:media.image,thumbnail:media.thumbnail,
          sha256:media.hash,thumbnailSha256:media.thumbnailHash,mime:'image/jpeg');
        if(mounted)setState(()=>message='Ảnh đã lưu bền vững trên máy · chờ đồng bộ');
      }else{
        await widget.service.uploadPhoto(widget.customer.id,photo);
        await load();
      }
    }catch(e){if(mounted)setState(()=>message='$e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> checkin()async{
    if(busy)return;
    setState(()=>busy=true);
    try{
      final pos=await captureGps(context);
      if(pos.accuracy>100)throw StateError('Độ chính xác GPS lớn hơn 100m');
      if(widget.queue!=null){
        await widget.queue!.enqueue('/api/v1/customers/${widget.customer.id}/visits',{
          'latitude':pos.latitude,'longitude':pos.longitude,
          'accuracy_m':pos.accuracy,'captured_at':pos.timestamp.toUtc().toIso8601String(),
        });
        if(mounted)setState(()=>message='Đã lưu check-in trên máy · chờ xác minh');
      }else{
        await widget.service.checkin(widget.customer.id,pos,const Uuid().v4());
        if(mounted){setState(()=>message='Check-in thành công');await load();}
      }
    }catch(e){if(mounted)setState(()=>message='$e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Map<String,dynamic>? get _coverPhoto{
    final photos=gallery.where((p)=>p['source']=='customer').toList();
    final pending=(widget.queue?.pending??<Map<String,dynamic>>[])
      .where((r)=>r['path']=='/api/v1/customers/${widget.customer.id}/cover').toList();
    final queuedId=pending.isEmpty?null:(pending.last['payload'] as Map?)?['photo_id']?.toString();
    final id=selectedCoverId??queuedId;
    return photos.where((p)=>p['id'].toString()==id).firstOrNull
      ??photos.where((p)=>p['is_cover']==true).firstOrNull
      ??photos.firstOrNull;
  }
  Future<void> _setCover(Map<String,dynamic> photo)async{
    if(busy||widget.customer.owner!=widget.service.identity)return;
    setState(()=>busy=true);
    try{
      final id=photo['id'].toString();
      if(widget.queue!=null){
        await widget.queue!.enqueue('/api/v1/customers/${widget.customer.id}/cover',
          {'photo_id':id},method:'PATCH');
        if(mounted)setState((){selectedCoverId=id;message='Đã lưu lựa chọn ảnh đại diện · chờ đồng bộ';});
      }else{
        await widget.service.setCover(widget.customer.id,id);
        if(mounted)setState((){selectedCoverId=id;message='Đã cập nhật ảnh đại diện';});
      }
    }catch(e){if(mounted)setState(()=>message='$e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> _call()async{
    final phone=widget.customer.phone?.replaceAll(RegExp(r'[^0-9+]'),'')??'';
    if(phone.isEmpty)return;
    try{
      if(!await launchUrl(Uri(scheme:'tel',path:phone),mode:LaunchMode.externalApplication)){
        throw StateError('Thiết bị không hỗ trợ gọi điện');
      }
    }catch(e){if(mounted)setState(()=>message='$e');}
  }
  Future<void> _map()async{
    final c=widget.customer;
    final query=c.latitude!=null&&c.longitude!=null
      ?'${c.latitude},${c.longitude}'
      :'${c.address}, ${c.district}, ${c.province}, Việt Nam';
    final uri=Uri.https('www.google.com','/maps/search/',{'api':'1','query':query});
    try{
      if(!await launchUrl(uri,mode:LaunchMode.externalApplication))throw StateError('Không mở được bản đồ');
    }catch(e){if(mounted)setState(()=>message='$e');}
  }
  Widget _section(String title,IconData icon,Widget child)=>Card(
    child:Padding(padding:const EdgeInsets.all(14),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Row(children:[Icon(icon,size:20,color:Theme.of(context).colorScheme.primary),
          const SizedBox(width:8),Expanded(child:Text(title,style:Theme.of(context).textTheme.titleMedium))]),
        const SizedBox(height:10),child,
      ]),
    ),
  );
  Widget _line(IconData icon,String label,String value)=>Padding(
    padding:const EdgeInsets.symmetric(vertical:5),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(icon,size:18,color:Theme.of(context).colorScheme.onSurfaceVariant),
      const SizedBox(width:10),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(label,style:Theme.of(context).textTheme.labelSmall),
        Text(value.isEmpty?'Chưa có':value,softWrap:true),
      ])),
    ]),
  );
  Widget _photoTile(Map<String,dynamic> item){
    final chosen=_coverPhoto?['id']==item['id'];
    final own=widget.customer.owner==widget.service.identity;
    return Card(clipBehavior:Clip.antiAlias,margin:EdgeInsets.zero,
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Expanded(child:Stack(fit:StackFit.expand,children:[
          InkWell(onTap:()=>_fullScreen(item),child:FutureBuilder<Uint8List>(
            future:_thumbnail(item),builder:(context,s)=>s.hasData
              ?Image.memory(s.data!,fit:BoxFit.cover)
              :Center(child:Icon(s.hasError?Icons.broken_image_outlined:Icons.image_outlined)))),
          if(own)Positioned(top:4,right:4,child:IconButton.filledTonal(
            tooltip:chosen?'Ảnh đại diện hiện tại':'Chọn làm ảnh đại diện',
            onPressed:chosen||busy?null:()=>_setCover(item),
            icon:Icon(chosen?Icons.star:Icons.star_border),
          )),
        ])),
        Padding(padding:const EdgeInsets.all(8),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(chosen?'Ảnh đại diện':'Ảnh cửa hàng',maxLines:1,overflow:TextOverflow.ellipsis,
            style:Theme.of(context).textTheme.labelMedium),
          Text(_date(item['captured_at']),maxLines:1,overflow:TextOverflow.ellipsis,
            style:Theme.of(context).textTheme.labelSmall),
        ])),
      ]),
    );
  }
  Widget _gallery(){
    final items=gallery.where((p)=>p['source']=='customer').toList();
    final groups=<String,List<Map<String,dynamic>>>{};
    for(final p in items){
      final date=_date(p['captured_at']).split(' · ').first;
      groups.putIfAbsent(date,()=>[]).add(p);
    }
    final pending=pendingPhotos;
    return _section('Hình ảnh cửa hàng · ${items.length}',Icons.photo_library_outlined,Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Wrap(spacing:8,runSpacing:6,children:[
          if(widget.customer.owner==widget.service.identity)
            OutlinedButton.icon(onPressed:busy?null:()=>addPhoto(ImageSource.camera),
              icon:const Icon(Icons.camera_alt_outlined),label:const Text('Chụp ảnh')),
          if(widget.customer.owner==widget.service.identity)
            OutlinedButton.icon(onPressed:busy?null:()=>addPhoto(ImageSource.gallery),
              icon:const Icon(Icons.add_photo_alternate_outlined),label:const Text('Thêm ảnh')),
          IconButton(onPressed:busy?null:load,tooltip:'Tải lại ảnh',icon:const Icon(Icons.refresh)),
        ]),
        if(pending.isNotEmpty)...[
          const SizedBox(height:8),
          Text('Ảnh chờ đồng bộ (${pending.length})',style:Theme.of(context).textTheme.titleSmall),
          for(final p in pending)ListTile(
            leading:const Icon(Icons.cloud_upload_outlined),
            title:const Text('Ảnh cửa hàng lưu trên thiết bị'),
            subtitle:Text(p['status']=='blocked'?'Cần thử đồng bộ lại':'Đang chờ mạng'),
            onTap:()=>_fullScreen(const {},local:Uint8List.fromList(
              (p['thumbnail']??p['photo'] as List).cast<int>())),
            trailing:p['status']=='blocked'&&widget.queue!=null?IconButton(
              tooltip:'Thử lại',onPressed:()=>widget.queue!.retryBlocked(p['key'] as String),
              icon:const Icon(Icons.refresh)):null,
          ),
        ],
        if(groups.isEmpty&&pending.isEmpty)const Padding(
          padding:EdgeInsets.all(12),child:Text('Chưa có ảnh cửa hàng. Hãy thêm ảnh mặt tiền hoặc quầy kệ.')),
        for(final group in groups.entries)...[
          const SizedBox(height:12),
          Text(group.key,style:Theme.of(context).textTheme.titleSmall),
          const SizedBox(height:6),
          LayoutBuilder(builder:(context,box)=>GridView.builder(
            shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
            itemCount:group.value.length,
            gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:box.maxWidth<420?2:4,crossAxisSpacing:8,mainAxisSpacing:8,childAspectRatio:.82),
            itemBuilder:(context,i)=>_photoTile(group.value[i]),
          )),
        ],
      ],
    ));
  }
  @override Widget build(BuildContext context){
    final c=widget.customer,own=c.owner==widget.service.identity;
    final cover=_coverPhoto;
    final gps=c.latitude==null||c.longitude==null?'Chưa ghi nhận':
      '${c.latitude!.toStringAsFixed(6)}, ${c.longitude!.toStringAsFixed(6)}';
    final phone=c.phone?.replaceAll(RegExp(r'[^0-9+]'),'')??'';
    return DefaultTabController(length:3,child:Scaffold(
      appBar:AppBar(title:const Text('Hồ sơ điểm bán'),actions:[
        if(own)IconButton(tooltip:'Sửa thông tin',icon:const Icon(Icons.edit_outlined),onPressed:()async{
          final changed=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>
            CustomerEditor(service:widget.service,regions:widget.regions,customer:c,queue:widget.queue)));
          if(changed==true&&context.mounted)Navigator.pop(context,true);
        }),
      ]),
      body:Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(12,8,12,4),child:Card(
          clipBehavior:Clip.antiAlias,margin:EdgeInsets.zero,
          child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            SizedBox(height:MediaQuery.sizeOf(context).width<=780?148:196,
              child:cover==null
                ?ColoredBox(color:Theme.of(context).colorScheme.primaryContainer,child:Center(
                    child:Column(mainAxisSize:MainAxisSize.min,children:[
                      CustomerCategoryAvatar(category:c.category),
                      const SizedBox(height:8),const Text('Chưa có ảnh cửa hàng'),
                    ])))
                :InkWell(onTap:()=>_fullScreen(cover),child:FutureBuilder<Uint8List>(
                    future:_thumbnail(cover),builder:(context,s)=>s.hasData
                      ?Image.memory(s.data!,width:double.infinity,fit:BoxFit.cover)
                      :ColoredBox(color:Theme.of(context).colorScheme.primaryContainer,
                        child:Center(child:CustomerCategoryAvatar(category:c.category)))))),
            Padding(padding:const EdgeInsets.fromLTRB(12,10,12,4),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Expanded(child:Text(c.name,style:Theme.of(context).textTheme.titleMedium,
                    maxLines:2,overflow:TextOverflow.ellipsis)),
                  const SizedBox(width:8),
                  Text(switch(c.status){'active'=>'Đang hoạt động','inactive'=>'Ngừng hoạt động',
                    'potential'=>'Tiềm năng',_=>c.status},
                    style:Theme.of(context).textTheme.labelSmall),
                ]),
                const SizedBox(height:3),
                CustomerCategoryLabel(category:c.category),
                Text('Mã Field Work: ${c.fieldCode??'Đang cấp sau đồng bộ'}',
                  style:Theme.of(context).textTheme.bodySmall),
                if(c.code?.isNotEmpty==true)Text('Mã khách CTY: ${c.code}',
                  style:Theme.of(context).textTheme.bodySmall),
              ])),
            Padding(padding:const EdgeInsets.fromLTRB(12,6,12,12),child:Row(children:[
              Expanded(child:OutlinedButton.icon(onPressed:phone.isEmpty?null:_call,
                icon:const Icon(Icons.call_outlined,size:18),label:const Text('Gọi điện'))),
              const SizedBox(width:8),
              Expanded(child:OutlinedButton.icon(onPressed:_map,
                icon:const Icon(Icons.map_outlined,size:18),label:const Text('Google Maps'))),
            ])),
          ]),
        )),
        if(message!=null)Padding(padding:const EdgeInsets.symmetric(horizontal:14,vertical:2),
          child:Text(message!,maxLines:2,overflow:TextOverflow.ellipsis,
            style:Theme.of(context).textTheme.bodySmall)),
        Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:4),
          child:Material(
            color:Theme.of(context).colorScheme.surface,
            borderRadius:BorderRadius.circular(9),
            child:const TabBar(tabs:[
              Tab(text:'Thông tin'),Tab(text:'Sản phẩm'),Tab(text:'Hình ảnh'),
            ]),
          )),
        Expanded(child:TabBarView(children:[
          ListView(key:const PageStorageKey('customer-info'),
            padding:const EdgeInsets.fromLTRB(12,4,12,16),children:[
              _section('Thông tin liên hệ',Icons.contact_phone_outlined,Column(children:[
                _line(Icons.person_outline,'Chủ điểm bán / người liên hệ',c.contact??''),
                _line(Icons.phone_outlined,'Số điện thoại',c.phone??''),
              ])),
              _section('Địa chỉ & định vị',Icons.location_on_outlined,Column(
                crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                  _line(Icons.map_outlined,'Tỉnh/TP · Quận/Huyện','${c.province} · ${c.district}'),
                  _line(Icons.place_outlined,'Địa chỉ chi tiết',c.address),
                  _line(Icons.gps_fixed_outlined,'GPS',gps),
                ],
              )),
              if(own&&widget.queue!=null)Padding(padding:const EdgeInsets.symmetric(vertical:6),
                child:Wrap(spacing:8,runSpacing:8,children:[
                  OutlinedButton.icon(onPressed:()=>addRecord('forecast'),
                    icon:const Icon(Icons.payments_outlined),label:const Text('Dự kiến doanh thu')),
                  FilledButton.icon(onPressed:busy?null:checkin,
                    icon:const Icon(Icons.location_pin),label:const Text('Check-in')),
                ])),
              if(!own)const Padding(padding:EdgeInsets.all(8),
                child:Text('Chế độ xem theo phân quyền.')),
              _section('Lịch sử ghé thăm',Icons.history_outlined,
                ExpansionTile(title:Text('${visits.length} lượt check-in'),
                  tilePadding:EdgeInsets.zero,children:[
                    if(visits.isEmpty)const ListTile(title:Text('Chưa có lượt check-in được xác minh.')),
                    for(final v in visits)ListTile(dense:true,
                      leading:const Icon(Icons.verified_outlined),
                      title:Text(_date(v['checkin_at'])),
                      subtitle:Text('Khoảng cách: ${v['distance_m']??'?'} m · GPS: ${v['accuracy_m']??'?'} m')),
                  ])),
            ]),
          ListView(key:const PageStorageKey('customer-products'),
            padding:const EdgeInsets.fromLTRB(12,4,12,16),children:[
              CustomerAssortmentSection(
                customerId:c.id,ownerSub:c.owner??'',editable:own,queue:widget.queue,
                api:CustomerAssortmentApi(widget.service.endpoint,widget.service.token,
                  identity:widget.service.identity,revision:widget.service.revision,client:widget.service.client),
              ),
            ]),
          ListView(key:const PageStorageKey('customer-photos'),
            padding:const EdgeInsets.fromLTRB(12,4,12,16),children:[_gallery()]),
        ])),
      ]),
    ));
  }
}
