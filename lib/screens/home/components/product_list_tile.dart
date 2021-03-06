import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:price_tracker/models/product.dart';
import 'package:price_tracker/services/product_utils.dart';
import 'package:price_tracker/screens/product_detail/product_detail.dart';
import 'package:share/share.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timeago/timeago.dart' as timeago;

class ProductListTile extends StatelessWidget {
  final Product product;
  final Function onDelete;

  ProductListTile({this.product, this.onDelete});

  @override
  Widget build(BuildContext context) {
    bool _underTarget = product.underTarget();
    bool _availableAgain = product.availableAgain();
    bool _priceFall = product.priceFall();
    bool _priceIncrease = product.priceIncrease() && !_availableAgain;
    // bool _showTargetPrice = product.targetPrice > 0;
    double _priceDiffPercentage = product.percentageToYesterday();
    bool _priceChanged = _priceFall || _priceIncrease;

    Color _chosenColor = _priceFall || _availableAgain
        ? Colors.green[800]
        : _priceIncrease ? Colors.red[900] : Colors.transparent;

    Color _titleColor = refreshing
        ? Colors.grey
        : product.parseSuccess ? Colors.white : Colors.red;

    Color _storeColor = _underTarget ? Colors.black87 : Colors.grey;

    void _onTap() {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => ProductDetail(
                product: product,
              )));
    }

    void _onLongPress() async {
      if (await canLaunch(product.productUrl)) {
        await launch(product.productUrl);
      } else {
        throw "Could not launch URL";
      }
    }

    Widget _getLeadingImage() {
      Widget image = Icon(Icons.error);
      if (product.imageUrl != null) {
        try {
          image = CachedNetworkImage(
              imageUrl: product.imageUrl,
              placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(
                    valueColor:
                        new AlwaysStoppedAnimation<Color>(Colors.black87),
                  )),
              errorWidget: (context, url, error) => Icon(Icons.error));
        } catch (e) {
          image = Icon(Icons.error);
        }
      }
      return image;
    }

    Widget _buildLeadingImage() {
      return Container(
        //Image Placeholder
        color: Colors.white,
        width: 80,
        height: 60,
        child: Hero(tag: product.imageUrl, child: _getLeadingImage()),
      );
    }

    Widget _buildTrailing() {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
              //Change Placeholder?
              width: 100,
              height: 40,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  RichText(
                    text: TextSpan(
                      children: <TextSpan>[
                        //if prices changed add new line to show price difference %
                        //otherwise only show current price
                        TextSpan(
                            text: product.prices[product.prices.length - 1] >=
                                        0 &&
                                    _priceChanged
                                ? product.prices[product.prices.length - 1]
                                        .toString() +
                                    "\n"
                                : product.prices[product.prices.length - 1] >= 0
                                    ? product.prices[product.prices.length - 1]
                                        .toString()
                                    : "--\n",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.white)),
                        TextSpan(
                          text: _priceIncrease
                              ? "+" + _priceDiffPercentage.toString() + "%"
                              : _priceFall
                                  ? _priceDiffPercentage.toString() + "%"
                                  : "",
                          style: TextStyle(
                            color: _chosenColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              )),
          Visibility(visible: !product.parseSuccess, child: Spacer()),
          Visibility(
            visible: !product.parseSuccess,
            child: Container(
              child: Text(
                "Last Sync: ${timeago.format(product.dates[product.dates.length - 1], locale: 'en_short')}",
                style: TextStyle(fontSize: 10),
                maxLines: 2,
              ),
            ),
          )
        ],
      );
    }

    return Slidable(
      actionPane: SlidableDrawerActionPane(),
      actionExtentRatio: 0.25,
      child: Container(
        color: _underTarget ? Colors.green[800] : Colors.transparent,
        child: ListTile(
          title: Text(
            product.getShortName(),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _titleColor),
            maxLines: 2,
          ),
          subtitle: Text(
            product.getDomain(),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _storeColor),
          ),
          leading: _buildLeadingImage(),
          trailing: _buildTrailing(),
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          onTap: refreshing ? null : _onTap,
          onLongPress: refreshing ? null : _onLongPress,
        ),
      ),
      actions: <Widget>[
        IconSlideAction(
          caption: 'Share',
          color: Colors.blue,
          icon: Icons.share,
          onTap: () => Share.share(product.productUrl),
        ),
      ],
      secondaryActions: <Widget>[
        IconSlideAction(
            caption: 'Delete',
            color: Colors.red,
            icon: Icons.delete,
            onTap: onDelete),
      ],
    );
  }
}
