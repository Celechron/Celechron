import 'dart:convert';
import 'dart:io';
import 'package:celechron/http/zjuServices/tuple.dart';

import 'package:celechron/database/database_helper.dart';
import 'package:celechron/utils/utils.dart';
//import 'package:get/get_connect/http/src/utils/utils.dart';
// import 'package:celechron/model/session.dart';
import '../../model/task.dart';
import 'exceptions.dart';

class Xzzd {
  String? _taskurl;
  List<Cookie>? _tasksession;
  Cookie? _iPlanetDirectoryPro;
  DatabaseHelper? _db;

  set db(DatabaseHelper? db) {
    _db = db;
  }

  Future<bool> login(HttpClient httpClient, Cookie? iPlanetDirectoryPro) async {
    _iPlanetDirectoryPro=iPlanetDirectoryPro;
    final request=await httpClient
        .getUrl(Uri.parse('https://courses.zju.edu.cn/api/todos'))
        .timeout(const Duration(seconds: 8),
        onTimeout: () => throw ExceptionWithMessage("请求超时"));
    request.cookies.add(_iPlanetDirectoryPro!);
    request.followRedirects = false;
    final response = await request.close();
    await response.drain();
    // 检查响应状态码
    if (response.statusCode == 302) {
      final locationHeader = response.headers['location'];
      //print(locationHeader);
      final request2=await httpClient
          .getUrl(Uri.parse(locationHeader!.first))
          .timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request2.cookies.addAll(response.cookies);
      request2.followRedirects = false;
      final response2 = await request2.close();
      await response2.drain();

      final request3=await httpClient
          .getUrl(Uri.parse(response2.headers['location']!.first))
          .timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request3.followRedirects=false;
      request3.cookies.addAll(response2.cookies);
      final response3 = await request3.close();
      
      final request4=await httpClient
          .getUrl(Uri.parse(response3.headers['location']!.first))
          .timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request4.followRedirects=false;
      request4.cookies.add(_iPlanetDirectoryPro!);
      // request4.cookies.addAll(response3.cookies);
      final response4 = await request4.close();

      final request5=await httpClient
          .getUrl(Uri.parse(response4.headers['location']!.first))
          .timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request5.followRedirects=false;
      request5.cookies.add(_iPlanetDirectoryPro!);
      request5.cookies.addAll(response2.cookies);
      request5.cookies.addAll(response4.cookies);
      final response5 = await request5.close();

      final request6=await httpClient
          .getUrl(Uri.parse(response5.headers['location']!.first))
          .timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request6.followRedirects=false;
      request6.cookies.addAll(response5.cookies);
      final response6 = await request6.close();
      _tasksession=response6.cookies;
      _taskurl=response6.headers['location']!.first;
      return true;
    }
    return false;
  }

  void logout() {
    _iPlanetDirectoryPro = null;
    _tasksession = null;
    _taskurl = null;
  }
  
  Future<Tuple<Exception?, List<Task>>> getXzzdTask(
      HttpClient httpClient) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    try {
      request=await httpClient
          .getUrl(Uri.parse(_taskurl!))
          .timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request.cookies.addAll(_tasksession!);
      request.followRedirects=false;
      response = await request.close().timeout(const Duration(seconds: 8),
          onTimeout: () => throw ExceptionWithMessage("请求超时"));
      final taskJson=await response.transform(utf8.decoder).join();
      print(taskJson);
      final jsondecode = jsonDecode(taskJson) ;
      if(jsondecode==null) throw ExceptionWithMessage("解析json失败");
      List<Task> tasklist=[];
      for(var task in jsondecode['todo_list']){
        tasklist.add(Task(
          status:TaskStatus.running,
          description: (
           task['type']=='exam'?
           'https://courses.zju.edu.cn/course/${task['course_id']}/learning-activity#/exam/${task['id']}':
           'https://courses.zju.edu.cn/course/${task['course_id']}/learning-activity#/${task['id']}' 
          ),
          startTime: DateTime.now(),
          endTime: task['end_time']!=null?DateTime.parse(task['end_time']):DateTime.parse('2099-12-31 23:59:59'),
          repeatType: TaskRepeatType.norepeat,
          repeatEndsTime: DateTime.now(),
          summary: '${task['course_name']} ${task['title']}',
        ));
      }
      return Tuple(null, tasklist);
    } catch (e) {
      return Tuple(e is SocketException ? ExceptionWithMessage("网络错误") : e as Exception, []);
    }
  }
  
  
  
}
