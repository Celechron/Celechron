class CampusAlias {
  final String campusName;
  final List<String> aliases;

  const CampusAlias({
    required this.campusName,
    required this.aliases,
  });
}

class BuildingAlias {
  final String? campusName;
  final List<String> aliases;
  final String fullName;

  const BuildingAlias({
    this.campusName,
    required this.aliases,
    required this.fullName,
  });
}

/// 日历地点映射器
/// 将 zdbk 中的上课地址缩写转换为详细地址，避免日历/地图定位失败。
///
/// 教务网中的地址一般形式为：[校区+教学楼]-[教室]，如“紫金港西1-101”表示“紫金港西1教学楼-101教室”，详细地址为“浙江大学紫金港校区西一教学楼”（根据apple地图）
/// 
/// 目前映射实现方式：
/// 1. 定位字符串中的'-'符号，将其前后部分分开
/// 2. 前半部分（如“紫金港西1”）进行教学楼的解析，转换成更详细的描述（如“浙江大学紫金港校区西一教学楼”）
/// 3. 后半部分（如“101”）直接保留
/// 4. 最终组合成完整的地址字符串（如“浙江大学紫金港校区西一教学楼-101”）
/// 
/// 可能存在不包含'-'符号的地址，目前已知存在这种情况的地址为：
/// - 紫金港田径场（东）
/// - 紫金港风雨操场（羽毛球场）
/// - 紫金港游泳馆
/// - 紫金港机房
/// 目前只有紫金港机房无法定位到海洋大楼，其他地址在地图上均可定位，因此暂时不对这类地址进行特殊处理。
class CalendarLocationMapper {
  static const List<CampusAlias> _campusAliases = [
    CampusAlias(campusName: '紫金港', aliases: ['紫金港']),
    CampusAlias(campusName: '玉泉', aliases: ['玉泉']),
    CampusAlias(campusName: '西溪', aliases: ['西溪']),
    CampusAlias(campusName: '华家池', aliases: ['华家池']),
    CampusAlias(campusName: '之江', aliases: ['之江']),
  ];

  /// 楼宇映射表：后续按这个数组持续补充即可。
  static const List<BuildingAlias> _buildingAliases = [
    // 紫金港
      // 东教
    BuildingAlias(campusName: '紫金港', aliases: ['东1'], fullName: '东一教学楼'),
    BuildingAlias(campusName: '紫金港', aliases: ['东1A'], fullName: '东一教学楼'),
    BuildingAlias(campusName: '紫金港', aliases: ['东1B'], fullName: '东一教学楼'),
    BuildingAlias(campusName: '紫金港', aliases: ['东2'], fullName: '东二教学楼'),
    BuildingAlias(campusName: '紫金港', aliases: ['东3'], fullName: '东三教学楼'),
    BuildingAlias(campusName: '紫金港', aliases: ['东4'], fullName: '东四教学楼'),
    BuildingAlias(campusName: '紫金港', aliases: ['东5'], fullName: '东五教学楼'),
    BuildingAlias(campusName: '紫金港', aliases: ['东6'], fullName: '东六教学楼'),
      // 西教
    BuildingAlias(campusName: '紫金港', aliases: ['西1'], fullName: '西一教学楼'),
    BuildingAlias(campusName: '紫金港', aliases: ['西2'], fullName: '西二教学楼'),
    BuildingAlias(campusName: '紫金港', aliases: ['西3'], fullName: '西三教学楼'),
    BuildingAlias(campusName: '紫金港', aliases: ['西3A'], fullName: '西三教学楼'),
    BuildingAlias(campusName: '紫金港', aliases: ['西3B'], fullName: '西三教学楼'),
      // 北教
    BuildingAlias(campusName: '紫金港', aliases: ['北1'], fullName: '北一教学楼'),
    BuildingAlias(campusName: '紫金港', aliases: ['北2'], fullName: '北二教学楼'),
    BuildingAlias(campusName: '紫金港', aliases: ['北3'], fullName: '北三教学楼'),
    BuildingAlias(campusName: '紫金港', aliases: ['北4'], fullName: '北四教学楼'),
      // 其他
    BuildingAlias(campusName: '紫金港', aliases: ['蒙民伟'], fullName: '蒙民伟楼'),
    BuildingAlias(campusName: '紫金港', aliases: ['机房'], fullName: '海洋大楼'),
    
    // TODO: 其他校区的教学楼映射
  ];

  static String mapForCalendar(String? rawLocation) {
    if (rawLocation == null) return '';
    final raw = rawLocation.trim();
    if (raw.isEmpty) return '';

    final normalized = _normalizeDash(raw);
    final parts = _splitHeadAndRoom(normalized);
    if (parts == null) {
      return _mapWithoutRoom(normalized);
    }

    final head = parts.$1;
    final room = parts.$2;
    if (head.isEmpty) return raw;

    final mappedHead = _mapHeadToFullAddress(head);
    if (mappedHead == null) return raw;
    if (room.isEmpty) return mappedHead;
    return '$mappedHead-$room';
  }

  static String _mapWithoutRoom(String raw) {
    final mappedHead = _mapHeadToFullAddress(raw);
    return mappedHead ?? raw;
  }

  static String? _mapHeadToFullAddress(String head) {
    final campus = _matchCampus(head);
    if (campus == null) return null;

    final buildingRaw = _stripCampusAlias(head, campus).trim();
    if (buildingRaw.isEmpty) {
      return '浙江大学${campus.campusName}校区';
    }

    final buildingName = _mapBuildingName(campus.campusName, buildingRaw);
    return '浙江大学${campus.campusName}校区$buildingName';
  }

  static CampusAlias? _matchCampus(String raw) {
    for (final campus in _campusAliases) {
      for (final alias in campus.aliases) {
        if (raw.contains(alias)) return campus;
      }
    }
    return null;
  }

  static String _stripCampusAlias(String raw, CampusAlias campus) {
    var result = raw;
    for (final alias in campus.aliases) {
      result = result.replaceFirst(alias, '');
    }
    return result;
  }

  static String _mapBuildingName(String campusName, String buildingRaw) {
    // 映射表
    for (final item in _buildingAliases) {
      if (item.campusName != null && item.campusName != campusName) continue;
      if (item.aliases.contains(buildingRaw)) return item.fullName;
    }

    // 未命中，保留原始文本
    return buildingRaw;
  }

  static (String, String)? _splitHeadAndRoom(String raw) {
    final dashIndex = raw.indexOf('-');
    if (dashIndex == -1) return null;
    final head = raw.substring(0, dashIndex).trim();
    final room = raw.substring(dashIndex + 1).trim();
    return (head, room);
  }

  static String _normalizeDash(String raw) {
    return raw
        .replaceAll('－', '-')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('−', '-');
  }
}
