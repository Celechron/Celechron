import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:celechron/http/zjuServices/zjuam.dart';
import 'package:celechron/http/zjuServices/ecard.dart';

import '../utils/utils.dart';

class ECardWidgetMessenger {
  static Future<void> update() async {
    var secureStorage = const FlutterSecureStorage();
    var username = await secureStorage.read(key: 'username', iOptions: secureStorageIOSOptions);
    var password = await secureStorage.read(key: 'password', iOptions: secureStorageIOSOptions);
    if(username == null || password == null) return;

    var httpClient = HttpClient();
    httpClient.userAgent = "E-CampusZJU/2.3.20 (iPhone; iOS 17.5.1; Scale/3.00)";

    var iPlanetDirectoryPro = await ZjuAm.getSsoCookie(httpClient, username, password);
    if(iPlanetDirectoryPro == null) return;

    var synjonesAuth = await ECard.getSynjonesAuth(httpClient, iPlanetDirectoryPro);
    var eCardAccount = await ECard.getAccount(httpClient, synjonesAuth);
    await secureStorage.write(key: 'synjonesAuth', value: synjonesAuth, iOptions: secureStorageIOSOptions);
    await secureStorage.write(key: 'eCardAccount', value: eCardAccount, iOptions: secureStorageIOSOptions);

    if(Platform.isIOS) {
      const platform = MethodChannel('top.celechron.celechron/ecardWidget');
      await platform.invokeMethod('update');
    }
  }

  static Future<void> logout() async {
    var secureStorage = const FlutterSecureStorage();
    await secureStorage.delete(key: 'synjonesAuth', iOptions: secureStorageIOSOptions);

    if(Platform.isIOS) {
      const platform = MethodChannel('top.celechron.celechron/ecardWidget');
      await platform.invokeMethod('logout');
    }
  }
}