import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/routes/register_route_model.dart';
import '../../providers/routes/register_route_provider.dart';

// ─── Màu sắc dùng chung ─────────────────────────────────────────────────────
const _kPopupBg = Color(0xFF0D3D22);
const _kPopupBgSoft = Color(0xFF164D2E);
const _kPopupBgItem = Color(0xFF1A5C36);
const _kGold = Color(0xFFFBBF24);
const _kGoldLight = Color(0xFFFDE68A);
const _kGreen100 = Color(0xFFD1FAE5);
const _kGreen700 = Color(0xFF065F46);
const _kGreen400 = Color(0xFF34D399);
const _kWhite = Colors.white;

class RegisterRoutePopup extends StatefulWidget {
  const RegisterRoutePopup({super.key});

  @override
  State<RegisterRoutePopup> createState() => _RegisterRoutePopupState();
}

class _RegisterRoutePopupState extends State<RegisterRoutePopup>
    with TickerProviderStateMixin {
  bool _initialized = false;

  // Search + picker sheet
  final _searchController = TextEditingController();
  bool _showPicker = false;
  String _searchText = '';

  late AnimationController _pickerAnim;
  late Animation<double> _pickerFade;
  late Animation<Offset> _pickerSlide;

  @override
  void initState() {
    super.initState();
    _pickerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _pickerFade = CurvedAnimation(parent: _pickerAnim, curve: Curves.easeOut);
    _pickerSlide = Tween<Offset>(
      begin: const Offset(0, -0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _pickerAnim, curve: Curves.easeOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _loadData();
  }

  @override
  void dispose() {
    _pickerAnim.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString("accessToken") ?? "";
    if (accessToken.isEmpty || !mounted) return;
    await context.read<RegisterRouteProvider>().initRegisterRoute(accessToken);
  }

  Future<void> _submit() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString("accessToken") ?? "";

    if (accessToken.isEmpty) {
      _showSnack('Không tìm thấy access token');
      return;
    }

    final provider = context.read<RegisterRouteProvider>();
    if (provider.selectedProvinceIds.isEmpty) {
      _showSnack('Vui lòng chọn ít nhất 1 tỉnh');
      return;
    }

    final ok = await provider.updateRoutes(accessToken: accessToken);
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      _showSnack(provider.errorMessage ?? 'Đăng ký tuyến thất bại');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1F2937),
      ),
    );
  }

  void _openPicker() {
    setState(() {
      _showPicker = true;
      _searchText = '';
      _searchController.clear();
    });
    _pickerAnim.forward(from: 0);
  }

  void _closePicker() {
    _pickerAnim.reverse().then((_) {
      if (mounted) setState(() => _showPicker = false);
    });
  }

  void _selectProvince(int provinceId, RegisterRouteProvider provider) {
    provider.toggleProvince(provinceId);
    if (provider.selectedProvinceIds.length >= provider.maxProvinceCount) {
      _closePicker();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RegisterRouteProvider>();
    final selectedIds = provider.selectedProvinceIds;
    final routeOptions = provider.routeOptions;
    final isLoading = provider.isLoading;
    final isSubmitting = provider.isSubmitting;
    final maxCount = provider.maxProvinceCount;

    final selectedOptions =
    routeOptions.where((e) => selectedIds.contains(e.provinceId)).toList();
    final availableOptions =
    routeOptions.where((e) => !selectedIds.contains(e.provinceId)).toList();
    final filteredAvailable = _searchText.isEmpty
        ? availableOptions
        : availableOptions
        .where((e) => e.provinceName
        .toLowerCase()
        .contains(_searchText.toLowerCase()))
        .toList();

    final bool canAddMore = selectedIds.length < maxCount;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Main container ─────────────────────────────────────────────
          Container(
            constraints: const BoxConstraints(maxHeight: 680),
            decoration: BoxDecoration(
              color: _kPopupBg,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──────────────────────────────────────────────
                _buildHeader(selectedIds, maxCount),

                

                // ── Body scrollable ─────────────────────────────────────
                Flexible(
                  child: isLoading
                      ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(color: _kGold),
                    ),
                  )
                      : routeOptions.isEmpty
                      ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        'Không có dữ liệu tỉnh',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  )
                      : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Trigger button ─────────────────
                        _buildPickerTrigger(
                            canAddMore, maxCount, provider),

                        // ── Inline picker panel ────────────
                        if (_showPicker)
                          _buildInlinePicker(
                              filteredAvailable, provider),

                        const SizedBox(height: 20),

                        // ── Selected chips ─────────────────
                        if (selectedOptions.isNotEmpty) ...[
                          _buildSectionLabel('Tỉnh đã chọn'),
                          const SizedBox(height: 10),
                          _buildSelectedChips(
                              selectedOptions, provider),
                          const SizedBox(height: 20),

                          // ── Route preview ──────────────
                          _buildSectionLabel('Tuyến sẽ được tạo'),
                          const SizedBox(height: 10),
                          ...selectedOptions
                              .map((e) => _RoutePreviewCard(item: e)),
                        ] else ...[
                          _buildSectionLabel('Tỉnh đã chọn'),
                          const SizedBox(height: 10),
                          _buildEmptyChips(),
                        ],

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // ── Footer actions ─────────────────────────────────────
                _buildFooter(provider, isSubmitting, selectedIds),
              ],
            ),
          ),

          // ── Submitting overlay ─────────────────────────────────────────
          if (isSubmitting)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: _kGold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────
  Widget _buildHeader(List<int> selectedIds, int maxCount) {
    final filled = selectedIds.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white10, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Đăng ký tuyến hoạt động',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _kWhite,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tạo tuyến 2 chiều Hà Nội ↔ Tỉnh',
                  style: TextStyle(
                    fontSize: 13,
                    color: _kGreen100.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Slot indicator
          _SlotIndicator(filled: filled, max: maxCount),
        ],
      ),
    );
  }



  // ─── Picker trigger button ───────────────────────────────────────────────
  Widget _buildPickerTrigger(
      bool canAddMore, int maxCount, RegisterRouteProvider provider) {
    final isOpen = _showPicker;
    return GestureDetector(
      onTap: canAddMore
          ? () {
        if (isOpen) {
          _closePicker();
        } else {
          _openPicker();
        }
      }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isOpen ? _kPopupBgItem : _kPopupBgSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOpen ? _kGold : Colors.white24,
            width: isOpen ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.add_location_alt_outlined,
              color: canAddMore ? _kGold : Colors.white30,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                canAddMore
                    ? (isOpen ? 'Đang chọn tỉnh...' : 'Thêm tỉnh hoạt động')
                    : 'Đã chọn tối đa $maxCount tỉnh',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: canAddMore ? _kWhite : Colors.white38,
                ),
              ),
            ),
            if (canAddMore)
              AnimatedRotation(
                turns: isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 220),
                child: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.white54, size: 22),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Inline picker panel ────────────────────────────────────────────────
  Widget _buildInlinePicker(
      List<RouteOptionModel> options, RegisterRouteProvider provider) {
    return FadeTransition(
      opacity: _pickerFade,
      child: SlideTransition(
        position: _pickerSlide,
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: _kPopupBgSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search box
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(
                    color: _kWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  onChanged: (v) => setState(() => _searchText = v),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm tỉnh...',
                    hintStyle: const TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Colors.white38, size: 20),
                    suffixIcon: _searchText.isNotEmpty
                        ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _searchText = '');
                      },
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white38, size: 18),
                    )
                        : null,
                    filled: true,
                    fillColor: _kPopupBg,
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              // Divider
              const Divider(height: 1, color: Colors.white10),
              // List
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: options.isEmpty
                    ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'Không tìm thấy tỉnh phù hợp',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
                    : ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: options.length,
                  separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Colors.white10),
                  itemBuilder: (context, index) {
                    final item = options[index];
                    return _ProvinceListTile(
                      item: item,
                      onTap: () =>
                          _selectProvince(item.provinceId, provider),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Section label ───────────────────────────────────────────────────────
  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: _kGreen100,
        letterSpacing: 0.5,
      ),
    );
  }

  // ─── Selected chips ──────────────────────────────────────────────────────
  Widget _buildSelectedChips(
      List<RouteOptionModel> options, RegisterRouteProvider provider) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((item) {
        return _SelectedProvinceChip(
          item: item,
          onRemove: () => provider.toggleProvince(item.provinceId),
        );
      }).toList(),
    );
  }

  // ─── Empty chips ─────────────────────────────────────────────────────────
  Widget _buildEmptyChips() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _kPopupBgSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(Icons.location_off_outlined,
              color: Colors.white24, size: 18),
          const SizedBox(width: 8),
          const Text(
            'Bạn chưa chọn tỉnh nào',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white30,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Footer ──────────────────────────────────────────────────────────────
  Widget _buildFooter(RegisterRouteProvider provider, bool isSubmitting,
      List<int> selectedIds) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          // Clear button
          OutlinedButton.icon(
            onPressed: isSubmitting || selectedIds.isEmpty
                ? null
                : provider.clearSelectedProvinces,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Xóa chọn'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(120, 52),
              side: BorderSide(
                color: selectedIds.isEmpty ? Colors.white12 : Colors.white38,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              foregroundColor:
              selectedIds.isEmpty ? Colors.white24 : Colors.white,
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Submit button
          Expanded(
            child: ElevatedButton(
              onPressed: isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: _kGold,
                foregroundColor: const Color(0xFF1F2937),
                disabledBackgroundColor: _kGold.withOpacity(0.4),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Color(0xFF1F2937),
                  strokeWidth: 2.5,
                ),
              )
                  : const Text('Xác nhận đăng ký'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Slot Indicator widget ────────────────────────────────────────────────────
class _SlotIndicator extends StatelessWidget {
  final int filled;
  final int max;
  const _SlotIndicator({required this.filled, required this.max});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(max, (i) {
            final active = i < filled;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              margin: const EdgeInsets.only(left: 5),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? _kGold : Colors.white.withOpacity(0.15),
                boxShadow: active
                    ? [
                  BoxShadow(
                    color: _kGold.withOpacity(0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  )
                ]
                    : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          '$filled/$max tỉnh',
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white38,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Province list tile ───────────────────────────────────────────────────────
class _ProvinceListTile extends StatelessWidget {
  final RouteOptionModel item;
  final VoidCallback onTap;
  const _ProvinceListTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _kPopupBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.location_city_outlined,
                color: _kGold,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.provinceName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kWhite,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'HN ↔ ${item.provinceName}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white38,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.add_circle_outline_rounded,
                color: _kGold, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Selected Province Chip ───────────────────────────────────────────────────
class _SelectedProvinceChip extends StatelessWidget {
  final RouteOptionModel item;
  final VoidCallback onRemove;
  const _SelectedProvinceChip({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.only(left: 12, right: 6, top: 7, bottom: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kGreen400),
        boxShadow: [
          BoxShadow(
            color: _kGreen400.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded,
              color: _kGreen700, size: 15),
          const SizedBox(width: 6),
          Text(
            item.provinceName,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: _kGreen700,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 16, color: _kGreen700),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Route Preview Card ───────────────────────────────────────────────────────
class _RoutePreviewCard extends StatelessWidget {
  final RouteOptionModel item;
  const _RoutePreviewCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kPopupBgSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGold.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left accent bar
          Container(
            width: 3,
            height: 54,
            decoration: BoxDecoration(
              color: _kGold,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.provinceName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _kGoldLight,
                  ),
                ),
                const SizedBox(height: 6),
                _RouteRow(label: item.fromHaNoiRouteName),
                const SizedBox(height: 4),
                _RouteRow(label: item.toHaNoiRouteName),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final String label;
  const _RouteRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.route_outlined, color: _kGreen100, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _kGreen100,
            ),
          ),
        ),
      ],
    );
  }
}
