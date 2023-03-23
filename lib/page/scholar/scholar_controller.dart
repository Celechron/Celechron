import 'package:get/get.dart';
import '../../model/user.dart';

class ScholarController extends GetxController {

  var user = Get.find<Rx<User>>(tag: 'user');

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
  }

}
