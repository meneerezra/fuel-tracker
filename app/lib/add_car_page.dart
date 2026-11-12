import 'package:flutter/material.dart';
import 'package:fuel_tracker/api.dart';
import 'package:fuel_tracker/secure_storage.dart';
import 'package:fuel_tracker/storage_service.dart';

/// Form to create a car. Pops with the created [Car].
class AddCarPage extends StatefulWidget {
  final StorageService storage;
  final AuthStorage authStorage;

  const AddCarPage({
    super.key,
    required this.storage,
    required this.authStorage,
  });

  @override
  State<AddCarPage> createState() => _AddCarPageState();
}

class _AddCarPageState extends State<AddCarPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _consumption = TextEditingController();
  final _threshold = TextEditingController(text: '500');
  final _country = TextEditingController(text: 'NL');
  FuelType _fuelType = FuelType.e95;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _consumption.dispose();
    _threshold.dispose();
    _country.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final token = await widget.authStorage.getAuthToken();
      if (token == null) throw ApiException('Not logged in');
      final api = Api(baseUrl: widget.storage.getServerUrl(), authToken: token);
      final car = await api.createCar(
        name: _name.text.trim(),
        kmThreshold: _parseNumber(_threshold.text)!,
        fuelType: _fuelType,
        consumption: _parseNumber(_consumption.text)!,
        countryCode: _country.text.trim().toUpperCase(),
      );
      if (!mounted) return;
      Navigator.pop(context, car);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add car')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.directions_car_outlined),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 24),
            SegmentedButton<FuelType>(
              segments: const [
                ButtonSegment(value: FuelType.e95, label: Text('Petrol (E95)')),
                ButtonSegment(value: FuelType.diesel, label: Text('Diesel')),
              ],
              selected: {_fuelType},
              onSelectionChanged: (selected) =>
                  setState(() => _fuelType = selected.first),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _consumption,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Consumption',
                suffixText: 'L / 100 km',
                prefixIcon: Icon(Icons.water_drop_outlined),
              ),
              validator: _validateNumber,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _threshold,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Threshold',
                helperText: 'Pay back every this many km',
                suffixText: 'km',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              validator: _validateNumber,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _country,
              maxLength: 2,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Country code',
                prefixIcon: Icon(Icons.public),
              ),
              validator: (value) =>
                  RegExp(r'^[A-Za-z]{2}$').hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Enter a 2-letter country code',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: const Text('Add car'),
            ),
          ],
        ),
      ),
    );
  }
}

String? _validateNumber(String? value) {
  final number = _parseNumber(value ?? '');
  if (number == null) return 'Enter a number';
  if (number < 0) return 'Must be 0 or more';
  return null;
}

double? _parseNumber(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));
