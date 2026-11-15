import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'offline_queue.dart';
import 'session.dart';

/// School directory is read-only. Bounded account/scope-revision cache uses
/// OfflineQueue's existing IndexedDB (web) / SQLite (Android) storage.
class SchoolDirectoryPage extends StatefulWidget {
  final OfflineQueue queue;
  final SalesSession session;
  const SchoolDirectoryPage({super.key,required this.queue,required this.session});

  @override State<SchoolDirectoryPage> createState()=>_SchoolDirectoryPageState();
}

class _SchoolDirectoryPageState extends State<SchoolDirectoryPage> {
  static const int pageSize=20;
  Map<String,List<String>> areas={};
  String province='',district='',search='';
  final searchController=TextEditingController();
  final List<Map<String,dynamic>> schools=[];
  Timer? debounce;
  int generation=0,page=0,total=0;
  bool loading=false,offline=false,more=false;
  String? error;

  @override void initState(){
    super.initState();
    unawaited(_initialize());
  }

  @override void dispose(){
    generation++;
    debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _initialize()async{
    // The scoped cache is safe to read before requesting fresh permissions.
    try {
      final saved=await widget.queue.cached('schools:areas:v1');
      _setAreas(saved);
    } catch (_) {}
    try{
      final data=await widget.session.get('/api/v1/schools/areas');
      final rows=(data['items'] as List? ?? [])
          .map((row)=>Map<String,dynamic>.from(row as Map)).toList();
      await widget.queue.cache('schools:areas:v1',rows);
      _setAreas(rows);
    }on ApiFailure catch(e){
      if(e.status==401||e.status==403){
        if(mounted)setState((){areas={};schools.clear();error=e.message;});
        return;
      }
    }catch(_){}
    if(mounted)await _load();
  }

  void _setAreas(List<Map<String,dynamic>> rows){
    if(!mounted)return;
    final values=<String,List<String>>{};
    for(final row in rows){
      final p=row['province']?.toString()??'';
      if(p.isEmpty)continue;
      values[p]=((row['districts'] as List?)??[])
          .map((value)=>value.toString()).toSet().toList()..sort();
    }
    setState(()=>areas=values);
  }

  String _cacheKey(int next)=>
    'schools:page:v1:${province.isEmpty?'_':province}:${district.isEmpty?'_':district}:$next';

  void _changeFilters({String? newProvince,String? newDistrict}){
    setState((){
      if(newProvince!=null){
        province=newProvince;
        district='';
      }else if(newDistrict!=null){
        district=newDistrict;
      }
      schools.clear();total=0;page=0;more=false;error=null;
    });
    unawaited(_load());
  }

  Future<void> _load({bool loadMore=false})async{
    if(loading&&loadMore)return;
    final request=++generation;
    final next=loadMore?page+1:1;
    final chosenProvince=province,chosenDistrict=district,chosenSearch=search;
    setState((){
      loading=true;error=null;
      if(!loadMore){schools.clear();page=0;total=0;more=false;}
    });
    final key=_cacheKey(next);
    var hasCached=false;
    if(chosenSearch.isEmpty && next<=3){
      try{
        final saved=await widget.queue.cached(key);
        if(!mounted||request!=generation)return;
        if(saved.isNotEmpty){
          hasCached=true;
          _apply(saved,next,loadMore:loadMore,isOffline:true,
            reportedTotal:null,hasMore:saved.length==pageSize);
        }
      }catch(_){}
    }
    try{
      final uri=Uri(path:'/api/v1/schools',queryParameters:{
        'page':'$next','size':'$pageSize',
        if(chosenProvince.isNotEmpty)'province':chosenProvince,
        if(chosenDistrict.isNotEmpty)'district':chosenDistrict,
        if(chosenSearch.isNotEmpty)'q':chosenSearch,
      });
      final data=await widget.session.get(uri.toString());
      final rows=(data['items'] as List? ?? [])
          .map((row)=>Map<String,dynamic>.from(row as Map)).toList();
      if(!mounted||request!=generation)return;
      final count=(data['total'] as num?)?.toInt()??0;
      _apply(rows,next,loadMore:loadMore,isOffline:false,
        reportedTotal:count,hasMore:data['hasMore']==true);
      if(chosenSearch.isEmpty&&next<=3){
        // Search terms are not persisted; only three pages per territory
        // are cached, preventing unbounded cache growth.
        try{await widget.queue.cache(key,rows);}catch(_){}
      }
    }on ApiFailure catch(e){
      if(!mounted||request!=generation)return;
      setState((){
        loading=false;offline=true;
        if(e.status==401||e.status==403){
          schools.clear();more=false;total=0;hasCached=false;
        }
        error=hasCached?'Không có mạng, đang xem dữ liệu đã lưu.':e.message;
      });
    }catch(_){
      if(!mounted||request!=generation)return;
      setState((){
        loading=false;offline=true;
        error=hasCached?'Không có mạng, đang xem dữ liệu đã lưu.':
          'Không tải được trường học. Hãy thử lại khi có mạng.';
      });
    }
  }

  void _apply(List<Map<String,dynamic>> rows,int current,{
    required bool loadMore,required bool isOffline,
    required int? reportedTotal,required bool hasMore,
  }){
    if(!mounted)return;
    setState((){
      if(!loadMore)schools.clear();
      final seen=schools.map((r)=>r['source_ref'].toString()).toSet();
      for(final school in rows){
        if(seen.add(school['source_ref'].toString()))schools.add(school);
      }
      page=current;
      if(reportedTotal!=null)total=reportedTotal;
      more=hasMore;
      offline=isOffline;
      loading=isOffline;
      error=null;
    });
  }

  void _onSearch(String value){
    debounce?.cancel();
    debounce=Timer(const Duration(milliseconds:350),(){
      if(!mounted)return;
      search=value.trim();
      unawaited(_load());
    });
  }

  Uri? _mapsLink(Map<String,dynamic> school){
    final lat=school['latitude'],lng=school['longitude'];
    if(school['gps_verified']==true&&lat is num&&lng is num&&
       lat.isFinite&&lng.isFinite&&lat.abs()<=90&&lng.abs()<=180){
      return Uri.https('www.google.com','/maps/dir/',{
        'api':'1','destination':'$lat,$lng'
      });
    }
    final link=Uri.tryParse(school['maps_search_url']?.toString()??'');
    if(link?.scheme=='https'&&
       (link?.host=='www.google.com'||link?.host=='google.com')&&
       (link?.path.startsWith('/maps/search')??false))return link;
    return null;
  }

  Future<void> _openMaps(Map<String,dynamic> school)async{
    final uri=_mapsLink(school);
    if(uri==null)return;
    try{
      if(!await launchUrl(uri,mode:LaunchMode.externalApplication)&&mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:Text('Không mở được Google Maps')));
      }
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Không mở được Google Maps')));
    }
  }

  Widget _schoolCard(Map<String,dynamic> school){
    final name=school['name']?.toString()??'Trường học';
    final level=school['education_level']?.toString()??'';
    final location=[school['province_old'],school['district_old']]
        .where((s)=>s!=null&&s.toString().isNotEmpty).join(' · ');
    final address=school['address_text']?.toString()??'Chưa có địa chỉ';
    final verified=school['gps_verified']==true;
    final directions=_mapsLink(school);
    return Card(
      margin:const EdgeInsets.symmetric(horizontal:12,vertical:4),
      child:Padding(padding:const EdgeInsets.fromLTRB(12,10,4,10),
        child:Row(crossAxisAlignment:CrossAxisAlignment.center,children:[
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(name,style:Theme.of(context).textTheme.titleSmall),
            if(level.isNotEmpty)Text(level,style:Theme.of(context).textTheme.labelSmall),
            const SizedBox(height:5),
            Text(location,style:Theme.of(context).textTheme.bodySmall),
            const SizedBox(height:3),
            Text(address,style:Theme.of(context).textTheme.bodyMedium,
              maxLines:3,overflow:TextOverflow.ellipsis),
            if(!verified)Padding(padding:const EdgeInsets.only(top:5),
              child:Text('Vị trí chưa xác minh · Maps tìm theo địa chỉ',
                style:Theme.of(context).textTheme.labelSmall)),
          ])),
          IconButton(
            tooltip:verified?'Chỉ đường bằng GPS đã xác minh':
              'Tìm trường trên Google Maps (chưa xác minh GPS)',
            onPressed:directions==null?null:()=>_openMaps(school),
            icon:const Icon(Icons.directions_outlined)),
        ])));
  }

  @override Widget build(BuildContext context){
    final provinces=areas.keys.toList()..sort();
    final districts=areas[province]??const <String>[];
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Padding(padding:const EdgeInsets.fromLTRB(12,12,12,6),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Trường Học',style:Theme.of(context).textTheme.titleLarge),
          const SizedBox(height:8),
          TextField(controller:searchController,onChanged:_onSearch,
            decoration:const InputDecoration(
              labelText:'Tìm theo tên trường',isDense:true,
              prefixIcon:Icon(Icons.search_outlined))),
          const SizedBox(height:8),
          Row(children:[
            Expanded(child:DropdownButtonFormField<String>(
              key:ValueKey('school-province:$province'),
              initialValue:province,isExpanded:true,
              decoration:const InputDecoration(labelText:'Tỉnh cũ',isDense:true),
              items:[const DropdownMenuItem(value:'',child:Text('Tất cả')),
                for(final p in provinces)DropdownMenuItem(value:p,child:Text(p,
                  overflow:TextOverflow.ellipsis))],
              onChanged:(v)=>_changeFilters(newProvince:v??''))),
            const SizedBox(width:8),
            Expanded(child:DropdownButtonFormField<String>(
              key:ValueKey('school-district:$province:$district'),
              initialValue:district,isExpanded:true,
              decoration:const InputDecoration(labelText:'Huyện cũ',isDense:true),
              items:[const DropdownMenuItem(value:'',child:Text('Tất cả')),
                for(final d in districts)DropdownMenuItem(value:d,
                  child:Text(d,overflow:TextOverflow.ellipsis))],
              onChanged:province.isEmpty?null:
                (v)=>_changeFilters(newDistrict:v??''))),
          ]),
          const SizedBox(height:6),
          Text(offline?'Dữ liệu đã lưu trên máy · cần mạng để cập nhật':
            '$total trường phù hợp',
            style:Theme.of(context).textTheme.bodySmall),
          if(error!=null)Padding(padding:const EdgeInsets.only(top:6),
            child:Row(children:[
              Expanded(child:Text(error!,
                style:TextStyle(color:Theme.of(context).colorScheme.error))),
              TextButton(onPressed:loading?null:()=>_load(),
                child:const Text('Thử lại')),
            ])),
        ])),
      if(loading&&schools.isEmpty)const LinearProgressIndicator(minHeight:2),
      Expanded(child:schools.isEmpty
        ?Center(child:Text(loading?'Đang tải danh sách...':
          error!=null?'Chưa có dữ liệu khả dụng':'Không tìm thấy trường trong phạm vi của bạn'))
        :ListView.builder(
          itemCount:schools.length+(more?1:0),
          itemBuilder:(context,i){
            if(i==schools.length)return Padding(
              padding:const EdgeInsets.all(12),
              child:OutlinedButton(
                onPressed:loading?null:()=>_load(loadMore:true),
                child:Text(loading?'Đang tải...':'Tải thêm trường')));
            return _schoolCard(schools[i]);
          })),
    ]);
  }
}
