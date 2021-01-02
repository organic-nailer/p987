import 'dart:math' as Math;

import 'package:expanded_grid/expanded_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_gesture_detector/simple_gesture_detector.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '.987',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage()
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);
  @override
  SlidePageState createState() => SlidePageState();
}

class SlidePageState extends State<MyHomePage> with TickerProviderStateMixin {
  Map<int, TileData> tilesMap = {};
  List<TileData> tilesPool = [];
  List<TileData> removePool = [];
  final int xLength = 4;
  final int yLength = 4;
  bool canSwipe = true;

  bool menuVisible = false;
  bool clearVisible = false;
  bool failedVisible = false;
  bool alreadyCleared = false;
  int score = 0;
  int prevHighScore = 0;

  AnimationController _menuController;

  void restartGame() {
    tilesMap.clear();
    tilesPool.clear();
    removePool.clear();
    alreadyCleared = false;
    score = 0;
    Future(() async {
      var prefs = await SharedPreferences.getInstance();
      prevHighScore = prefs.getInt("HIGH") ?? 0;
    });

    menuVisible = false;
    clearVisible = false;
    failedVisible = false;

    addTile();
    addTile();
    setState(() { });

    canSwipe = true;
  }

  @override
  void initState() {
    super.initState();
    _menuController = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this
    );
    addTile();
    addTile();
    Future(() async {
      var prefs = await SharedPreferences.getInstance();
      prevHighScore = prefs.getInt("HIGH") ?? 0;
    });
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  void addTile() {
    if(tilesMap.length >= xLength * yLength) return;
    while(true) {
      var randomX = Math.Random().nextInt(xLength);
      var randomY = Math.Random().nextInt(yLength);
      var randomValue = Math.Random().nextBool() ? 2 : 4;
      if(!tilesMap.containsKey(randomX * 10 + randomY)) {
        tilesMap[randomX * 10 + randomY] = TileData(UniqueKey(), randomValue);
        tilesPool.add(tilesMap[randomX * 10 + randomY]..positionX = randomX..positionY = randomY);
        break;
      }
    }
  }

  void incrementScore(int value) async {
    score += value;
    if(score > prevHighScore) {
      var prefs = await SharedPreferences.getInstance();
      prefs.setInt("HIGH", score);
    }
  }

