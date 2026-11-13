String dayKey(DateTime day)=>'${day.year.toString().padLeft(4,'0')}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}';
DateTime weekMonday(DateTime day)=>DateTime(day.year,day.month,day.day).subtract(Duration(days:day.weekday-1));
String monthKey(DateTime day)=>dayKey(day).substring(0,7);
/// Five planning periods are dates 1–7, 8–14, 15–21, 22–28, 29–end.
int planningPeriod(DateTime day)=>((day.day-1)~/7)+1;
DateTime monthEnd(DateTime day)=>DateTime(day.year,day.month+1,0);
List<DateTime> periodDays(DateTime month,int period){
 if(period<1||period>5)throw ArgumentError('Kỳ phải từ 1 đến 5');
 final first=(period-1)*7+1,last=monthEnd(month).day;
 return [for(var d=first;d<=last&&d<first+7;d++)DateTime(month.year,month.month,d)];
}
