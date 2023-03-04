enum PeriodType { classes, test, user, virtual, flow }

enum DeadlineType { running, suspended, completed, failed, deleted }

Map<DeadlineType, String> deadlineTypeName = {
  DeadlineType.running: '进行中',
  DeadlineType.suspended: '已暂停',
  DeadlineType.completed: '完成',
  DeadlineType.failed: '失败',
};