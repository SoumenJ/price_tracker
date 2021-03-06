import 'dart:io';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_clipboard_manager/flutter_clipboard_manager.dart';
import 'package:price_tracker/models/product.dart';
import 'package:price_tracker/screens/home/home.dart';
import 'package:price_tracker/services/database.dart';
import 'package:price_tracker/services/notifications.dart';
import 'package:price_tracker/services/product_utils.dart';
import 'package:price_tracker/services/scraper.dart';
import 'package:price_tracker/services/share_intent.dart';
import 'package:simple_search_bar/simple_search_bar.dart';
import 'package:toast/toast.dart';

class HomeScreenController extends State<HomeScreen> {
  ScrollController listviewController;
  final AppBarController appBarController = AppBarController();

  bool loading = false;
  bool searching = false;

  String refreshingText = "Refreshing Prices";
  List<Product> _products = <Product>[];
  List<Product> _filteredProducts = <Product>[];
  bool iConnectivity = true;
  int productCount;

  List<Product> get products => searching ? _filteredProducts : _products;

  String get productsCountString => products.length > 1 || products.length == 0
      ? productCount.toString() + " products"
      : "1 product";

  @override
  void initState() {
    listviewController = ScrollController();
    init();
    super.initState();
  }

  void init() async {
    await _loadProducts();
    await checkInternet();
    await _checkForNotificationTap();

    if (iConnectivity) await _checkForSharedText();

    appBarController.stream.stream.listen((searching) {
      this.searching = searching;
    });
  }

  @override
  void dispose() {
    listviewController.dispose();
    super.dispose();
  }

  _checkForSharedText() async {
    String input = ShareIntentService.sharedText;
    if (input != null) {
      ShareIntentService.sharedText = null;
      await addProduct(input);
    }
  }

  _checkForNotificationTap() async {
    String payload = NotificationService.currentPayload;
    if (payload != null) {
      notificationTapCallback(payload);
    }
  }

  Future<bool> checkInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(Duration(seconds: 5), onTimeout: () {
        debugPrint("Internet Timout!");
        iConnectivity = false;
        return null;
      });

      if (result != null &&
          result.isNotEmpty &&
          result[0].rawAddress.isNotEmpty) {
        // print('connected to internet');
        setState(() {
          iConnectivity = true;
        });
      }
    } on SocketException catch (_) {
      print('NOT connected to internet');
      setState(() {
        iConnectivity = false;
      });
      Toast.show('Please ensure an internet connection', context,
          duration: 3, gravity: Toast.BOTTOM);
    }
    return iConnectivity;
  }

  Future<void> _loadProducts() async {
    loading = true;

    final _db = await DatabaseService.getInstance();

    await _db.getAllProducts().then((value) {
      _products = value.reversed.toList();
      _filteredProducts = _products;
      loading = false;
      refreshing = false;
      productCount = _filteredProducts.length;
    });
    setState(() {});
  }

  void addProductDialogue() async {
    if (!await checkInternet()) return;
    String input = await FlutterClipboardManager.copyFromClipBoard();
    bool validURL = ScraperService.validUrl(input);

    List<String> inputs = (await showTextInputDialog(
      context: context,
      textFields: [
        DialogTextField(
            initialText: validURL ? input : "",
            hintText: !validURL ? "Paste from Clipboard" : "")
      ],
      title: "Add new Product",
      message: "Paste Link to Product. \n\n" +
          (!validURL
              ? "No valid Product Link or unsupported Store Link found in the Clipboard!"
              : "Valid Link pasted from the Clipboard!"),
      style: AdaptiveStyle.material,
    ));
    input = inputs != null ? inputs[0] : inputs;

    await addProduct(input);
  }

  Future<void> addProduct(String input) async {
    if (input != null && ScraperService.validUrl(input)) {
      await scrollToTop();
      loading = true;
      setState(() {});
      // Toast.show("Product details are being parsed", context,
      //     duration: Toast.LENGTH_LONG, gravity: Toast.BOTTOM);
      Product p = Product(input);
      if (await p.init()) {
        final _db = await DatabaseService.getInstance();
        int newId = await _db.insert(p);
        //Check for insert error
        if (newId == -1)
          Toast.show("Product already exists!", context,
              duration: 4, gravity: Toast.BOTTOM);
      } else {
        Toast.show("Invalid URL or unsupported store", context,
            duration: 4, gravity: Toast.BOTTOM);
        // await FlutterClipboardManager.copyToClipBoard("");
      }

      _loadProducts();
    } else {
      if (input != null)
        Toast.show("Invalid URL or unsupported store", context,
            duration: 4, gravity: Toast.BOTTOM);
    }
  }

  Future<bool> deleteDialogue(Product product) async {
    OkCancelResult result = await showOkCancelAlertDialog(
      context: context,
      title: "Do you really want to delete the following product?",
      message: product.getShortName(),
      okLabel: "Delete",
      barrierDismissible: true,
      isDestructiveAction: true,
    );
    return result == OkCancelResult.ok;
  }

  void deleteProduct(Product product) async {
    if (await deleteDialogue(product)) {
      final _db = await DatabaseService.getInstance();

      await _db.delete(product.id);
      debugPrint('Deleted Product ${product.name}');

      _loadProducts();
    }
  }

  void onRefresh() async {
    if (await checkInternet() && !refreshing) {
      refreshing = true;
      await scrollToTop();
      setState(() {});
      await updatePrices(() => setState(() {}));
      await _loadProducts();
      int failedCount = await countFailedParsing();
      if (failedCount > 0)
        Toast.show(
            "$failedCount Products failed to parse, please try again", context,
            duration: 10, gravity: Toast.BOTTOM);
    }
  }

  Future<void> scrollToTop() async {
    listviewController.animateTo(listviewController.position.minScrollExtent,
        curve: Curves.easeInOut, duration: Duration(milliseconds: 1000));
  }

  onSearch() {
    //This is where You change to SEARCH MODE. To hide, just
    //add FALSE as value on the stream
    setState(() {
      appBarController.state = true;
    });
    appBarController.stream.add(true);
  }

  search(String s) {
    _filteredProducts = filterProducts(_products, s).toList();
    setState(() {
      productCount = _filteredProducts.length;
    });
  }

  @override
  Widget build(BuildContext context) => HomeScreenView(this);
}