  bool tiltBoard(Direction direction) {
    tilesPool.clear();
    bool scanAxisIsX;
    int scanDirection;

    switch(direction) {
      case Direction.TOP:
        print("↑");
        scanAxisIsX = false;
        scanDirection = 1;
        break;
      case Direction.BOTTOM:
        print("↓");
        scanAxisIsX = false;
        scanDirection = -1;
        break;
      case Direction.LEFT:
        print("←");
        scanAxisIsX = true;
        scanDirection = 1;
        break;
      case Direction.RIGHT:
        print("→");
        scanAxisIsX = true;
        scanDirection = -1;
        break;
    }

    bool moved = false;
    for(int moveAxisIndex = 0; moveAxisIndex < (scanAxisIsX ? yLength : xLength); moveAxisIndex++) {
      var oldArrayCursor = scanDirection > 0 ? 0 : xLength - 1;
      var newArrayCursor = oldArrayCursor;
      while(oldArrayCursor < xLength && oldArrayCursor >= 0) {
        if(oldArrayCursor != newArrayCursor
            && tilesMap.containsKey(genKey(oldArrayCursor, moveAxisIndex, scanAxisIsX))) {
          if(tilesMap.containsKey(genKey(newArrayCursor, moveAxisIndex, scanAxisIsX))) {
            if(tilesMap[genKey(oldArrayCursor, moveAxisIndex, scanAxisIsX)].value
                == tilesMap[genKey(newArrayCursor, moveAxisIndex, scanAxisIsX)].value) {
              tilesMap[genKey(newArrayCursor, moveAxisIndex, scanAxisIsX)].value *= 2;
              var upScore = tilesMap[genKey(newArrayCursor, moveAxisIndex, scanAxisIsX)].value;
              var newKey = genKey(newArrayCursor, moveAxisIndex, scanAxisIsX);
              newArrayCursor += scanDirection;
              var oldKey = genKey(oldArrayCursor, moveAxisIndex, scanAxisIsX);
              tilesPool.add(tilesMap[oldKey]..positionX = (newKey / 10).floor()..positionY = newKey % 10);
              removePool.add(tilesMap[genKey(oldArrayCursor, moveAxisIndex, scanAxisIsX)]);
              tilesMap.remove(genKey(oldArrayCursor, moveAxisIndex, scanAxisIsX));
              moved = true;
              Future(() async { incrementScore(upScore); });
            }
            else {
              newArrayCursor += scanDirection;
              if(oldArrayCursor != newArrayCursor) {
                tilesMap[genKey(newArrayCursor, moveAxisIndex, scanAxisIsX)]
                = tilesMap[genKey(oldArrayCursor, moveAxisIndex, scanAxisIsX)];
                //removePool.add(tilesMap[genKey(oldArrayCursor, moveAxisIndex, scanAxisIsX)]);
                tilesMap.remove(genKey(oldArrayCursor, moveAxisIndex, scanAxisIsX));
                moved = true;
              }
            }
          }
          else {
            tilesMap[genKey(newArrayCursor, moveAxisIndex, scanAxisIsX)]
            = tilesMap[genKey(oldArrayCursor, moveAxisIndex, scanAxisIsX)];
            //removePool.add(tilesMap[genKey(oldArrayCursor, moveAxisIndex, scanAxisIsX)]);
            tilesMap.remove(genKey(oldArrayCursor, moveAxisIndex, scanAxisIsX));
            moved = true;
          }
        }
        oldArrayCursor += scanDirection;
      }
    }
    tilesMap.forEach((k, v) {
      tilesPool.add(v
        ..positionX = (k / 10).floor()
        ..positionY = k % 10
      );
    });
    return moved;
    //tilesPool.addAll(removePool);
  }

  int genKey(int scanAxis, int moveAxis, bool scanAxisIsX) {
    return scanAxisIsX ? scanAxis * 10 + moveAxis : moveAxis * 10 + scanAxis;
  }

  void onSwipe(SwipeDirection direction) {
    if(!canSwipe || clearVisible || failedVisible || menuVisible) return;
    canSwipe = false;
    var moved = false;
    switch(direction) {
      case SwipeDirection.up:
        moved = tiltBoard(Direction.TOP);
        break;
      case SwipeDirection.down:
        moved = tiltBoard(Direction.BOTTOM);
        break;
      case SwipeDirection.left:
        moved = tiltBoard(Direction.LEFT);
        break;
      case SwipeDirection.right:
        moved = tiltBoard(Direction.RIGHT);
        break;
    }
    //printBoard();
    if(!moved) {
      print("移動できません");
      canSwipe = true;
      return;
    }
    setState(() {});
    Future.delayed(const Duration(milliseconds: 350), () {
      addTile();
      removePool.forEach((e) { tilesPool.remove(e); });
      removePool.clear();
      setState(() {});
      //print("tilePool:$tilesPool}");
      //print("removePool:$removePool");

      if(!alreadyCleared && tilesPool.any((e) => e.value >= 2021)) {
        alreadyCleared = true;
        setState(() {
          clearVisible = true;
        });
      }

      if(!canTilt()) {
        setState(() {
          failedVisible = true;
        });
      }
      canSwipe = true;
    });
  }

  bool canTilt() {
    if(tilesPool.length <= 15) return true;
    for(int row = 0; row < yLength; row++) {
      for(int col = 0; col < xLength - 1; col++) {
        if(tilesMap[col * 10 + row].value == tilesMap[(col+1) * 10 + row].value) {
          return true;
        }
      }
    }
    for(int col = 0; col < xLength; col++) {
      for(int row = 0; row < yLength - 1; row++) {
        if(tilesMap[col * 10 + row].value == tilesMap[col * 10 + row + 1].value) {
          return true;
        }
      }
    }
    return false;
  }

