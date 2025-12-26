import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/AppColors.dart';
import '../constants/AppSpacing.dart';
import '../constants/AppTypography.dart';

/// Text Input Field Widget
/// Consistent text input styling
class AppTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final int? maxLength;
  final bool enabled;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;

  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.textInputAction,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      maxLength: maxLength,
      enabled: enabled,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      style: AppTypography.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

/// Password Input Field Widget
/// Text field with show/hide password toggle
class PasswordTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const PasswordTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.validator,
    this.onChanged,
  });

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label ?? 'Password',
      hint: widget.hint,
      controller: widget.controller,
      validator: widget.validator,
      onChanged: widget.onChanged,
      obscureText: _obscureText,
      keyboardType: TextInputType.visiblePassword,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        icon: Icon(
          _obscureText
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      ),
    );
  }
}

/// Search Field Widget
/// Input field styled for search functionality
class SearchField extends StatelessWidget {
  final String? hint;
  final TextEditingController? controller;
  final void Function(String)? onChanged;
  final VoidCallback? onClear;
  final VoidCallback? onSubmit;

  const SearchField({
    super.key,
    this.hint,
    this.controller,
    this.onChanged,
    this.onClear,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: AppSpacing.borderRadiusMD,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmit != null ? (_) => onSubmit!() : null,
        style: AppTypography.bodyMedium,
        decoration: InputDecoration(
          hintText: hint ?? 'Search...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller?.text.isNotEmpty ?? false
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller?.clear();
                    onClear?.call();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
        ),
      ),
    );
  }
}

/// Dropdown Field Widget
/// Styled dropdown selector
class AppDropdown<T> extends StatelessWidget {
  final String? label;
  final String? hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)? onChanged;
  final String? Function(T?)? validator;

  const AppDropdown({
    super.key,
    this.label,
    this.hint,
    this.value,
    required this.items,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(labelText: label, hintText: hint),
      style: AppTypography.bodyMedium,
      dropdownColor: AppColors.backgroundWhite,
      borderRadius: AppSpacing.borderRadiusMD,
    );
  }
}

/// Chip Selector Widget
/// Horizontal scrollable chip selector
class ChipSelector extends StatelessWidget {
  final List<String> options;
  final String? selectedOption;
  final void Function(String) onSelected;

  const ChipSelector({
    super.key,
    required this.options,
    this.selectedOption,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.screenPaddingHorizontal,
        itemCount: options.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final option = options[index];
          final isSelected = option == selectedOption;

          return FilterChip(
            label: Text(option),
            selected: isSelected,
            onSelected: (_) => onSelected(option),
            backgroundColor: AppColors.backgroundWhite,
            selectedColor: AppColors.primaryGreenLight,
            labelStyle: AppTypography.labelMedium.copyWith(
              color: isSelected
                  ? AppColors.textOnPrimary
                  : AppColors.textPrimary,
            ),
            side: BorderSide(
              color: isSelected
                  ? AppColors.primaryGreen
                  : AppColors.borderLight,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
          );
        },
      ),
    );
  }
}
