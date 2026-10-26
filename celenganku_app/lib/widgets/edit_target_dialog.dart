import 'package:flutter/material.dart';
import '../models/celengan_data.dart';
import '../services/celengan_service.dart';

class EditTargetDialog extends StatefulWidget {
  final CelenganInfo currentInfo;

  const EditTargetDialog({super.key, required this.currentInfo});

  @override
  State<EditTargetDialog> createState() => _EditTargetDialogState();
}

class _EditTargetDialogState extends State<EditTargetDialog> {
  late TextEditingController _namaAnakCtrl;
  late TextEditingController _targetNamaCtrl;
  late TextEditingController _targetNominalCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _namaAnakCtrl = TextEditingController(text: widget.currentInfo.namaAnak);
    _targetNamaCtrl = TextEditingController(text: widget.currentInfo.targetNama);
    _targetNominalCtrl = TextEditingController(
      text: widget.currentInfo.targetNominal.toString(),
    );
  }

  @override
  void dispose() {
    _namaAnakCtrl.dispose();
    _targetNamaCtrl.dispose();
    _targetNominalCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final nominal = int.tryParse(_targetNominalCtrl.text.trim()) ?? 0;
    if (nominal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal target harus lebih dari 0')),
      );
      return;
    }

    setState(() => _isLoading = true);
    await CelenganService().updateTarget(
      namaAnak: _namaAnakCtrl.text.trim(),
      targetNama: _targetNamaCtrl.text.trim(),
      targetNominal: nominal,
    );
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(
        children: [
          Icon(Icons.flag_rounded, color: Color(0xFF0D9488)),
          SizedBox(width: 8),
          Text('Ubah Target Tabungan'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _namaAnakCtrl,
              decoration: InputDecoration(
                labelText: 'Nama Anak',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _targetNamaCtrl,
              decoration: InputDecoration(
                labelText: 'Nama Impian / Barang',
                hintText: 'Contoh: Sepeda Baru, Lego',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                prefixIcon: const Icon(Icons.shopping_bag_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _targetNominalCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Target Nominal (Rp)',
                hintText: 'Contoh: 100000',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                prefixIcon: const Icon(Icons.attach_money),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D9488),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
