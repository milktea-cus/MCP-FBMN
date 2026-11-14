import 'package:flutter/material.dart';
import 'customers.dart';
import 'offline_queue.dart';
import 'models.dart';
import 'route_template_library.dart';
import 'surveys.dart';

/// One secondary settings entry, with the two existing versioned editors.
class SalesSettingsPage extends StatelessWidget {
 final CustomerService service;
 final OfflineQueue queue;
 final RegionCatalog regions;
 final bool admin;
 const SalesSettingsPage({super.key,required this.service,required this.queue,
  required this.regions,required this.admin});
 @override
 Widget build(BuildContext context)=>DefaultTabController(
  length:admin?2:1,
  child:Scaffold(
   appBar:AppBar(
    title:const Text('Thiết lập'),
    bottom:TabBar(isScrollable:false,tabs:[
     const Tab(icon:Icon(Icons.bookmark_outline),text:'Mẫu tuyến'),
     if(admin)const Tab(icon:Icon(Icons.fact_check_outlined),text:'Mẫu làm việc'),
    ]),
   ),
   body:TabBarView(children:[
    RouteTemplateLibraryPage(service:service,queue:queue,embedded:true),
    if(admin)SurveyTemplateAdmin(service:service,regions:regions,embedded:true),
   ]),
  ),
 );
}
