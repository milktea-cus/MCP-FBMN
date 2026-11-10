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

class FieldCustomer {
  final String id, name, address, province, district, category, status;
  final String? phone, contact, note;
  final double? latitude, longitude;
  final int version;
  FieldCustomer.fromJson(Map<String, dynamic> j)
      : id = j['id'].toString(), name = j['name'].toString(),
        address = j['address_line'].toString(), province = j['province'].toString(),
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
  const CustomerService(this.endpoint, this.token,{this.province=''});
  Uri uri(String path, [Map<String, String>? query]) {
    final url = Uri.parse('${endpoint.replaceFirst(RegExp(r'/$'), '')}$path');
    if (url.scheme != 'https' && url.host != 'localhost' && url.host != '127.0.0.1') {
      throw StateError('API phải sử dụng HTTPS');
    }
    return url.replace(queryParameters: query);
  }
  Map<String, String> get headers => sessionHeaders(token);
  Map<String, dynamic> decode(http.Response res, [int ok = 200]) {
    final data = decodeApi(res);
    if (res.statusCode != ok && !(ok == 201 && res.statusCode == 200)) {
      throw StateError(data['error']?.toString() ?? 'Lỗi ${res.statusCode}');
    }
    return data;
  }
  Future<List<FieldCustomer>> list() async {
    final data = decode(await http.get(uri('/api/v1/customers',{'province':province}), headers: headers));
    return (data['items'] as List<dynamic>)
        .map((e) => FieldCustomer.fromJson(e as Map<String, dynamic>)).toList();
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
    final name = photo.name.toLowerCase();
    final mime = name.endsWith('.png') ? 'image/png' : name.endsWith('.webp') ? 'image/webp' : 'image/jpeg';
    final bytes = await photo.readAsBytes();
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) throw StateError('Ảnh quá 5 MB');
    final res = await http.post(uri('/api/v1/customers/$customerId/photos'),
      headers: {...headers, 'Content-Type': mime, 'X-Upload-Id': const Uuid().v4()}, body: bytes);
    decode(res, 201);
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
  bool loading = false;
  String? error;
  @override
  void initState() {super.initState(); refresh();}
  Future<void> refresh() async {
    setState(() => loading = true);
    try {
      final items = await widget.service.list();
      if (mounted) setState(() {customers = items; error = null;});
    } catch (e) {if (mounted) setState(() {error = '$e';});}
    finally {if (mounted) setState(() => loading = false);}
  }
  Future<void> add() async {
    final created = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) =>
        CustomerEditor(service: widget.service, regions: widget.regions,queue:widget.queue)));
    if (created == true) refresh();
  }
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(18,16,18,8), child: Row(children: [
        const Expanded(child: Text('Khách hàng / Điểm bán', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
        IconButton(onPressed: refresh, icon: const Icon(Icons.refresh)),
        FilledButton.icon(onPressed: add, icon: const Icon(Icons.add), label: const Text('Thêm điểm bán')),
      ])),
      if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!,style: const TextStyle(color: Colors.red))),
      if (loading) const LinearProgressIndicator(),
      Expanded(child: customers.isEmpty ? const Center(child: Text('Chưa có điểm bán trong phạm vi được cấp'))
      : ListView.builder(itemCount: customers.length, itemBuilder: (ctx,i) {
        final c = customers[i];
        return Card(child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.storefront)),
          title: Text(c.name), subtitle: Text('${c.district}, ${c.province} · ${c.address}'),
          trailing: IconButton(tooltip:'Sửa thông tin',icon:const Icon(Icons.edit_outlined),onPressed:() async {final changed=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>CustomerEditor(service:widget.service,regions:widget.regions,customer:c,queue:widget.queue)));if(changed==true&&mounted)refresh();}),
          onTap: () async {final changed=await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) =>
            CustomerDetail(service: widget.service, customer: c,regions:widget.regions,queue:widget.queue)));if(changed==true&&mounted)refresh();},
        ));
      })),
    ]);
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
    phone = TextEditingController(), note = TextEditingController();
  final clientRef = const Uuid().v4();
  String? province, district;
  String category = 'tap_hoa';
  Position? position;
  XFile? photo;
  bool saving = false;
  String? error;
  @override void initState(){super.initState();final c=widget.customer;if(c!=null){name.text=c.name;address.text=c.address;contact.text=c.contact??'';phone.text=c.phone??'';note.text=c.note??'';province=c.province;district=c.district;category=c.category;}}
  @override void dispose() {name.dispose(); address.dispose();contact.dispose();phone.dispose();note.dispose();super.dispose();}
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
      final data=<String,dynamic>{if(widget.customer==null)'client_ref':clientRef,'name':name.text.trim(),
        'address_line':address.text.trim(),'contact_name':contact.text.trim().isEmpty?null:contact.text.trim(),
        'phone':phone.text.trim().isEmpty?null:phone.text.trim(),'note':note.text.trim().isEmpty?null:note.text.trim(),
        'province':province,'district':district,'category':category,
        if(widget.customer==null||position!=null)...{'location_consent':position != null,'latitude':position?.latitude,'longitude':position?.longitude,'location_accuracy_m':position?.accuracy}};
      if(widget.queue!=null){
        final bytes=await photo?.readAsBytes();
        final filename=photo?.name.toLowerCase()??'';
        final mime=filename.endsWith('.png')?'image/png':filename.endsWith('.webp')?'image/webp':'image/jpeg';
        await widget.queue!.enqueue(widget.customer==null?'/api/v1/customers':'/api/v1/customers/${widget.customer!.id}',{...data,if(widget.customer!=null)'version':widget.customer!.version,'client_ref':clientRef},photo:bytes,mime:mime,method:widget.customer==null?'POST':'PATCH');
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
      DropdownButtonFormField<String>(initialValue:category,decoration:const InputDecoration(labelText:'Loại điểm bán'),
        items: const [DropdownMenuItem(value:'tap_hoa',child:Text('Tạp hóa')),
          DropdownMenuItem(value:'sieu_thi',child:Text('Siêu thị')),
          DropdownMenuItem(value:'dai_ly',child:Text('Đại lý')),
          DropdownMenuItem(value:'npp',child:Text('Nhà phân phối')),
          DropdownMenuItem(value:'khac',child:Text('Khác'))],onChanged:(v)=>setState(()=>category=v??'tap_hoa')),
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
  List<String> photos=[];
  String? message;
  bool busy=false;
  @override void initState(){super.initState();load();}
  Future<void> load() async {try {final v=await widget.service.photos(widget.customer.id);if(mounted)setState(()=>photos=v);}catch(e){if(mounted)setState(()=>message='$e');}}
  Future<void> checkin() async {
    if(busy)return;
    setState(()=>busy=true);
    try{final pos=await captureGps(context);
      if(pos.accuracy>100)throw StateError('Độ chính xác GPS lớn hơn 100m');
      if(widget.queue!=null){await widget.queue!.enqueue('/api/v1/customers/${widget.customer.id}/visits',{'latitude':pos.latitude,'longitude':pos.longitude,'accuracy_m':pos.accuracy});if(mounted)setState(()=>message='Đã lưu check-in trên máy · chờ xác minh và đồng bộ');return;}
      await widget.service.checkin(widget.customer.id,pos,const Uuid().v4());
      if(mounted)setState(()=>message='Check-in thành công. Vị trí đã được xác minh trên server.');
    }catch(e){if(mounted)setState(()=>message='$e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;
    return Scaffold(
      appBar: AppBar(title: Text(customer.name),actions:[IconButton(tooltip:'Sửa thông tin',icon:const Icon(Icons.edit_outlined),onPressed:() async {final changed=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>CustomerEditor(service:widget.service,regions:widget.regions,customer:customer,queue:widget.queue)));if(changed==true&&context.mounted)Navigator.pop(context,true);})]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(customer.name, style: Theme.of(context).textTheme.headlineSmall),
          Text('${customer.category} · ${customer.status}'),
          const SizedBox(height: 12),
          Text('Địa chỉ: ${customer.address}, ${customer.district}, ${customer.province}'),
          Text('Chủ điểm bán: ${customer.contact ?? 'Chưa có'}'),
          Text('Số điện thoại: ${customer.phone ?? 'Chưa có'}'),
          Text('GPS: ${customer.latitude?.toStringAsFixed(6) ?? 'Chưa ghi'} / ${customer.longitude?.toStringAsFixed(6) ?? 'Chưa ghi'}'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy ? null : checkin,
            icon: const Icon(Icons.location_pin),
            label: Text(busy ? 'Đang lấy vị trí' : 'Check-in điểm bán (200m)'),
          ),
          if (message != null) Text(message!),
          const SizedBox(height: 24),
          Text('Ảnh điểm bán (${photos.length})', style: Theme.of(context).textTheme.titleMedium),
          ...photos.map((photoId) => FutureBuilder<Uint8List>(
            future: widget.service.photoBytes(customer.id, photoId),
            builder: (ctx, snapshot) {
              if (snapshot.hasData) {
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Image.memory(snapshot.data!, height: 180, fit: BoxFit.contain),
                );
              }
              return const Padding(
                padding: EdgeInsets.all(10),
                child: Text('Đang tải ảnh...'),
              );
            },
          )),
        ],
      ),
    );
  }
}
