import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // Product IDs must match what's registered in Google Play Console
  static const String product500Credits = 'credits_500_pack';
  static const String product1000Credits = 'credits_1000_pack';

  void initialize() {
    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      print("Purchase Error: $error");
    });
  }

  Future<void> buyCredits(String productId) async {
    final bool available = await _iap.isAvailable();
    if (!available) throw "Store not available";

    const Set<String> _kIds = {product500Credits, product1000Credits};
    final ProductDetailsResponse response =
        await _iap.queryProductDetails(_kIds);

    if (response.notFoundIDs.contains(productId)) {
      throw "Product not found in Google Play Console. Please check Product ID: $productId";
    }

    final ProductDetails productDetails =
        response.productDetails.firstWhere((p) => p.id == productId);
    final PurchaseParam purchaseParam =
        PurchaseParam(productDetails: productDetails);

    await _iap.buyConsumable(purchaseParam: purchaseParam);
  }

  void _listenToPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          print("Purchase Error: ${purchaseDetails.error}");
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          bool delivered = await _deliverProduct(purchaseDetails);
          if (delivered) {
            await _iap.completePurchase(purchaseDetails);
          }
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<bool> _deliverProduct(PurchaseDetails purchaseDetails) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    int creditsToAdd = 0;
    if (purchaseDetails.productID == product500Credits) {
      creditsToAdd = 500;
    } else if (purchaseDetails.productID == product1000Credits) {
      creditsToAdd = 1000;
    }

    if (creditsToAdd > 0) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'credits': FieldValue.increment(creditsToAdd),
          'lastPurchaseDate': FieldValue.serverTimestamp(),
          'lastTransactionId': purchaseDetails.purchaseID,
        }, SetOptions(merge: true));
        return true;
      } catch (e) {
        print("Error delivering credits: $e");
        return false;
      }
    }
    return false;
  }

  void dispose() {
    _subscription.cancel();
  }
}
