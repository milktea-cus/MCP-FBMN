import 'package:flutter/material.dart';

/// Handle legacy single-scope rules and new multi-scope rules equally.
List<Map<String,dynamic>> localTemplateScopes(Map<String,dynamic> template){
 final raw=template['scopes'];
 if(raw is List&&raw.isNotEmpty){
  return raw.whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList();
 }
 final kind=template['scope_kind']?.toString();
 if(kind=='territory'||kind=='customer'||kind=='chain'){
  final key=template['scope_key']?.toString()??'';
  if(key.isNotEmpty)return [<String,dynamic>{
   'scope_kind':kind,'scope_key':key,
   'province':kind=='territory'?template['province']:null,
   'district':kind=='territory'?template['district']:null,
   'label':template['scope_label']??key,
  }];
 }
 final province=template['province']?.toString()??'';
 final district=template['district']?.toString()??'';
 if(province.isEmpty)return [];
 return [<String,dynamic>{
  'scope_kind':'territory','scope_key':'${province}|${district}',
  'province':province,'district':district,
  'label':district.isEmpty?'Toàn tỉnh · ${province}':'${district} · ${province}',
 }];
}
String localScopeFingerprint(Map<String,dynamic> x)=>
 '${x['scope_kind']}:${x['scope_key']}';
String localScopeLabel(Map<String,dynamic> x)=>
 (x['label']??x['scope_key']??'Phạm vi').toString();
String localScopeSummary(List<Map<String,dynamic>> scopes){
 if(scopes.isEmpty)return 'Chọn địa bàn / khách / chuỗi';
 final names=scopes.map(localScopeLabel).toList();
 if(names.length<=2)return names.join(' · ');
 return '${names.take(2).join(' · ')} · +${names.length-2}';
}

/// Shared multi-select surface: category changes and search retain selections.
Future<List<Map<String,dynamic>>?> pickLocalScopes({
 required BuildContext context,
 required List<Map<String,dynamic>> options,
 required List<Map<String,dynamic>> initial,
})async{
 final selected=<String,Map<String,dynamic>>{
  for(final row in initial)localScopeFingerprint(row):Map<String,dynamic>.from(row)
 };
 String query='',category='all';
 return showModalBottomSheet<List<Map<String,dynamic>>>(
  context:context,isScrollControlled:true,showDragHandle:true,
  builder:(sheet)=>SafeArea(child:StatefulBuilder(
   builder:(ctx,refresh)=>SizedBox(
    height:MediaQuery.sizeOf(sheet).height*0.82,
    child:Column(children:[
     Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),
      child:Row(children:[
       Expanded(child:Text('Chọn nhiều địa bàn / khách / chuỗi',
        style:Theme.of(ctx).textTheme.titleMedium)),
       Text('${selected.length}/50',style:Theme.of(ctx).textTheme.labelMedium),
      ])),
     SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
      for(final kind in const ['all','territory','customer','chain'])
       Padding(padding:const EdgeInsets.symmetric(horizontal:3),
        child:ChoiceChip(label:Text({
         'all':'Tất cả','territory':'Tỉnh/huyện',
         'customer':'Khách','chain':'Chuỗi'}[kind]!),
         selected:category==kind,onSelected:(_)=>refresh(()=>category=kind))),
     ])),
     Padding(padding:const EdgeInsets.fromLTRB(12,8,12,5),
      child:TextField(decoration:const InputDecoration(
       prefixIcon:Icon(Icons.search),hintText:'Tìm phạm vi được phân công'),
       onChanged:(v)=>refresh(()=>query=v.trim().toLowerCase()))),
     Expanded(child:Builder(builder:(_){
      final found=options.where((row)=>
       (category=='all'||row['scope_kind']==category)&&
       localScopeLabel(row).toLowerCase().contains(query)).toList();
      if(found.isEmpty)return const Center(child:Text('Không có phạm vi phù hợp'));
      return ListView.builder(
       itemCount:found.length,itemBuilder:(ctx,i){
        final row=found[i],id=localScopeFingerprint(row);
        return CheckboxListTile(
         dense:true,controlAffinity:ListTileControlAffinity.leading,
         value:selected.containsKey(id),
         title:Text(localScopeLabel(row)),
         subtitle:Text({'territory':'Địa bàn','customer':'Khách hàng',
          'chain':'Chuỗi'}[row['scope_kind']]??''),
         onChanged:(checked)=>refresh((){
          if(checked==true&&selected.length<50){
           selected[id]=<String,dynamic>{
            'scope_kind':row['scope_kind'],'scope_key':row['scope_key'],
            'province':row['scope_kind']=='territory'?row['province']:null,
            'district':row['scope_kind']=='territory'?row['district']:null,
            'label':localScopeLabel(row),
           };
          }else if(checked!=true){selected.remove(id);}
         }),
        );
       });
     })),
     Padding(padding:const EdgeInsets.fromLTRB(12,8,12,12),
      child:Row(children:[
       TextButton(onPressed:selected.isEmpty?null:()=>refresh(selected.clear),
        child:const Text('Bỏ chọn')),
       const Spacer(),
       FilledButton.icon(
        icon:const Icon(Icons.check),
        onPressed:selected.isEmpty?null:()=>Navigator.pop(
         sheet,selected.values.toList(growable:false)),
        label:Text('Áp dụng (${selected.length})')),
      ])),
    ]),
   ),
  )));
}
