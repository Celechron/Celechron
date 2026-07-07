import 'package:celechron/database/database_helper.dart';
import 'package:celechron/utils/tuple.dart';

import 'package:celechron/model/grade.dart';
import 'package:celechron/model/semester.dart';
import 'package:celechron/model/todo.dart';

/// getEverything 的返回值：登录错误、抓取错误、学期、成绩、主修成绩、特殊日期、作业
typedef EverythingTuple = Tuple7<List<String?>, List<String?>, List<Semester>,
    List<Grade>, List<double>, Map<DateTime, String>, List<Todo>>;

/// 单个抓取模块的状态（供刷新状态文案使用）
enum FetchModuleState { pending, success, failed }

/// 一个顶层抓取模块的标签与当前状态
class ModuleFetchStatus {
  final String label;
  final FetchModuleState state;

  const ModuleFetchStatus(this.label, this.state);
}

/// 由 getEverything 的抓取错误列表（中间态或最终态）推导各模块状态。
/// null=成功；以「查询进行中」结尾=进行中；其余=失败。
/// 两表长度不等时视为不可信，返回空列表。
List<ModuleFetchStatus> moduleStatusesFromErrors(
    List<String?> errors, List<String> labels) {
  if (errors.length != labels.length) return const [];
  return List.generate(labels.length, (i) {
    final e = errors[i];
    return ModuleFetchStatus(
        labels[i],
        e == null
            ? FetchModuleState.success
            : e.endsWith('查询进行中')
                ? FetchModuleState.pending
                : FetchModuleState.failed);
  });
}

abstract class Spider {
  set db(DatabaseHelper? db);

  Future<List<String?>> login() async {
    throw UnimplementedError();
  }

  void logout() {
    throw UnimplementedError();
  }

  /// 顶层抓取任务的标签序列，与 getEverything 返回值的抓取错误列表下标一一对应
  List<String> get fetchLabels;

  /// onProgress：异步刷新用。每完成一个顶层抓取任务，就带着当前已累积的数据回调一次；
  /// 传 null 则行为与原来完全一致。
  Future<EverythingTuple> getEverything(
      {void Function(EverythingTuple partial)? onProgress}) async {
    throw UnimplementedError();
  }
}

/// 异步刷新支持：给每个顶层抓取任务挂一个旁路监听，任一任务完成就把当前累积的
/// 数据打包回调给上层，让界面先行更新。
///
/// 学期数据由多个任务共同拼装（校历/配置、课表、考试、成绩），必须等
/// [semesterFetchIndices] 指定的任务全部成功后才对外暴露，否则不完整的学期列表
/// 会顶掉本地缓存；特殊日期同理，须等校历/配置任务（下标 0）成功。
/// 全部任务完成后的那一次不再回调，由 getEverything 的正常返回值做最终合并。
void attachEverythingProgress({
  required List<Future<String?>> fetches,
  required List<String> fetchSequence,
  required List<int> semesterFetchIndices,
  required List<String?> loginErrorMessages,
  required List<Semester> semesters,
  required List<Grade> grades,
  required List<double> majorGrade,
  required Map<DateTime, String> specialDates,
  required List<Todo> todos,
  required void Function(EverythingTuple partial) onProgress,
}) {
  var errors = List<String?>.filled(fetches.length, null);
  var done = List<bool>.filled(fetches.length, false);
  for (var i = 0; i < fetches.length; i++) {
    fetches[i].then((e) {
      done[i] = true;
      errors[i] = e == null ? null : '${fetchSequence[i]}查询出错：$e';
      if (done.every((d) => d)) return;
      // 下标 0 为校历/配置任务
      var calendarReady = done[0] && errors[0] == null;
      var semestersReady = calendarReady &&
          semesterFetchIndices.every((j) => done[j] && errors[j] == null);
      // 中间态错误列表：尚未完成的任务标记为“查询进行中”，与“成功（null）”区分开，
      // 让 setScholar / updateLastUpdateTime 的关键字守卫把它们当作“尚未成功”，
      // 只有已成功板块才合并数据、刷新“更新于”时间戳。最终返回值不带该标记。
      var partialErrors = List<String?>.generate(fetches.length,
          (j) => done[j] ? errors[j] : '${fetchSequence[j]}查询进行中');
      // 学期数据由多个任务共同拼装，未就绪时课表一律视为进行中，
      // 避免课表时间戳先于面板数据更新
      if (!semestersReady) {
        var timetableIndex = fetchSequence.indexOf('课表');
        if (timetableIndex >= 0 && partialErrors[timetableIndex] == null) {
          partialErrors[timetableIndex] = '课表查询进行中';
        }
      }
      onProgress(Tuple7(
          loginErrorMessages,
          partialErrors,
          semestersReady
              ? semesters
                  .where((e) =>
                      e.grades.isNotEmpty ||
                      e.sessions.isNotEmpty ||
                      e.exams.isNotEmpty ||
                      e.courses.isNotEmpty)
                  .toList()
              : <Semester>[],
          grades,
          majorGrade,
          calendarReady ? specialDates : <DateTime, String>{},
          todos));
    });
  }
}
