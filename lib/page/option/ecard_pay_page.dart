import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:celechron/design/persistent_headers.dart';
import '../../http/zjuServices/ecard.dart';
import '../../utils/utils.dart';

class ECardPayPage extends StatelessWidget {
  ECardPayPage({super.key});

  final _httpClient = HttpClient();

  Future<String?> _requestNewCode() async {
    const secureStorage = FlutterSecureStorage();
    var synjonesAuth = await secureStorage.read(key: 'synjonesAuth', iOptions: secureStorageIOSOptions);
    var eCardAccount = await secureStorage.read(key: 'eCardAccount', iOptions: secureStorageIOSOptions);
    if(synjonesAuth == null) return '';
    eCardAccount ??= await ECard.getAccount(_httpClient, synjonesAuth);
    try {
      _httpClient.userAgent = "E-CampusZJU/2.3.20 (iPhone; iOS 17.5.1; Scale/3.00)";
      return await ECard.getBarcode(_httpClient, synjonesAuth, eCardAccount);
    } catch (e) {
      return null;
    }
  }

  final RxString _barcode = ''.obs;
  final RxBool _loading = true.obs;


  @override
  Widget build(BuildContext context) {
    _requestNewCode().then((code) {
      if (code == null) {
        _requestNewCode().then((code) {
          _loading.value = false;
          _barcode.value = code ?? '';
        });
      } else {
        _loading.value = false;
        _barcode.value = code;
      }
    });
    return CupertinoPageScaffold(
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            const CelechronSliverTextHeader(subtitle: '付款码'),
            SliverFillRemaining(
                child: Column(
              children: [
                const Spacer(
                  flex: 4,
                ),
                Obx(() {
                  if (_loading.value) {
                    return const CupertinoActivityIndicator();
                  } else {
                    return GestureDetector(
                      onTap: () => _requestNewCode().then((value) => _barcode.value = value ?? ''),
                        child: Stack(
                          alignment: Alignment.center,
                      children: [
                        // White background
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        _barcode.value.isNotEmpty && _barcode.value.length < 30 ? QrImageView(data: _barcode.value, version: 3, size: 200) : Text(_barcode.value, style: const TextStyle(color: CupertinoColors.black)),
                      ],
                    ));
                }}),
                const SizedBox(
                  height: 20,
                ),
                Obx(() {
                  if (_loading.value) {
                    return const Text('加载中...');
                  }
                  return Text('付款码：${_barcode.value.isNotEmpty ? _barcode.value : '加载失败'}');
                }),
                const Spacer(
                  flex: 6,
                ),
              ],
            ))
          ],
        ),
      ),
    );
  }
}
