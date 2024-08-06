import 'dart:convert';
import 'dart:io';
import 'package:celechron/http/zjuServices/tuple.dart';

import 'package:celechron/database/database_helper.dart';
import 'package:celechron/utils/utils.dart';
import 'package:get/get_connect/http/src/utils/utils.dart';
// import 'package:celechron/model/session.dart';
import '../../model/task.dart';
import 'exceptions.dart';

class Xzzd {
  Cookie? _jSessionId;
  Cookie? _route;
  DatabaseHelper? _db;

  set db(DatabaseHelper? db) {
    _db = db;
  }

  Future<bool> login(HttpClient httpClient, Cookie? iPlanetDirectoryPro) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    if (iPlanetDirectoryPro == null) {
      throw ExceptionWithMessage("iPlanetDirectoryPro无效");
    }
    request = await httpClient
        .getUrl(Uri.parse(
            "https://zjuam.zju.edu.cn/cas/login?service=http%3A%2F%2Fzjuam.zju.edu.cn%2Fcas%2Foauth2.0%2FcallbackAuthorize"))
        .timeout(const Duration(seconds: 8),
            onTimeout: () => throw ExceptionWithMessage("请求超时"));
    request.followRedirects = false;
    request.cookies.add(iPlanetDirectoryPro);
    response = await request.close().timeout(const Duration(seconds: 8),
        onTimeout: () => throw ExceptionWithMessage("请求超时"));
    response.drain();

    request = await httpClient
        .getUrl(Uri.parse(response.headers.value('location') ??
            (throw ExceptionWithMessage("iPlanetDirectoryPro无效"))))
        .timeout(const Duration(seconds: 8),
            onTimeout: () => throw ExceptionWithMessage("请求超时"));
    request.followRedirects = false;
    response = await request.close().timeout(const Duration(seconds: 8),
        onTimeout: () => throw ExceptionWithMessage("请求超时"));
    response.drain();

    if (response.cookies.any((element) => element.name == 'JSESSIONID')) {
      _jSessionId = response.cookies
          .firstWhere((element) => element.name == 'JSESSIONID');
    } else {
      throw ExceptionWithMessage("无法获取JSESSIONID");
    }
    if (response.cookies.any((element) => element.name == 'route')) {
      _route =
          response.cookies.firstWhere((element) => element.name == 'route');
    } else {
      throw ExceptionWithMessage("无法获取route");
    }
    var p=getXzzdTask(httpClient);//for debug
    print(p);
    

    return true;
  }

  void logout() {
    _jSessionId = null;
    _route = null;
  }
  
  Future<Tuple<Exception?, List<Task>>> getXzzdTask(
      HttpClient httpClient) async {
    late HttpClientRequest request;
    late HttpClientResponse response;

    try {
      if (_jSessionId == null) {
        throw ExceptionWithMessage("未登录");
      }
      request = await httpClient
          .getUrl(Uri.parse(
              "https://courses.zju.edu.cn/api/todos?no-intercept=true"))
          .timeout(const Duration(seconds: 8),
              onTimeout: () => throw ExceptionWithMessage("请求超时"));
      request.cookies.add(_jSessionId!);
      request.cookies.add(_route!);
      request.followRedirects = false;
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
