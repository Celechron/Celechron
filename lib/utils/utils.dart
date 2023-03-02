enum PeriodType { classes, test, user, virtual }

enum DeadlineType { running, suspended, completed, failed }

Map<DeadlineType, String> deadlineTypeName = {
  DeadlineType.running: '进行中',
  DeadlineType.suspended: '已暂停',
  DeadlineType.completed: '完成',
  DeadlineType.failed: '已过期',
};
