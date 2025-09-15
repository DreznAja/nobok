import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/filter_model.dart';

class FilterChipWidget extends StatelessWidget {
  final ConversationFilter filter;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const FilterChipWidget({
    Key? key,
    required this.filter,
    required this.onTap,
    this.onClear,
  }) : super(key: key);

  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color textSecondary = Color(0xFF757575);
  static const Color backgroundColor = Color(0xFFF5F5F5);

  @override
  Widget build(BuildContext context) {
    if (!filter.hasActiveFilters) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primaryBlue.withOpacity(0.3)),
              ),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(20),
                child: Row(
                  children: [
                    Icon(
                      Icons.filter_alt,
                      size: 16,
                      color: primaryBlue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${filter.activeFilterCount} filter${filter.activeFilterCount > 1 ? 's' : ''} active',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: primaryBlue,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onClear != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onClear,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: primaryBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}