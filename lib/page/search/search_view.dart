// Official packages
import 'package:extended_sliver/extended_sliver.dart';
import 'package:flutter/cupertino.dart';
import 'package:celechron/page/scholar/course_list/course_brief_card.dart';
import 'package:get/get.dart';

import 'search_controller.dart';


class SearchPage extends StatelessWidget {
  SearchPage({super.key});

  final _searchController = Get.put(SearchPageController());

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
        backgroundColor: CupertinoDynamicColor.resolve(
            CupertinoColors.systemGroupedBackground, context),
        child: SafeArea(
            child: CustomScrollView(slivers: [
          SliverPinnedToBoxAdapter(
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(children: [
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoSearchTextField(
                            placeholder: '搜索课程，事项...',
                            placeholderStyle: CupertinoTheme.of(context)
                                .textTheme
                                .textStyle
                                .copyWith(
                                    color: CupertinoColors.systemGrey,
                                    height: 1.25,
                                    fontSize: 18),
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .textStyle
                                .copyWith(height: 1.25, fontSize: 18),
                            borderRadius: BorderRadius.circular(12),
                            itemColor: CupertinoColors.systemGrey,
                            itemSize: 20,
                            suffixInsets: const EdgeInsetsDirectional.fromSTEB(
                                0, 0, 5, 0),
                            prefixInsets: const EdgeInsetsDirectional.fromSTEB(
                                10, 0, 0, 0),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 8),
                            onChanged: (String value) {
                              _searchController.searchWord.value= value;
                            },
                            autofocus: true,
                          ),
                        ),
                      ],
                    )
                  ]))),
              Obx(() => SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) => Container(
                    padding: index == 0 ? const EdgeInsets.only(top: 0, bottom: 5, left: 16, right: 16) : const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    child: CourseBriefCard(
                      course: _searchController.courseResult[index],
                      allowDirect: true,
                    ),
                  ),
                  childCount: _searchController.courseResult.length,
                ),
              )),
        ])));
  }
}