  void printBoard() {
    print("----");
    List<List<String>> res = List.generate(yLength, (i) => List.generate(xLength, (i) => "__"));
    for (var value in tilesPool) {
      if(res[value.positionY][value.positionX] != "__") {
        res[value.positionY][value.positionX] += "&" + value.value.toString().padLeft(2, "0");
      }
      else {
        res[value.positionY][value.positionX] = value.value.toString().padLeft(2, "0");
      }
    }
    for (var row in res) {
      print(row.join(" "));
    }
    print("----");
  }

  String genDisplayScore(int score) {
    var realScore = score * 0.987;
    if(realScore < 1000) {
      return realScore.toStringAsFixed(2);
    }
    if(realScore < 1000000) {
      return (realScore / 1000).toStringAsFixed(2) + "k";
    }
    if(realScore < 1000000000) {
      return (realScore / 1000000).toStringAsFixed(2) + "M";
    }
    return (realScore / 1000000000).toStringAsFixed(2) + "G";
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      actions: <Type, Action<Intent>> {
        KeyInputIntent: CallbackAction<KeyInputIntent>(
            onInvoke: (KeyInputIntent intent) {
              print(intent.type);
              switch(intent.type) {
                case KeyInputType.ARROW_UP:
                  onSwipe(SwipeDirection.up);
                  break;
                case KeyInputType.ARROW_DOWN:
                  onSwipe(SwipeDirection.down);
                  break;
                case KeyInputType.ARROW_LEFT:
                  onSwipe(SwipeDirection.left);
                  break;
                case KeyInputType.ARROW_RIGHT:
                  onSwipe(SwipeDirection.right);
                  break;
              }
              return null;
            }
        )
      },
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.arrowUp): KeyInputIntent.ARROW_UP(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): KeyInputIntent.ARROW_DOWN(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): KeyInputIntent.ARROW_LEFT(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): KeyInputIntent.ARROW_RIGHT(),
        LogicalKeySet(LogicalKeyboardKey.keyP): KeyInputIntent.ARROW_RIGHT(),
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 700),
              child: Column(
                children: [
                  //上のバー
                  Container(
                    height: 56,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(width: 32,),
                        Text("2 0 \n4 8 ", style: TextStyle(fontSize: 24, color: Colors.black87, height: 1),),
                        Expanded(child: Text("x.987", style: TextStyle(fontSize: 48, color: Colors.black26, height: 1),)),
                        Container(
                          margin: EdgeInsets.all(4),
                          width: 48,
                          child: Card(
                            color: Colors.green.shade800,
                            child: InkWell(
                              onTap: () {
                                menuVisible ? _menuController.reverse() : _menuController.forward();
                                setState(() { menuVisible = !menuVisible; });
                              },
                              child: Center(
                                  child: AnimatedIcon(
                                    icon: AnimatedIcons.close_menu,
                                    color: Colors.white,
                                    progress: Tween<double>(begin: 1.0, end: 0.0).animate(_menuController),
                                  )
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 4/5,
                        child: LayoutBuilder(
                          builder: (context, bConstraints) {
                            return Column(
                              children: [
                                //スコア表示する場所
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      height: bConstraints.biggest.width / 10,
                                      child: Card(
                                        color: Colors.green.shade800,
                                        child: InkWell(
                                          onTap: () {
                                            menuVisible ? _menuController.reverse() : _menuController.forward();
                                            setState(() { menuVisible = !menuVisible; });
                                          },
                                          child: Center(
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                              child: Text("MENU",
                                                style: TextStyle(color: Colors.white54, fontSize: bConstraints.biggest.width / 17),
                                              ),
                                            ),
                                          ),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8.0),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: bConstraints.biggest.width * 0.3,
                                      height: bConstraints.biggest.width / 10,
                                      child: Card(
                                        color: Colors.green,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                            child: Padding(
                                              padding: const EdgeInsets.only(right: 8.0),
                                              child: Text(genDisplayScore(score),
                                                style: TextStyle(color: Colors.white70, fontSize: bConstraints.biggest.width / 17),
                                              ),
                                            )
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8.0),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                //パズル領域
                                Expanded(
                                  child: Center(
                                    child: SimpleGestureDetector(
                                      onHorizontalSwipe: onSwipe,
                                      onVerticalSwipe: onSwipe,
                                      child: AspectRatio(
                                        aspectRatio: 1.0,
                                        child: Card(
                                          color: Colors.green.shade800.withAlpha(100),
                                          shadowColor: Colors.transparent,
                                          clipBehavior: Clip.antiAliasWithSaveLayer,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12.0),
                                          ),
                                          child: LayoutBuilder(
                                            builder: (context, constraint) {
                                              var width = constraint.biggest.width;
                                              var tileWidth = (width - 8) / 4;
                                              return Stack(
                                                children: [
                                                  Positioned.fill(
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(4.0),
                                                      child: ExpandedGrid(
                                                        column: xLength, row: yLength,
                                                        children: List.generate(xLength * yLength, (index) => ExpandedGridContent(
                                                          columnIndex: index % 4, rowIndex: (index / 4).floor(),
                                                          child: Container(
                                                            height: tileWidth - 4, width: tileWidth - 4,
                                                            margin: EdgeInsets.all(2.0),
                                                            child: Card(
                                                              shadowColor: Colors.transparent,
                                                              color: Colors.white38,
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(8.0),
                                                              ),
                                                              child: Container(),
                                                            ),
                                                          ),
                                                        )),
                                                      ),
                                                    ),
                                                  ),
                                                  Positioned.fill(
                                                    child: Focus(
                                                      autofocus: true,
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(4.0),
                                                        child: Stack(
                                                          children: tilesPool.map((e) => AnimatedPositioned(
                                                              duration: const Duration(milliseconds: 300),
                                                              key: e.key,
                                                              top: e.positionY * tileWidth, left: e.positionX * tileWidth,
                                                              child: Tile(data: e, tileWidth: tileWidth,))
                                                          ).toList(),
                                                          // children: tilesPool.map((e) => AnimatedPositioned(
                                                          //   duration: const Duration(milliseconds: 400),
                                                          //   key: e.key,
                                                          //   top: e.positionY * tileWidth, left: e.positionX * tileWidth,
                                                          //   //top: (e.key % 10) * tileWidth, left: (e.key / 10).floor() * tileWidth,
                                                          //   child: Container(
                                                          //     height: tileWidth - 4, width: tileWidth - 4,
                                                          //     margin: EdgeInsets.all(2.0),
                                                          //     child: Card(
                                                          //       color: valueColor(e.value),
                                                          //       shape: RoundedRectangleBorder(
                                                          //         borderRadius: BorderRadius.circular(8.0),
                                                          //       ),
                                                          //       child: Center(
                                                          //         child: Row(
                                                          //           children: [
                                                          //             const Expanded(child: SizedBox(),),
                                                          //             Text((e.value * 0.987).floor().toString(), style: TextStyle(fontSize: Math.min(tileWidth / (e.value * 0.987).floor().toString().length * 2 * 0.4, tileWidth * 0.35), color: Colors.white),),
                                                          //             Expanded(
                                                          //               child: Align(
                                                          //                 alignment: Alignment.centerLeft,
                                                          //                 child: Text(
                                                          //                   ((e.value * 0.987) - (e.value * 0.987).floor()).toString().substring(1),
                                                          //                   style: TextStyle(fontSize: Math.min(tileWidth / (e.value * 0.987).floor().toString().length * 2 * 0.2, tileWidth * 0.2), color: Colors.white54),
                                                          //                   overflow: TextOverflow.visible,
                                                          //                   maxLines: 1,
                                                          //                 ),
                                                          //               ),
                                                          //             )
                                                          //           ],
                                                          //         ),
                                                          //         //child: Text("${e.value}", style: TextStyle(fontSize: tileWidth * 0.5, color: Colors.white),),
                                                          //       ),
                                                          //     ),
                                                          //   ),
                                                          // )).toList()
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  if(clearVisible) Positioned.fill(
                                                    child: Container(
                                                      color: Colors.yellow.shade800.withAlpha(100),
                                                      child: Center(
                                                        child: Column(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Text("2021", style: TextStyle(color: Colors.orange.shade900, fontSize: tileWidth * 1.3, fontWeight: FontWeight.bold),),
                                                            Padding(
                                                              padding: EdgeInsets.symmetric(horizontal: tileWidth / 4, vertical: tileWidth / 10),
                                                              child: Text("あけましておめでとう！",
                                                                style: TextStyle(color: Colors.black45, fontSize: tileWidth / 5),
                                                                textAlign: TextAlign.center,
                                                              ),
                                                            ),
                                                            Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                IconButton(
                                                                  onPressed: () { restartGame(); },
                                                                  icon: Icon(Icons.refresh, size: tileWidth / 3, color: Colors.orange.shade900),
                                                                ),
                                                                InkWell(
                                                                  onTap: () { tweetScore(2021); },
                                                                  child: Container(
                                                                      width: tileWidth / 2,
                                                                      child: Image.asset("image/twitter.png", color: Colors.orange.shade900)
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            FlatButton(
                                                              onPressed: () {
                                                                setState(() {
                                                                  clearVisible = false;
                                                                });
                                                              },
                                                              child: Text("Continue", style: TextStyle(color: Colors.orange.shade900, fontSize: tileWidth / 5),),
                                                            )
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  if(failedVisible) Positioned.fill(
                                                    child: Container(
                                                      color: Colors.white70,
                                                      child: Center(
                                                        child: Column(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Text("${getMaxYear()}", style: TextStyle(color: Colors.black87, fontSize: tileWidth * 1.3, fontWeight: FontWeight.bold),),
                                                            Padding(
                                                              padding: EdgeInsets.symmetric(horizontal: tileWidth / 4, vertical: tileWidth / 10),
                                                              child: Text("${getMessage(getMaxYear())}",
                                                                style: TextStyle(color: Colors.black45, fontSize: tileWidth / 5),
                                                                textAlign: TextAlign.center,
                                                              ),
                                                            ),
                                                            Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                IconButton(
                                                                  onPressed: () { restartGame(); },
                                                                  icon: Icon(Icons.refresh, size: tileWidth / 3,),
                                                                ),
                                                                InkWell(
                                                                  onTap: () { tweetScore(getMaxYear()); },
                                                                  child: Container(
                                                                    width: tileWidth / 2,
                                                                      child: Image.asset("image/twitter.png", color: Colors.black)
                                                                  ),
                                                                ),
                                                              ],
                                                            )
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  PositionedTransition(
                                                    rect: RelativeRectTween(begin: RelativeRect.fromLTRB(width, 0, -width, 0), end: RelativeRect.fill)
                                                      .animate(CurvedAnimation(parent: _menuController, curve: Curves.easeOutBack)),
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.vertical(top: Radius.circular(8.0)),
                                                      child: Container(
                                                        color: Color(0xFF404040),
                                                        padding: EdgeInsets.all(4.0),
                                                        child: ExpandedGrid(
                                                          column: 4, row: 4,
                                                          children: [
                                                            menuTile(
                                                              cSpan: 2, rSpan: 2,
                                                              color: Colors.green,
                                                              child: Column(
                                                                children: [
                                                                  Padding(
                                                                    padding: const EdgeInsets.all(8.0),
                                                                    child: Text("High Score",
                                                                      style: TextStyle(color: Colors.black54, fontSize: tileWidth / 5),
                                                                    ),
                                                                  ),
                                                                  Expanded(
                                                                    child: Center(
                                                                      child: FutureBuilder(
                                                                        future: getHighScore(),
                                                                        initialData: 0,
                                                                        builder: (context, score) {
                                                                          return Text("${genDisplayScore(score.data)}",
                                                                            style: TextStyle(color: Colors.black, fontSize: tileWidth / 2, fontWeight: FontWeight.bold)
                                                                          );
                                                                        },
                                                                      ),
                                                                    ),
                                                                  )
                                                                ],
                                                              )
                                                            ),
                                                            menuTile(
                                                              cIndex: 2, rIndex: 0, cSpan: 2,
                                                              color: Colors.brown,
                                                              child: InkWell(
                                                                onTap: () { _menuController.reverse(); },
                                                                child: Center(
                                                                    child: Text("Back to Game",
                                                                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: tileWidth / 3),
                                                                    )
                                                                ),
                                                              ),
                                                            ),
                                                            menuTile(
                                                              cIndex: 2, rIndex: 1, cSpan: 2,
                                                              color: Colors.brown,
                                                              child: InkWell(
                                                                onTap: () {
                                                                  _menuController.reverse();
                                                                  restartGame();
                                                                },
                                                                child: Center(
                                                                    child: Text("New Game",
                                                                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: tileWidth / 2.5),
                                                                    )
                                                                ),
                                                              ),
                                                            ),
                                                            menuTile(
                                                              cIndex: 0, rIndex: 2,
                                                              color: Colors.grey,
                                                              child: InkWell(
                                                                onTap: () {
                                                                  showDialog(
                                                                    context: context,
                                                                    builder: (_) {
                                                                      return AlertDialog(
                                                                        content: Text("Swipe or Arrow Key"),
                                                                        actions: <Widget>[
                                                                          FlatButton(
                                                                            child: Text("I see"),
                                                                            onPressed: () => Navigator.pop(context),
                                                                          ),
                                                                        ],
                                                                      );
                                                                    },
                                                                  );
                                                                },
                                                                child: Center(child: Icon(Icons.help_outline, size: tileWidth / 2, color: Colors.white70,))
                                                              ),
                                                            ),
                                                            menuTile(
                                                              cIndex: 1, rIndex: 2, cSpan: 2,
                                                              color: Colors.blueGrey,
                                                              child: InkWell(
                                                                onTap: () {
                                                                  showLicensePage(
                                                                    context: context,
                                                                    applicationName: 'p987', // アプリの名前
                                                                    applicationVersion: '2.0.2.1', // バージョン
                                                                    applicationLegalese: '2020 fastriver_org', // 権利情報
                                                                  );
                                                                },
                                                                child: Center(
                                                                    child: Text(
                                                                        "Licenses",
                                                                      style: TextStyle(color: Colors.white12, fontSize: tileWidth / 2),
                                                                    )
                                                                ),
                                                              ),
                                                            ),
                                                            menuTile(
                                                              cIndex: 3, rIndex: 2,
                                                              color: Colors.yellowAccent,
                                                              child: InkWell(
                                                                onTap: () async { openUrl("https://year-greeting-condition2020.fastriver.dev/"); },
                                                                child: Container(
                                                                  color: Color(0xFFE5D8AB),
                                                                  child: Image.asset("image/cheese.png", fit: BoxFit.contain,),
                                                                )
                                                              ),
                                                            ),
                                                            menuTile(
                                                              cIndex: 0, rIndex: 3,
                                                              color: Color(0xFF1A91DA),
                                                              child: InkWell(
                                                                onTap: () async { openUrl("https://twitter.com/intent/tweet?text=%E5%B9%B4%E8%B3%80%E7%8A%B62021.987%0Ahttps%3A%2F%2Fp987.fastriver.dev%2F"); },
                                                                child: Center(child: Icon(Icons.share, size: tileWidth / 2, color: Colors.white70,))
                                                              ),
                                                            ),
                                                            menuTile(
                                                              cIndex: 1, rIndex: 3, cSpan: 2,
                                                              color: Color(0xFF60807F),
                                                              child: InkWell(
                                                                onTap: () async { openUrl("https://twitter.com/Fastriver_org"); },
                                                                child: Center(
                                                                    child: Column(
                                                                      crossAxisAlignment: CrossAxisAlignment.center,
                                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                                      children: [
                                                                        Text("from", style: TextStyle(color: Color(0xFF80C1E1)),),
                                                                        Text(
                                                                            "@fastriver_org",
                                                                          style: TextStyle(color: Color(0xFF80C1E1), fontSize: tileWidth / 3.5),
                                                                        ),
                                                                      ],
                                                                    )
                                                                ),
                                                              ),
                                                            ),
                                                            menuTile(
                                                              cIndex: 3, rIndex: 3,
                                                              color: Colors.yellow,
                                                              child: InkWell(
                                                                onTap: () async { openUrl("https://play2048.co/"); },
                                                                child: Image.asset("image/2048_logo.png", fit: BoxFit.cover,)
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    arrowButton(
                                        child: Icon(
                                          Icons.arrow_back,
                                          size: bConstraints.biggest.width / 10,
                                          color: Colors.white70,
                                        ),
                                        onTap: () { onSwipe(SwipeDirection.left); },
                                    ),
                                    arrowButton(
                                        child: Transform.rotate(
                                          angle: -90 * Math.pi / 180,
                                          child: Icon(
                                            Icons.arrow_forward,
                                            size: bConstraints.biggest.width / 10,
                                            color: Colors.white70,
                                          ),
                                        ),
                                        onTap: () { onSwipe(SwipeDirection.up); }
                                    ),
                                    arrowButton(
                                        child: Transform.rotate(
                                          angle: 90 * Math.pi / 180,
                                          child: Icon(
                                            Icons.arrow_forward,
                                            size: bConstraints.biggest.width / 10,
                                            color: Colors.white70,
                                          ),
                                        ),
                                        onTap: () { onSwipe(SwipeDirection.down); }
                                    ),
                                    arrowButton(
                                      child: Icon(
                                        Icons.arrow_forward,
                                        size: bConstraints.biggest.width / 10,
                                        color: Colors.white70,
                                      ),
                                      onTap: () { onSwipe(SwipeDirection.right); }
                                    ),
                                  ],
                                )
                              ],
                            );
                          }
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  int getMaxYear() {
    var maxYear = 0;
    for(var tile in tilesPool) {
      maxYear = Math.max(maxYear, (tile.value * 0.987).floor());
    }
    return maxYear;
  }

  String getMessage(int year) {
    if(year <= 1) return "Amanishakheto, queen of Kush (Nubia), dies.";
    if(year <= 3) return "King Yuri of Goguryeo moves the capital from Jolbon Fortress to Gungnae City.";
    if(year <= 7) return "Vonones I becomes ruler of the Parthian Empire.";
    if(year <= 15) return "In Rome, the election of magistrates passes from the people to the Emperor and the Senate.";
    if(year <= 31) return "Jesus is crucified.";
    if(year <= 63) return "Pompeii, the city at the foot of Mount Vesuvius, is heavily damaged by a strong earthquake.";
    if(year <= 126) return "First year of the Yongjian era of the Chinese Han Dynasty.";
    if(year <= 252) return "Pope Cornelius is exiled to Centumcellae, by Emperor Trebonianus Gallus.";
    if(year <= 505) return "The western Huns (Hephthalites) from the Caucasus invade the Persian Empire.";
    if(year <= 1010) return "Lady Murasaki writes The Tale of Genji in Japanese.";
    if(year <= 2021) return "now.";
    return "-----";
  }

  Future<int> getHighScore() async {
    var prefs = await SharedPreferences.getInstance();
    return prefs.getInt("HIGH") ?? 0;
  }

  void tweetScore(int year) async {
    var url = "https://twitter.com/intent/tweet?text=%E5%B9%B4%E8%B3%80%E7%8A%B62021.987%20-%20" + "$year" + "%E5%B9%B4%E3%81%BE%E3%81%A7%E5%88%B0%E9%81%94%0Ahttps%3A%2F%2Fp987.fastriver.dev%2F";
    openUrl(url);
  }

  void openUrl(String url) async {
    try {
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        throw 'Could not launch $url';
      }
    } catch(e) {
      print(e);
    }
  }

  Widget arrowButton({Widget child, Function onTap, double size}) {
    return Container(
      margin: EdgeInsets.all(4),
      width: size, height: size,
      child: Card(
        color: Colors.green.shade500,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: child,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    );
  }

  Widget menuTile({int cIndex = 0, int cSpan = 1, int rIndex = 0, int rSpan = 1, Color color, Widget child}) {
    return ExpandedGridContent(
      columnIndex: cIndex, rowIndex: rIndex,
      columnSpan: cSpan, rowSpan: rSpan,
      child: Container(
        margin: EdgeInsets.all(2),
        child: Card(
          color: color,
          child: child,
          shadowColor: Colors.transparent,
          clipBehavior: Clip.antiAliasWithSaveLayer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      ),
    );
  }

  Color valueColor(int value) {
    if(value <= 2) return Colors.brown.shade600;
    if(value <= 4) return Colors.brown.shade800;
    if(value <= 8) return Colors.orange;
    if(value <= 16) return Colors.deepOrange;
    if(value <= 32) return Colors.redAccent;
    if(value <= 64) return Colors.red;
    if(value <= 128) return Colors.green;
    if(value <= 256) return Colors.green.shade800;
    if(value <= 512) return Colors.blue;
    if(value <= 1024) return Colors.blueGrey;
    if(value <= 2048) return Colors.black87;
    else return Colors.deepPurpleAccent;
  }
}

enum Direction {
  TOP, BOTTOM, LEFT, RIGHT
}

class TileData {
  final UniqueKey key;
  int value;
  int positionX;
  int positionY;
  TileData(this.key, this.value);
}

class KeyInputIntent extends Intent {
  final KeyInputType type;
  const KeyInputIntent({@required this.type});
  const KeyInputIntent.ARROW_UP(): type = KeyInputType.ARROW_UP;
  const KeyInputIntent.ARROW_DOWN(): type = KeyInputType.ARROW_DOWN;
  const KeyInputIntent.ARROW_LEFT(): type = KeyInputType.ARROW_LEFT;
  const KeyInputIntent.ARROW_RIGHT(): type = KeyInputType.ARROW_RIGHT;
}

enum KeyInputType { ARROW_UP, ARROW_DOWN, ARROW_LEFT, ARROW_RIGHT }

class Tile extends StatefulWidget {
  TileData data;
  double tileWidth;
  Tile({Key key, this.data, this.tileWidth}): super(key: key);
  @override
  State<StatefulWidget> createState() => TileState();
}

class TileState extends State<Tile> with TickerProviderStateMixin {
  AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _controller.drive(CurveTween(curve: Curves.easeInOutQuint)),
      child: FadeTransition(
        opacity: _controller.drive(CurveTween(curve: Curves.easeInOutQuint)),
        child: Container(
          height: widget.tileWidth - 4, width: widget.tileWidth - 4,
          margin: EdgeInsets.all(2.0),
          child: Card(
            color: valueColor(widget.data.value),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Center(
              child: Row(
                children: [
                  const Expanded(child: SizedBox(),),
                  Text((widget.data.value * 0.987).floor().toString(), style: TextStyle(fontSize: Math.min(widget.tileWidth / (widget.data.value * 0.987).floor().toString().length * 2 * 0.4, widget.tileWidth * 0.35), color: Colors.white),),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        ((widget.data.value * 0.987) - (widget.data.value * 0.987).floor()).toString().substring(1),
                        style: TextStyle(fontSize: Math.min(widget.tileWidth / (widget.data.value * 0.987).floor().toString().length * 2 * 0.2, widget.tileWidth * 0.2), color: Colors.white54),
                        overflow: TextOverflow.visible,
                        maxLines: 1,
                      ),
                    ),
                  )
                ],
              ),
              //child: Text("${e.value}", style: TextStyle(fontSize: tileWidth * 0.5, color: Colors.white),),
            ),
          ),
        ),
      ),
    );
  }

  Color valueColor(int value) {
    if(value <= 2) return Colors.brown.shade600;
    if(value <= 4) return Colors.brown.shade800;
    if(value <= 8) return Colors.orange;
    if(value <= 16) return Colors.deepOrange;
    if(value <= 32) return Colors.redAccent;
    if(value <= 64) return Colors.red;
    if(value <= 128) return Colors.green;
    if(value <= 256) return Colors.green.shade800;
    if(value <= 512) return Colors.blue;
    if(value <= 1024) return Colors.blueGrey;
    if(value <= 2048) return Colors.black87;
    else return Colors.deepPurpleAccent;
  }
}
