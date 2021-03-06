import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mvp/classes/storage_sharedPrefs.dart';
import 'package:mvp/classes/crud_firestore.dart';
import 'package:mvp/models/storeProducts.dart';

class CartModel extends ChangeNotifier {
  List<StoreProduct> _cartItems = [];

  UnmodifiableListView<StoreProduct> get items =>
      UnmodifiableListView(_cartItems);

  int get listLength => _cartItems.length;
  FirestoreCRUD f = new FirestoreCRUD();

  // check for items in firestore
  _checkFireStore() async {
    List<DocumentSnapshot> docs;
    QuerySnapshot q;
    StorageSharedPrefs p = new StorageSharedPrefs();
    String id = await p.getId();
    q = await Firestore.instance.collection('$id').getDocuments();
    docs = q.documents;
    return docs;
  }

  void firstTimeAddition() async {
    if (_cartItems.length == 0) {
      var docs = await _checkFireStore();
      if (docs.length > 0) {
        docs.forEach((d) {
          StoreProduct ob = new StoreProduct();
          Quantity q = new Quantity();
          ob.name = d.data['name'];
          ob.price = d.data['productPrice'];
          ob.uniqueId = d.data['uniqueId'];
          ob.id = d.data['id'];
          ob.type = d.data['type'];
          q.quantityValue = d.data['quantityValue'];
          q.quantityMetric = d.data['quantityMetric'];
          ob.totalPrice = d.data['userPrice'];
          ob.totalQuantity = d.data['userQuantity'];
          ob.pictureUrl = d.data['pictureURL'];
          ob.description = d.data['description'];
          ob.quantity = q;
          _cartItems.add(ob);
        });
        notifyListeners();
      }
    }
  }

  void checkCartItemsMatch() async {
    var docs = await _checkFireStore();
    if (docs.length == 0 && _cartItems.length > 0) {
      _cartItems.clear();
      notifyListeners();
    }
  }

  // Add item to cart
  void addItem(StoreProduct i) {
    // check if it exists already, then don't add
    bool matched = false;
    if (_cartItems.length > 0) {
      _cartItems.forEach((element) {
        if (element.uniqueId == i.uniqueId) {
          matched = true;
          return;
        }
      });
    }

    if (matched == false) {
      i.totalQuantity = 1;
      i.totalPrice = i.price;
      _cartItems.add(i);
      f.addToFirestore(i);
      notifyListeners();
    }
  }

  // Remove from cart
  void removeItem(StoreProduct i) {
    int index = -1;
    _cartItems.forEach((element) {
      if (element.uniqueId == i.uniqueId) {
        index = _cartItems.indexOf(element);
        return;
      }
    });
    if (index != -1) {
      String uid = _cartItems[index].uniqueId;
      _cartItems.removeAt(index);
      f.deleteFromFirestore(uid);
      notifyListeners();
    }
  }

  // update quantity by 1 for an item
  void updateQtyByOne(StoreProduct i) {
    bool matched = false;
    _cartItems.forEach((item) {
      if (item.uniqueId == i.uniqueId) {
        matched = true;
        item.totalQuantity = item.totalQuantity + 1;
        item.totalPrice = item.totalPrice + item.price;
        f.updateDocInFirestore(
            'p-${item.uniqueId}', item.totalQuantity, item.totalPrice);
        notifyListeners();
        return;
      }
    });

    if (matched == false) {
      addItem(i);
      notifyListeners();
    }
  }

  // update quantity by -1 for an item
  void minusQtyByOne(StoreProduct i) {
    bool remove = false;
    StoreProduct toRemove;
    _cartItems.forEach((item) {
      if (item.uniqueId == i.uniqueId) {
        if (item.totalQuantity != 0) {
          item.totalQuantity = item.totalQuantity - 1;
          item.totalPrice = item.totalPrice - item.price;
          if (item.totalQuantity != 0) {
            f.updateDocInFirestore(
                'p-${item.uniqueId}', item.totalQuantity, item.totalPrice);
            notifyListeners();
          } else if (item.totalQuantity == 0) {
            remove = true;
            toRemove = item;
          }
          return;
        }
      }
    });
    if (remove == true) {
      removeItem(toRemove);
      notifyListeners();
    }
  }

  // removing duplicates
  removeDuplicates() {
    // _cartItems.toSet().toList();
    StoreProduct selected;
    int itemIndex;
    if (_cartItems.length >= 2) {
      selected = _cartItems[0];
      _cartItems.asMap().forEach((index, e) {
        if (index > 0) {
          if (e.uniqueId == selected.uniqueId) {
            // remove item
            itemIndex = _cartItems.indexOf(e);
            // break loop
            return;
          }
          return;
        }
      });
    }
    if (itemIndex != null) {
      _cartItems.removeAt(itemIndex);
    }
  }

  // calculate total Price
  calTotalPrice() {
    var sum = 0;
    if (_cartItems.length > 0) {
      _cartItems.forEach((i) {
        sum = sum + i.totalPrice;
      });
    }
    return sum;
  }

  // remove all items from cart
  clearCart() {
    if (_cartItems.length > 0) {
      _cartItems.clear();
      f.deleteDocuments();
      notifyListeners();
    }
  }

  // clear Cart don't notify
  clearCartWithoutNotify() {
    if (_cartItems.length > 0) {
      _cartItems.clear();
      f.deleteDocuments();
    }
  }
}
