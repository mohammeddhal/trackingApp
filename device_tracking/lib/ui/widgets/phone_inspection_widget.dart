import 'dart:convert';
import 'package:flutter/material.dart';

enum DamageType {
  scratch('خدش (Scratch)', Colors.amber, Icons.linear_scale),
  dent('ضربة / انبعاج (Dent)', Colors.deepOrange, Icons.radio_button_checked),
  crack('كسر / شرخ (Crack)', Colors.red, Icons.broken_image),
  discoloration('تقشر بوية / أثر (Scuff)', Colors.purple, Icons.blur_on);

  final String label;
  final Color color;
  final IconData icon;
  const DamageType(this.label, this.color, this.icon);
}

class DamageMark {
  final String view; // 'front', 'back', 'sides'
  final Offset relativePos; // (0.0 - 1.0, 0.0 - 1.0)
  final DamageType type;
  final String? note;

  DamageMark({
    required this.view,
    required this.relativePos,
    required this.type,
    this.note,
  });

  Map<String, dynamic> toMap() => {
    'view': view,
    'dx': relativePos.dx,
    'dy': relativePos.dy,
    'type': type.name,
    'note': note,
  };

  factory DamageMark.fromMap(Map<String, dynamic> map) {
    return DamageMark(
      view: map['view'] ?? 'front',
      relativePos: Offset(
        (map['dx'] as num?)?.toDouble() ?? 0.5,
        (map['dy'] as num?)?.toDouble() ?? 0.5,
      ),
      type: DamageType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => DamageType.scratch,
      ),
      note: map['note'],
    );
  }
}

class PhoneInspectionDialog extends StatefulWidget {
  final String? initialData;
  final String? initialConditionText;

  const PhoneInspectionDialog({
    super.key,
    this.initialData,
    this.initialConditionText,
  });

  @override
  State<PhoneInspectionDialog> createState() => _PhoneInspectionDialogState();
}

