import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:dhiraj_ayu_academy/src/services/api_service.dart';

typedef PaymentSuccessCallback =
    void Function(Map<String, dynamic> verifyResult);
typedef PaymentErrorCallback = void Function(String message);

class PaymentService {
  final ApiService _apiService;
  late final Razorpay _razorpay;

  PaymentService(this._apiService) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _internalSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _internalError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _internalExternal);
  }

  PaymentSuccessCallback? _onSuccess;
  PaymentErrorCallback? _onError;
  void Function(String walletName)? _onExternal;

  // track which course the current payment is init for
  String? _currentCourseId;

  Future<void> startPayment({
    required String courseId,
    required String name,
    String? email,
    String? contact,
    required PaymentSuccessCallback onSuccess,
    required PaymentErrorCallback onError,
    void Function(String walletName)? onExternal,
  }) async {
    _onSuccess = onSuccess;
    _onError = onError;
    _onExternal = onExternal;
    _currentCourseId = courseId;
    try {
      // Request backend to create order (server validates amount)
      final resp = await _apiService.post(
        'courses/buy-course',
        data: {'courseId': courseId},
      );

      final order = resp.data['order'] as Map<String, dynamic>;
      final key = resp.data['key'];

      final razorpayOrderId = order['razorpay_order_id'] ?? order['order_id'];
      final amount = order['amount']; // paise
      final currency = order['currency'] ?? 'INR';

      if (razorpayOrderId == null || amount == null) {
        throw Exception(
          'Incomplete order info from server (order_id/amount required)',
        );
      }

      final options = {
        'key': key,
        'order_id': razorpayOrderId,
        'amount': amount,
        'currency': currency,
        'name': name,
        'description': 'Course purchase',
        'prefill': {
          if (email != null) 'email': email,
          if (contact != null) 'contact': contact,
        },
      };

      _razorpay.open(options);
    } catch (e) {
      onError('Error initiating payment: ${e.toString()}');
      rethrow;
    }
  }

  void _internalSuccess(PaymentSuccessResponse response) async {
    try {
      // Verify with backend
      final verifyResp = await _apiService.post(
        'courses/verify-payment',
        data: {
          'order_id': response.orderId,
          'payment_id': response.paymentId,
          'signature': response.signature,
          'courseId': _currentCourseId,
        },
      );

      // Pass backend verification result to callback
      if (_onSuccess != null) {
        _onSuccess!(verifyResp.data as Map<String, dynamic>);
      }
    } catch (e) {
      if (_onError != null) {
        _onError!('Error verifying payment: ${e.toString()}');
      }
    }
  }

  void _internalError(PaymentFailureResponse response) {
    if (_onError != null) _onError!("Payment failed");
  }

  void _internalExternal(ExternalWalletResponse response) {
    if (_onExternal != null) _onExternal!(response.walletName ?? '');
  }

  void dispose() {
    _razorpay.clear();
  }
}
