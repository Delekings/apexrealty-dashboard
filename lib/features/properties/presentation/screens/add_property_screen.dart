// // lib/features/properties/presentation/screens/new_property_screen.dart
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:go_router/go_router.dart';
// import 'package:intl/intl.dart';
//
// import '../../../../core/theme/app_theme.dart';
// import '../../../../core/utils/formatters.dart';
// import '../../../auth/providers/auth_providers.dart';
// import '../../providers/properties_providers.dart';
//
// const _nigerianStates = [
//   'Abia', 'Adamawa', 'Akwa Ibom', 'Anambra', 'Bauchi', 'Bayelsa', 'Benue',
//   'Borno', 'Cross River', 'Delta', 'Ebonyi', 'Edo', 'Ekiti', 'Enugu', 'FCT',
//   'Gombe', 'Imo', 'Jigawa', 'Kaduna', 'Kano', 'Katsina', 'Kebbi', 'Kogi',
//   'Kwara', 'Lagos', 'Nasarawa', 'Niger', 'Ogun', 'Ondo', 'Osun', 'Oyo',
//   'Plateau', 'Rivers', 'Sokoto', 'Taraba', 'Yobe', 'Zamfara',
// ];
//
// /// A single editable unit type row in the form.
// class _UnitTypeDraft {
//   final String key;
//   final TextEditingController title;
//   final TextEditingController size;
//   final TextEditingController price;
//   final TextEditingController count;
//   final TextEditingController description;
//
//   _UnitTypeDraft({String? presetTitle})
//       : key = UniqueKey().toString(),
//         title = TextEditingController(text: presetTitle ?? ''),
//         size = TextEditingController(),
//         price = TextEditingController(),
//         count = TextEditingController(text: '1'),
//         description = TextEditingController();
//
//   void dispose() {
//     title.dispose();
//     size.dispose();
//     price.dispose();
//     count.dispose();
//     description.dispose();
//   }
//
//   bool get isValid {
//     if (title.text.trim().isEmpty) return false;
//     final p = num.tryParse(price.text.replaceAll(',', ''));
//     if (p == null || p <= 0) return false;
//     final c = int.tryParse(count.text);
//     if (c == null || c < 1) return false;
//     return true;
//   }
// }
//
// class NewPropertyScreen extends ConsumerStatefulWidget {
//   const NewPropertyScreen({super.key});
//
//   @override
//   ConsumerState<NewPropertyScreen> createState() => _NewPropertyScreenState();
// }
//
// class _NewPropertyScreenState extends ConsumerState<NewPropertyScreen> {
//   final _title = TextEditingController();
//   final _location = TextEditingController();
//   final _lga = TextEditingController();
//   final _description = TextEditingController();
//   String? _state;
//
//   final List<_UnitTypeDraft> _units = [
//     _UnitTypeDraft(presetTitle: 'Standard plot'),
//   ];
//
//   bool _submitting = false;
//   String? _error;
//
//   @override
//   void dispose() {
//     _title.dispose();
//     _location.dispose();
//     _lga.dispose();
//     _description.dispose();
//     for (final u in _units) {
//       u.dispose();
//     }
//     super.dispose();
//   }
//
//   bool get _isValid {
//     if (_title.text.trim().isEmpty) return false;
//     if (_state == null) return false;
//     if (_location.text.trim().isEmpty) return false;
//     if (_units.isEmpty) return false;
//     return _units.every((u) => u.isValid);
//   }
//
//   Future<void> _submit() async {
//     final profile = ref.read(currentProfileProvider).value;
//     if (profile?.agencyId == null) {
//       setState(() => _error = 'No agency on your profile');
//       return;
//     }
//
//     setState(() {
//       _submitting = true;
//       _error = null;
//     });
//
//     try {
//       final unitsPayload = _units.map((u) {
//         return (
//         title: u.title.text.trim(),
//         description: u.description.text.trim().isEmpty
//             ? null
//             : u.description.text.trim(),
//         sizeSqm: num.tryParse(u.size.text.replaceAll(',', '')),
//         basePriceNgn: num.parse(u.price.text.replaceAll(',', '')),
//         totalUnits: int.parse(u.count.text),
//         );
//       }).toList();
//
//       final propertyId =
//       await ref.read(propertiesRepoProvider).createPropertyWithUnits(
//         agencyId: profile!.agencyId!,
//         title: _title.text.trim(),
//         state: _state!,
//         lga: _lga.text.trim().isEmpty ? null : _lga.text.trim(),
//         location: _location.text.trim(),
//         description: _description.text.trim().isEmpty
//             ? null
//             : _description.text.trim(),
//         unitTypes: unitsPayload,
//       );
//
//       ref.invalidate(propertiesProvider);
//       if (mounted) {
//         context.go('/properties/$propertyId');
//       }
//     } catch (e) {
//       setState(() =>
//       _error = e.toString().replaceFirst('Exception: ', ''));
//     } finally {
//       if (mounted) setState(() => _submitting = false);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(20),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Header
//           Row(
//             children: [
//               IconButton(
//                 icon: const Icon(Icons.arrow_back, size: 20),
//                 onPressed: () => context.go('/properties'),
//               ),
//               const SizedBox(width: 4),
//               const Text('Add new property',
//                   style: TextStyle(
//                       fontSize: 18, fontWeight: FontWeight.w600)),
//             ],
//           ),
//           const SizedBox(height: 16),
//           Expanded(
//             child: SingleChildScrollView(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   // ----- Property details card -----
//                   _card(
//                     title: 'Property details',
//                     children: [
//                       _label('Property name *'),
//                       TextField(
//                         controller: _title,
//                         onChanged: (_) => setState(() {}),
//                         decoration: const InputDecoration(
//                           hintText: 'e.g. New Touch Estate',
//                           isDense: true,
//                         ),
//                       ),
//                       const SizedBox(height: 12),
//                       Row(
//                         children: [
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment:
//                               CrossAxisAlignment.start,
//                               children: [
//                                 _label('State *'),
//                                 DropdownButtonFormField<String>(
//                                   value: _state,
//                                   isDense: true,
//                                   decoration: const InputDecoration(
//                                       isDense: true),
//                                   items: [
//                                     for (final s in _nigerianStates)
//                                       DropdownMenuItem(
//                                         value: s,
//                                         child: Text(s,
//                                             style: const TextStyle(
//                                                 fontSize: 13)),
//                                       ),
//                                   ],
//                                   onChanged: (v) =>
//                                       setState(() => _state = v),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           const SizedBox(width: 12),
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment:
//                               CrossAxisAlignment.start,
//                               children: [
//                                 _label('LGA'),
//                                 TextField(
//                                   controller: _lga,
//                                   decoration: const InputDecoration(
//                                       hintText: 'e.g. Ojo',
//                                       isDense: true),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 12),
//                       _label('Address / location *'),
//                       TextField(
//                         controller: _location,
//                         onChanged: (_) => setState(() {}),
//                         decoration: const InputDecoration(
//                           hintText:
//                           'e.g. Off Volkswagen Bus Stop, Lagos-Badagry Expressway',
//                           isDense: true,
//                         ),
//                       ),
//                       const SizedBox(height: 12),
//                       _label('Description'),
//                       TextField(
//                         controller: _description,
//                         maxLines: 3,
//                         decoration: const InputDecoration(
//                           hintText:
//                           'Brief description of the estate (optional)',
//                           isDense: true,
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 16),
//
//                   // ----- Unit types card -----
//                   _card(
//                     title: 'Unit types',
//                     trailing: OutlinedButton.icon(
//                       onPressed: () {
//                         setState(() => _units.add(_UnitTypeDraft()));
//                       },
//                       icon: const Icon(Icons.add, size: 14),
//                       label: const Text('Add unit type'),
//                     ),
//                     subtitle:
//                     'Each unit type is a plot size + price + count. '
//                         'Example: 30 plots of 300sqm at ₦5,000,000 each.',
//                     children: [
//                       for (var i = 0; i < _units.length; i++) ...[
//                         if (i > 0) const SizedBox(height: 12),
//                         _UnitTypeRow(
//                           index: i,
//                           draft: _units[i],
//                           canRemove: _units.length > 1,
//                           onChanged: () => setState(() {}),
//                           onRemove: () {
//                             setState(() {
//                               _units[i].dispose();
//                               _units.removeAt(i);
//                             });
//                           },
//                         ),
//                       ],
//                       const SizedBox(height: 12),
//                       _totalsSummary(),
//                     ],
//                   ),
//
//                   if (_error != null) ...[
//                     const SizedBox(height: 16),
//                     Container(
//                       padding: const EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         color: AppColors.dangerLight,
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: Row(
//                         children: [
//                           const Icon(Icons.error_outline,
//                               size: 14, color: AppColors.danger),
//                           const SizedBox(width: 8),
//                           Expanded(
//                             child: Text(_error!,
//                                 style: const TextStyle(
//                                     fontSize: 12,
//                                     color: AppColors.danger)),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//
//                   const SizedBox(height: 20),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.end,
//                     children: [
//                       TextButton(
//                         onPressed: _submitting
//                             ? null
//                             : () => context.go('/properties'),
//                         child: const Text('Cancel'),
//                       ),
//                       const SizedBox(width: 8),
//                       FilledButton.icon(
//                         onPressed:
//                         (_isValid && !_submitting) ? _submit : null,
//                         icon: _submitting
//                             ? const SizedBox(
//                             width: 14,
//                             height: 14,
//                             child: CircularProgressIndicator(
//                                 strokeWidth: 2,
//                                 color: Colors.white))
//                             : const Icon(Icons.check, size: 14),
//                         label: Text(
//                             _submitting ? 'Creating…' : 'Create property'),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _card({
//     required String title,
//     required List<Widget> children,
//     Widget? trailing,
//     String? subtitle,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: AppColors.border),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Expanded(
//                 child: Text(title,
//                     style: const TextStyle(
//                         fontSize: 13, fontWeight: FontWeight.w600)),
//               ),
//               if (trailing != null) trailing,
//             ],
//           ),
//           if (subtitle != null) ...[
//             const SizedBox(height: 4),
//             Text(subtitle,
//                 style: const TextStyle(
//                     fontSize: 11, color: AppColors.muted)),
//           ],
//           const SizedBox(height: 14),
//           ...children,
//         ],
//       ),
//     );
//   }
//
//   Widget _label(String s) => Padding(
//     padding: const EdgeInsets.only(bottom: 4),
//     child: Text(s,
//         style: const TextStyle(
//             fontSize: 12, fontWeight: FontWeight.w500)),
//   );
//
//   Widget _totalsSummary() {
//     int totalUnits = 0;
//     num totalInventoryValue = 0;
//     for (final u in _units) {
//       final c = int.tryParse(u.count.text) ?? 0;
//       final p = num.tryParse(u.price.text.replaceAll(',', '')) ?? 0;
//       totalUnits += c;
//       totalInventoryValue += p * c;
//     }
//     if (totalUnits == 0) return const SizedBox.shrink();
//
//     return Container(
//       padding: const EdgeInsets.all(10),
//       decoration: BoxDecoration(
//         color: AppColors.brandLight,
//         borderRadius: BorderRadius.circular(6),
//       ),
//       child: Row(
//         children: [
//           const Icon(Icons.calculate_outlined,
//               size: 14, color: AppColors.brand),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               '$totalUnits units total · ${Formatters.naira(totalInventoryValue)} '
//                   'in inventory value',
//               style: const TextStyle(
//                   fontSize: 12,
//                   color: AppColors.brand,
//                   fontWeight: FontWeight.w500),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _UnitTypeRow extends StatelessWidget {
//   final int index;
//   final _UnitTypeDraft draft;
//   final bool canRemove;
//   final VoidCallback onChanged;
//   final VoidCallback onRemove;
//
//   const _UnitTypeRow({
//     required this.index,
//     required this.draft,
//     required this.canRemove,
//     required this.onChanged,
//     required this.onRemove,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: AppColors.bg2,
//         borderRadius: BorderRadius.circular(6),
//         border: Border.all(color: AppColors.border, width: 0.5),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 width: 22,
//                 height: 22,
//                 alignment: Alignment.center,
//                 decoration: BoxDecoration(
//                   color: AppColors.brand,
//                   borderRadius: BorderRadius.circular(11),
//                 ),
//                 child: Text('${index + 1}',
//                     style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 11,
//                         fontWeight: FontWeight.w600)),
//               ),
//               const SizedBox(width: 8),
//