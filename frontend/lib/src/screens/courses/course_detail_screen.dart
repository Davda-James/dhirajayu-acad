import 'package:flutter/material.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppColors.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppSpacing.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppTypography.dart';
import 'package:dhiraj_ayu_academy/src/services/api_service.dart';
import 'package:dhiraj_ayu_academy/src/services/payment_service.dart';

class CourseDetailScreen extends StatefulWidget {
  final String courseId;
  final Map<String, dynamic> courseDetails; // Add courseDetails field

  const CourseDetailScreen({
    super.key,
    required this.courseId,
    required this.courseDetails, // Initialize courseDetails
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final ApiService _apiService = ApiService();
  bool _isEnrolled = false;
  bool _isProcessingPayment = false;

  late final PaymentService _paymentService;

  @override
  void initState() {
    super.initState();
    _checkEnrollment(); // Only check enrollment
    _paymentService = PaymentService(ApiService());
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  Future<void> _checkEnrollment() async {
    try {
      final enrollmentResponse = await _apiService.get(
        'courses/check_enrollment/${widget.courseId}',
      );
      setState(() {
        _isEnrolled = enrollmentResponse.data['enrolled'];
      });
    } catch (e) {}
  }

  // Payment callbacks handled via PaymentService callbacks
  void _onPaymentSuccess(Map<String, dynamic> verifyResult) {
    setState(() {
      _isProcessingPayment = false;
      _isEnrolled = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment verified and enrolled')),
    );
  }

  void _onPaymentError(String message) {
    setState(() {
      _isProcessingPayment = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onExternalWallet(String walletName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External wallet selected: $walletName')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.courseDetails; // Use passed course details

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Course Details', style: AppTypography.titleLarge),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: Column(
        children: [
          // Scrollable content (image included)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail now scrolls with content
                  if (course['thumbnail_url'] != null)
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        course['thumbnail_url'],
                        fit: BoxFit.cover,
                      ),
                    ),

                  const SizedBox(height: AppSpacing.md),

                  Text(course['title'], style: AppTypography.headlineMedium),
                  const SizedBox(height: AppSpacing.sm),

                  // Prominent price (extra large)
                  Text(
                    course['price'] != null
                        ? '₹ ${(course['price'] as num).toInt()}'
                        : 'FREE',
                    style: AppTypography.displaySmall.copyWith(
                      color: course['price'] != null
                          ? AppColors.primaryGreen
                          : AppColors.success,
                      fontWeight: AppTypography.extraBold,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  Text(course['description'], style: AppTypography.bodyMedium),
                ],
              ),
            ),
          ),

          // Buy Button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            color: AppColors.backgroundWhite,
            child: ElevatedButton(
              onPressed: _isEnrolled || _isProcessingPayment
                  ? null
                  : () => _startPayment(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isEnrolled
                    ? AppColors.textSecondary.withValues(alpha: 0.5)
                    : AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              ),
              child: _isProcessingPayment
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnPrimary,
                      ),
                    )
                  : Text(
                      _isEnrolled ? 'Already Enrolled' : 'Buy Now',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.backgroundWhite,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startPayment() async {
    final course = widget.courseDetails;
    if (course['price'] == null) return;
    try {
      setState(() {
        _isProcessingPayment = true;
      });
      // Use the PaymentService to start the flow and let it handle order creation and verification
      _paymentService
          .startPayment(
            courseId: widget.courseId,
            name: course['title'] ?? 'Course',
            email: '',
            contact: '',
            onSuccess: _onPaymentSuccess,
            onError: _onPaymentError,
            onExternal: _onExternalWallet,
          )
          .whenComplete(() {
            if (mounted) setState(() => _isProcessingPayment = false);
          });
    } catch (e) {
      setState(() {
        _isProcessingPayment = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error initiating payment')));
    }
  }
}