class _PhoneInspectionDialogState extends State<PhoneInspectionDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<DamageMark> _marks = [];
  DamageType _selectedType = DamageType.scratch;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.initialData != null && widget.initialData!.isNotEmpty) {
      try {
        final decoded = jsonDecode(widget.initialData!) as List;
        for (final item in decoded) {
          _marks.add(DamageMark.fromMap(Map<String, dynamic>.from(item)));
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _addMark(String view, Offset relativePos) {
    setState(() {
      _marks.add(DamageMark(
        view: view,
        relativePos: relativePos,
        type: _selectedType,
      ));
    });
  }

  void _undo() {
    if (_marks.isNotEmpty) {
      setState(() {
        _marks.removeLast();
      });
    }
  }

  void _clearAll() {
    setState(() {
      _marks.clear();
    });
  }

  String _generateSummaryText() {
    if (_marks.isEmpty) {
      return widget.initialConditionText?.isNotEmpty == true
          ? widget.initialConditionText!
          : 'جهاز سليم بدون خدوش ظاهرة';
    }

    final counts = <String, int>{};
    for (final mark in _marks) {
      String viewLabel = mark.view == 'front'
          ? 'الشاشة'
          : mark.view == 'back'
              ? 'الظهر'
              : 'الحواف/الإطار';
      String key = '${mark.type.label} في $viewLabel';
      counts[key] = (counts[key] ?? 0) + 1;
    }

    final summaryParts = counts.entries.map((e) => '${e.value} ${e.key}').toList();
    return 'مخطط الفحص: ${summaryParts.join('، ')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.88,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.smartphone, color: Colors.indigo, size: 28),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'فحص حالة الجوال والخدوش بصرياً',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),

            // Damage Type Selector
            Row(
              children: [
                const Text('نوع الضرر: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 4),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: DamageType.values.map((type) {
                        final isSelected = _selectedType == type;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            avatar: Icon(type.icon, size: 16, color: isSelected ? Colors.white : type.color),
                            label: Text(
                              type.label,
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: type.color,
                            onSelected: (_) => setState(() => _selectedType = type),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Tab Bar for Phone Views
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.indigo,
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black87,
                tabs: const [
                  Tab(icon: Icon(Icons.phone_android, size: 18), text: 'الشاشة الأمامية'),
                  Tab(icon: Icon(Icons.camera_alt, size: 18), text: 'الجهة الخلفية'),
                  Tab(icon: Icon(Icons.view_column, size: 18), text: 'الجوانب والحواف'),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Interactive Drawing / Point Placing Canvas
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildPhoneView(viewKey: 'front', title: 'اضغط على الشاشة لوضع علامة الخدش/الضربة'),
                  _buildPhoneView(viewKey: 'back', title: 'اضغط على خلفية الهاتف لوضع علامة'),
                  _buildPhoneView(viewKey: 'sides', title: 'اضغط على الحواف أو الإطار لوضع علامة'),
                ],
              ),
            ),

            // Toolbar for Undo / Clear / Marks Count
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text(
                    'النقاط المحددة: ${_marks.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _marks.isNotEmpty ? _undo : null,
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('تراجع', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton.icon(
                    onPressed: _marks.isNotEmpty ? _clearAll : null,
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                    label: const Text('مسح الكل', style: TextStyle(fontSize: 12, color: Colors.red)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Generated Summary Preview
            Text(
              _generateSummaryText(),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Save Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                    onPressed: () {
                      final summaryText = _generateSummaryText();
                      final serializedMarks = jsonEncode(_marks.map((m) => m.toMap()).toList());
                      Navigator.pop(context, {
                        'summary': summaryText,
                        'data': serializedMarks,
                      });
                    },
                    child: const Text('اعتماد وحفظ الحالة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneView({required String viewKey, required String title}) {
    final viewMarks = _marks.where((m) => m.view == viewKey).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ),
        Expanded(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double phoneHeight = constraints.maxHeight * 0.92;
                final double phoneWidth = viewKey == 'sides'
                    ? (phoneHeight * 0.75).clamp(180.0, 320.0)
                    : (phoneHeight * 0.52).clamp(140.0, 240.0);

                return GestureDetector(
                  onTapUp: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box == null) return;
                    final local = details.localPosition;
                    // Clamp inside phone boundary
                    final dx = (local.dx / phoneWidth).clamp(0.0, 1.0);
                    final dy = (local.dy / phoneHeight).clamp(0.0, 1.0);
                    _addMark(viewKey, Offset(dx, dy));
                  },
                  child: Container(
                    width: phoneWidth,
                    height: phoneHeight,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.blueGrey.shade300, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Phone schematic vector background
                        CustomPaint(
                          size: Size(phoneWidth, phoneHeight),
                          painter: PhoneSchematicPainter(view: viewKey),
                        ),

                        // Damage Marks
                        ...viewMarks.map((mark) {
                          return Positioned(
                            left: (mark.relativePos.dx * phoneWidth) - 12,
                            top: (mark.relativePos.dy * phoneHeight) - 12,
                            child: Tooltip(
                              message: mark.type.label,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: mark.type.color.withOpacity(0.85),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                                  ],
                                ),
                                child: Icon(mark.type.icon, size: 12, color: Colors.white),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class PhoneSchematicPainter extends CustomPainter {
  final String view; // 'front', 'back', 'sides'

  PhoneSchematicPainter({required this.view});

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = Colors.blueGrey.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final fillPaint = Paint()
      ..color = Colors.blueGrey.shade100.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final accentPaint = Paint()
      ..color = Colors.blueGrey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    if (view == 'front') {
      // Front Screen Outline
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 8, size.width - 16, size.height - 16),
        const Radius.circular(20),
      );
      canvas.drawRRect(rect, fillPaint);
      canvas.drawRRect(rect, borderPaint);

      // Dynamic Island / Top Speaker Notch
      final notchPaint = Paint()..color = Colors.black87..style = PaintingStyle.fill;
      final notchRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(size.width / 2, 22), width: size.width * 0.35, height: 12),
        const Radius.circular(6),
      );
      canvas.drawRRect(notchRect, notchPaint);

      // Home Indicator Line
      final homePaint = Paint()..color = Colors.black54..style = PaintingStyle.fill;
      final homeRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(size.width / 2, size.height - 20), width: size.width * 0.4, height: 4),
        const Radius.circular(2),
      );
      canvas.drawRRect(homeRect, homePaint);

      // Subtle Screen grid lines
      accentPaint.color = Colors.blueGrey.shade200.withOpacity(0.5);
      canvas.drawLine(Offset(size.width / 2, 35), Offset(size.width / 2, size.height - 30), accentPaint);
      canvas.drawLine(Offset(15, size.height / 2), Offset(size.width - 15, size.height / 2), accentPaint);
    } else if (view == 'back') {
      // Back panel outline
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 8, size.width - 16, size.height - 16),
        const Radius.circular(20),
      );
      canvas.drawRRect(rect, fillPaint);
      canvas.drawRRect(rect, borderPaint);

      // Camera Module Box (Top Left)
      final camBoxPaint = Paint()..color = Colors.blueGrey.shade200..style = PaintingStyle.fill;
      final camBoxRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(18, 18, size.width * 0.45, size.height * 0.22),
        const Radius.circular(14),
      );
      canvas.drawRRect(camBoxRect, camBoxPaint);
      canvas.drawRRect(camBoxRect, accentPaint);

      // Camera Lenses
      final lensPaint = Paint()..color = Colors.black87..style = PaintingStyle.fill;
      final lensCenter1 = Offset(camBoxRect.left + camBoxRect.width * 0.35, camBoxRect.top + camBoxRect.height * 0.3);
      final lensCenter2 = Offset(camBoxRect.left + camBoxRect.width * 0.35, camBoxRect.top + camBoxRect.height * 0.7);
      final lensCenter3 = Offset(camBoxRect.left + camBoxRect.width * 0.75, camBoxRect.top + camBoxRect.height * 0.5);

      canvas.drawCircle(lensCenter1, 10, lensPaint);
      canvas.drawCircle(lensCenter2, 10, lensPaint);
      canvas.drawCircle(lensCenter3, 8, lensPaint);

      // Center Logo Icon Area
      final logoPaint = Paint()..color = Colors.blueGrey.shade300..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(size.width / 2, size.height * 0.52), 16, logoPaint);
    } else if (view == 'sides') {
      // Draw 3 vertical strips: Left Frame, Right Frame, Top/Bottom Frame
      final colWidth = (size.width - 24) / 3;

      for (int i = 0; i < 3; i++) {
        final left = 8 + i * (colWidth + 4);
        final sideRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(left, 10, colWidth, size.height - 20),
          const Radius.circular(12),
        );
        canvas.drawRRect(sideRect, fillPaint);
        canvas.drawRRect(sideRect, borderPaint);

        // Labels for side strips
        final labelText = i == 0 ? 'الجانب الأيمن' : (i == 1 ? 'الجانب الأيسر' : 'أعلى وأسفل');
        final textPainter = TextPainter(
          text: TextSpan(
            text: labelText,
            style: TextStyle(color: Colors.blueGrey.shade800, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.rtl,
        )..layout(maxWidth: colWidth);
        textPainter.paint(canvas, Offset(left + (colWidth - textPainter.width) / 2, 16));

        // Buttons simulation
        if (i == 0) {
          // Power Button
          final btnPaint = Paint()..color = Colors.blueGrey.shade700..style = PaintingStyle.fill;
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(left + colWidth - 4, size.height * 0.3, 4, 30), const Radius.circular(2)),
            btnPaint,
          );
        } else if (i == 1) {
          // Volume buttons
          final btnPaint = Paint()..color = Colors.blueGrey.shade700..style = PaintingStyle.fill;
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(left, size.height * 0.25, 4, 25), const Radius.circular(2)),
            btnPaint,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(left, size.height * 0.35, 4, 25), const Radius.circular(2)),
            btnPaint,
          );
        } else if (i == 2) {
          // Charging port & speaker holes
          final portPaint = Paint()..color = Colors.black87..style = PaintingStyle.fill;
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(left + colWidth / 2, size.height - 35), width: colWidth * 0.6, height: 8), const Radius.circular(4)),
            portPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant PhoneSchematicPainter oldDelegate) => oldDelegate.view != view;
}
