import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_advanced_networkimage/provider.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:bot_toast/bot_toast.dart';

import '../page/new_page.dart';
import '../page/user_page.dart';
import '../function/identity.dart';
import 'package:pixivic/provider/collection_model.dart';

// 用于 PicPage 的临时变量
double homeScrollerPosition = 0;
List homePicList = [];
int homeCurrentPage = 1;
String homePicDate;
String homePicModel;
int cacheSize;

SharedPreferences prefs;
//验证码验证图片
String tempVerificationCode;
String tempVerificationImage;
bool isLogin; // 记录登录状态（已登录，未登录）用于控制是否展示loginPage

Dio dioPixivic;

List<String> keywordsString = [
  'auth',
  'name',
  'email',
  'qqcheck',
  'avatarLink',
  'gender',
  'signature',
  'location',
  'previewQuality',
];
List<String> keywordsInt = ['id', 'star', 'sanityLevel', 'previewRule'];
List<String> keywordsBool = [
  'isBindQQ',
  'isCheckEmail',
  'isBackTipsKnown',
  'isPicTipsKnown'
];

GlobalKey<NewPageState> newPageKey;
GlobalKey<UserPageState> userPageKey;

// 初始化数据
Future initData(BuildContext context) async {
  newPageKey = GlobalKey();
  userPageKey = GlobalKey();

  prefs = await SharedPreferences.getInstance();
  cacheSize = await DiskCache().cacheSize();

  print('The disk usage for cache is $cacheSize');
  // 遍历所有key，对不存在的 key 进行 value 初始化
  print(prefs.getKeys());
  print('The user name is : ${prefs.getString('name')}');

  for (var item in keywordsString) {
    if (prefs.getString(item) == null) prefs.setString(item, '');
  }
  for (var item in keywordsInt) {
    if (prefs.getInt(item) == null) {
      if (item == 'sanityLevel')
        prefs.setInt(item, 3);
      else if (item == 'previewRule')
        prefs.setInt(item, 7);
      else
        prefs.setInt(item, 0);
    }
  }
  for (var item in keywordsBool) {
    if (prefs.getBool(item) == null) prefs.setBool(item, false);
  }

  // 检查是否登录，若登录则检查是否过期
  if (prefs.getString('auth') != '') {
    isLogin = true;
    checkAuth().then((result) {
      print('Chek auth result is $result');
      if (result)
        isLogin = true;
      else {
        logout(context, isInit: true);
      }
    });
  } else
    logout(context, isInit: true);

  if (prefs.getString('auth') != '') {
    Provider.of<CollectionUserDataModel>(context, listen: false);
  }

  if (prefs.getString('previewQuality') == '')
    prefs.setString('previewQuality', 'medium');

  // Dio 单例暂时放置于此
  dioPixivic = Dio(BaseOptions(
      baseUrl: 'https://api.pixivic.com',
      connectTimeout: 150000,
      receiveTimeout: 150000,
      headers: prefs.getString('auth') == ''
          ? {'Content-Type': 'application/json'}
          : {
              'authorization': prefs.getString('auth'),
              'Content-Type': 'application/json'
            }));

  dioPixivic.interceptors
      .add(InterceptorsWrapper(onRequest: (RequestOptions options) async {
    print(options.uri);
    print(options.headers);
    return options;
  }, onResponse: (Response response) async {
    return response;
  }, onError: (DioError e) async {
    if (e.response != null) {
      BotToast.showSimpleNotification(title: e.response.data['message']);
      print(e.response.statusCode);
      print(e.response.data);
      print(e.response.headers);
      print(e.response.request);
      return e;
    } else {
      // Something happened in setting up or sending the request that triggered an Error
      BotToast.showSimpleNotification(title: e.message);
      print(e.request);
      print(e.message);
      return e;
    }
  }));
}
