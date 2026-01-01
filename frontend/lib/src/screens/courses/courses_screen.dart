import 'package:flutter/material.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppColors.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppSpacing.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppTypography.dart';
import 'package:dhiraj_ayu_academy/src/constants/AppConstants.dart';
import 'package:dhiraj_ayu_academy/src/widgets/cards.dart';
import 'package:dhiraj_ayu_academy/src/widgets/inputs.dart';
import 'package:dhiraj_ayu_academy/src/widgets/common_widgets.dart';
import 'package:dhiraj_ayu_academy/src/services/api_service.dart';
import 'package:dhiraj_ayu_academy/src/screens/courses/course_detail_screen.dart';

/// Courses Screen
/// Browse all available courses with filters and search
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();

  String _selectedCategory = AppConstants.courseCategories[0];
  String _selectedSort = AppConstants.courseSortOptions[0];

  String _selectedSortKey = 'most_recent';

  final Map<String, String> _sortMap = {
    'Most Recent': 'most_recent',
    'Most Popular': 'most_popular',
    'Price: Low to High': 'price_asc',
    'Price: High to Low': 'price_desc',
    'A-Z': 'a_z',
    'Z-A': 'z_a',
  };
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;

  final List<Map<String, dynamic>> _courses = [];
  int _currentPage = 1;
  bool _hasMore = true;

  // Server-side filter: null = all, true = paid only, false = free only
  bool? _filterIsPaid;

  @override
  void initState() {
    super.initState();
    _loadCourses();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadMoreCourses();
      }
    }
  }

  Future<void> _loadCourses({
    bool showGlobalLoading = true,
    bool? filterIsPaid,
  }) async {
    if (showGlobalLoading) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _hasMore = true;
        _courses.clear();
      });
    } else {
      // For pull-to-refresh: keep current list visible until new data arrives
      setState(() {
        _isRefreshing = true;
        _currentPage = 1;
        _hasMore = true;
      });
    }

    try {
      final effectiveFilter = filterIsPaid ?? _filterIsPaid;
      final params = {
        'page': _currentPage,
        'pageSize': AppConstants.coursesPerPage,
        if (effectiveFilter != null) 'is_paid': effectiveFilter.toString(),
        'sort': _selectedSortKey,
      };

      final response = await _apiService.get(
        'courses/get-all-courses',
        queryParameters: params,
      );
      final data = response.data as Map<String, dynamic>;
      final List<dynamic> newCourses = data['data'] ?? [];
      final newList = newCourses.cast<Map<String, dynamic>>();

      if (showGlobalLoading) {
        setState(() {
          _courses.clear();
          _courses.addAll(newList);
          _hasMore = _courses.length < (data['total'] ?? 0);
          _isLoading = false;
        });
      } else {
        // Replace the list atomically on refresh, then clear refreshing flag
        setState(() {
          _courses.clear();
          _courses.addAll(newList);
          _hasMore = _courses.length < (data['total'] ?? 0);
          _isRefreshing = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _hasMore = false;
      });
    }
  }

  Future<void> _loadMoreCourses() async {
    if (!_hasMore || _isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
    });
    try {
      final nextPage = _currentPage + 1;
      final params = {
        'page': nextPage,
        'pageSize': AppConstants.coursesPerPage,
        if (_filterIsPaid != null) 'is_paid': _filterIsPaid.toString(),
        'sort': _selectedSortKey,
      };

      final response = await _apiService.get(
        'courses/get-all-courses',
        queryParameters: params,
      );
      final data = response.data as Map<String, dynamic>;
      final List<dynamic> newCourses = data['data'] ?? [];
      final newList = newCourses.cast<Map<String, dynamic>>();
      setState(() {
        _currentPage = nextPage;
        _courses.addAll(newList);
        _hasMore = _courses.length < (data['total'] ?? 0);
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
        _hasMore = false;
      });
    }
  }

  void _onCategorySelected(String category) {
    // Map UI category selection to server-side is_paid filter
    bool? selected;
    if (category == AppConstants.courseCategories[0]) {
      // 'All Courses'
      selected = null;
    } else if (category == AppConstants.courseCategories[2]) {
      // 'Paid'
      selected = true;
    } else if (category == AppConstants.courseCategories[1]) {
      // 'Free'
      selected = false;
    }

    setState(() {
      _selectedCategory = category;
      _filterIsPaid = selected;
      _currentPage = 1;
      _courses.clear();
    });

    _loadCourses(filterIsPaid: selected);
  }

  void _onSearchChanged(String query) {
    // TODO: Implement fuzzy search
    // Debounce search
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.6;
        return Container(
          height: maxHeight,
          decoration: const BoxDecoration(
            color: AppColors.backgroundWhite,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusLG),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: AppSpacing.screenPaddingHorizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sort By', style: AppTypography.headlineSmall),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Column(
                    children: AppConstants.courseSortOptions.map((option) {
                      return ListTile(
                        title: Text(option, style: AppTypography.bodyMedium),
                        trailing: _selectedSort == option
                            ? const Icon(
                                Icons.check,
                                color: AppColors.primaryGreen,
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedSort = option;
                            _selectedSortKey =
                                _sortMap[option] ?? 'most_recent';
                          });
                          Navigator.pop(context);
                          _loadCourses();
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: RefreshIndicator(
        onRefresh: () => _loadCourses(showGlobalLoading: false),
        color: AppColors.primaryGreen,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // App Bar
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: AppColors.backgroundWhite,
              elevation: 0,
              title: const Text('All Courses'),
            ),

            // Search and Filters
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.md),
                  Padding(
                    padding: AppSpacing.screenPaddingHorizontal,
                    child: Row(
                      children: [
                        Expanded(
                          child: SearchField(
                            hint: 'Search courses...',
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        IconButton(
                          onPressed: _showSortOptions,
                          icon: const Icon(Icons.sort),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.backgroundWhite,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppSpacing.borderRadiusMD,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Category Chips
                  ChipSelector(
                    options: AppConstants.courseCategories,
                    selectedOption: _selectedCategory,
                    onSelected: _onCategorySelected,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),

            // Thin refresh indicator shown during pull-to-refresh (keeps list visible)
            if (_isRefreshing)
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: 3,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    minHeight: 3,
                  ),
                ),
              ),

            // Course List
            if (_isLoading)
              const SliverFillRemaining(child: LoadingIndicator())
            else if (_courses.isEmpty)
              const SliverFillRemaining(
                child: EmptyState(
                  icon: Icons.search_off,
                  title: 'No courses found',
                  subtitle: 'Try adjusting your search or filters',
                ),
              )
            else
              SliverPadding(
                padding: AppSpacing.screenPaddingHorizontal,
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index == _courses.length) {
                      return _isLoadingMore
                          ? const Padding(
                              padding: EdgeInsets.all(AppSpacing.md),
                              child: LoadingIndicator(size: 30),
                            )
                          : const SizedBox.shrink();
                    }

                    final course = _courses[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: CourseCard(
                        title: course['title'] ?? '',
                        description: course['description'] ?? '',
                        thumbnailUrl: course['thumbnail_url'],
                        isPaid: course['is_paid'] ?? false,
                        price: course['price'] != null
                            ? (course['price'] as num).toInt()
                            : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CourseDetailScreen(
                                courseId: course['id'],
                                courseDetails: course,
                              ), // Pass course details
                            ),
                          );
                        },
                      ),
                    );
                  }, childCount: _courses.length + (_isLoadingMore ? 1 : 0)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
