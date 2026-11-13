import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuel_tracker/api.dart';
import 'package:fuel_tracker/car_repository.dart';
import 'package:fuel_tracker/secure_storage.dart';
import 'package:fuel_tracker/share_car_page.dart';
import 'package:fuel_tracker/storage_service.dart';
import 'package:fuel_tracker/trip_tracker.dart';

class CarPage extends StatefulWidget {
  final Car car;
  final StorageService storage;
  final AuthStorage authStorage;

  /// Only the owner can change the car. Users the car is shared with can only
  /// view it.
  final bool isOwner;

  /// The logged in user, needed to leave a shared car.
  final int? userId;

  /// Called after the car is deleted or left. Pops the page when not set.
  final VoidCallback? onRemoved;

  const CarPage({
    super.key,
    required this.car,
    required this.storage,
    required this.authStorage,
    this.isOwner = true,
    this.userId,
    this.onRemoved,
  });

  @override
  State<CarPage> createState() => _CarPageState();
}

class _CarPageState extends State<CarPage> {
  late Car _car;
  late Future<CarPrice> _price;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _car = widget.car;
    _price = _loadPrice();
  }

  @override
  void didUpdateWidget(CarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The parent reloaded the car, for example the current car on the home tab.
    if (widget.car != oldWidget.car) {
      _car = widget.car;
      _price = _loadPrice();
    }
  }

  final _repository = CarRepository.instance;

  Future<Api> _api() => _repository.api();

  Future<CarPrice> _loadPrice() => _repository.getPrice(_car.id!);

  Future<void> _refresh() async {
    try {
      final car = await _repository.getCar(_car.id!);
      setState(() {
        _car = car;
        _price = _loadPrice();
      });
      await _price;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  /// Saves a km change. Works offline, the change is synced later.
  Future<bool> _saveKm(KmChange change) async {
    final car = await _repository.changeKm(_car, change);
    if (mounted) setState(() => _car = car);
    return true;
  }

  /// Saves other changes to the server. Needs a connection. Returns false
  /// when saving failed.
  Future<bool> _save(Car car) async {
    setState(() => _saving = true);
    try {
      // The whole car is sent, so queued km changes must be on the server
      // first or they would be counted twice.
      await _repository.sync();
      if (_repository.hasPending(car.id!)) {
        throw ApiException(
          'Km changes are still waiting to sync. Try again when online.',
        );
      }
      final api = await _api();
      final saved = await api.editCar(
        id: car.id!,
        name: car.name,
        kmThreshold: car.kmTreshold,
        kmDriven: car.kmDriven,
        totalKmDriven: car.totalKmDriven,
        consumption: car.consumption,
        fuelType: car.fuelType,
        countryCode: car.countryCode,
      );
      await _repository.carSaved(saved);
      if (!mounted) return true;
      setState(() {
        _car = saved;
        _price = _loadPrice();
      });
      return true;
    } on OfflineException {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offline. Only km changes can be saved offline.'),
        ),
      );
      return false;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Resets the trip after paying for the km driven. The odometer is kept.
  Future<void> _markAsPaid() async {
    CarPrice? price;
    try {
      price = await _price;
    } catch (_) {
      // Still allow resetting when the price is not available.
    }
    if (!mounted) return;
    final owed = _owed(_car, price);
    final km = formatKm(_car.kmDriven);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.payments_outlined),
        title: const Text('Mark as paid?'),
        content: Text(
          owed == null
              ? 'The trip of $km km is reset to 0 km.'
              : 'You paid €${owed.toStringAsFixed(2)} for $km km. '
                    'The trip is reset to 0 km.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark as paid'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final paid = await _saveKm(KmChange.resetTrip(widget.userId, _car.id!));
    if (!paid || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          owed == null
              ? 'Trip reset'
              : 'Paid €${owed.toStringAsFixed(2)}, trip reset',
        ),
      ),
    );
  }

  /// Deletes the car when owned, otherwise stops sharing it with this user.
  Future<void> _remove() async {
    final isOwner = widget.isOwner;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isOwner ? 'Delete ${_car.name}?' : 'Leave ${_car.name}?'),
        content: Text(
          isOwner
              ? 'The car and its km are removed for everyone it is shared with. '
                    'This cannot be undone.'
              : 'The car is removed from your list. The owner can share it '
                    'with you again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isOwner ? 'Delete' : 'Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      final api = await _api();
      if (isOwner) {
        await api.deleteCar(_car.id!);
      } else {
        await api.unshareCar(_car.id!, widget.userId!);
      }
      if (!mounted) return;
      final onRemoved = widget.onRemoved;
      if (onRemoved != null) {
        onRemoved();
      } else {
        Navigator.pop(context);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<bool> _addKm(double km) =>
      _saveKm(KmChange.add(widget.userId, _car.id!, km));

  Future<void> _editName() async {
    final name = await _showTextDialog(
      context,
      title: 'Name',
      initial: _car.name,
      validator: (value) => value.isEmpty ? 'Enter a name' : null,
    );
    if (name != null) await _save(_car.copyWith(name: name));
  }

  Future<void> _editCountry() async {
    final code = await _showTextDialog(
      context,
      title: 'Country code',
      initial: _car.countryCode,
      hint: 'NL',
      maxLength: 2,
      capitalization: TextCapitalization.characters,
      validator: (value) => RegExp(r'^[A-Za-z]{2}$').hasMatch(value)
          ? null
          : 'Enter a 2-letter country code',
    );
    if (code != null) {
      await _save(_car.copyWith(countryCode: code.toUpperCase()));
    }
  }

  Future<void> _editFuelType() async {
    final fuelType = await showDialog<FuelType>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Fuel type'),
        children: [
          for (final fuelType in FuelType.values)
            ListTile(
              leading: Icon(
                fuelType == _car.fuelType
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(_fuelTypeLabel(fuelType)),
              onTap: () => Navigator.pop(context, fuelType),
            ),
        ],
      ),
    );
    if (fuelType != null && fuelType != _car.fuelType) {
      await _save(_car.copyWith(fuelType: fuelType));
    }
  }

  Future<double?> _editNumber({
    required String title,
    required double initial,
    required String suffix,
    int decimals = 0,
  }) {
    return _showNumberDialog(
      context,
      title: title,
      initial: initial,
      suffix: suffix,
      decimals: decimals,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final screenHeight = MediaQuery.sizeOf(context).height;

    // Only show the app bar when there is a back button, so the current car
    // tab has no empty bar on top.
    final canPop = Navigator.canPop(context);

    return Scaffold(
      appBar: canPop
          ? AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            24,
            canPop ? 0 : MediaQuery.paddingOf(context).top + 24,
            24,
            0,
          ),
          children: [
            InkWell(
              onTap: _saving || !widget.isOwner ? null : _editName,
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      _car.name,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.isOwner) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.edit, size: 20, color: scheme.onSurfaceVariant),
                  ],
                  if (_saving) ...[
                    const SizedBox(width: 12),
                    const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [
                _fuelTypeLabel(_car.fuelType),
                _car.countryCode,
                if (!widget.isOwner) 'Shared with you',
              ].join(' · '),
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _ThresholdBar(car: _car)),
                if (widget.isOwner)
                  FilledButton.tonalIcon(
                    onPressed: _saving || _car.kmDriven == 0
                        ? null
                        : _markAsPaid,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Paid'),
                  ),
              ],
            ),
            SizedBox(height: screenHeight * 0.03),
            _CarHero(height: screenHeight * 0.22),
            SizedBox(height: screenHeight * 0.03),
            FutureBuilder<CarPrice>(
              future: _price,
              builder: (context, snapshot) => _PriceRow(
                car: _car,
                price: snapshot.data,
                error: snapshot.error,
              ),
            ),
            if (widget.isOwner) ...[
              const SizedBox(height: 16),
              _TripCard(carId: _car.id!, enabled: !_saving, onAdd: _addKm),
              const SizedBox(height: 16),
              _AddKmCard(enabled: !_saving, onAdd: _addKm),
            ],
            const SizedBox(height: 24),
            const Divider(height: 1),
            _InfoTile(
              icon: Icons.route,
              title: 'Trip',
              subtitle: 'Driven since last payment',
              value: '${formatKm(_car.kmDriven)} km',
              onTap: _saving || !widget.isOwner
                  ? null
                  : () async {
                      final km = await _editNumber(
                        title: 'Trip',
                        initial: _car.kmDriven,
                        suffix: 'km',
                        decimals: 1,
                      );
                      if (km != null) {
                        await _saveKm(
                          KmChange.setTrip(widget.userId, _car.id!, km),
                        );
                      }
                    },
            ),
            _InfoTile(
              icon: Icons.speed,
              title: 'Odometer',
              subtitle: 'Total driven',
              value: '${formatKm(_car.totalKmDriven)} km',
              onTap: _saving || !widget.isOwner
                  ? null
                  : () async {
                      final km = await _editNumber(
                        title: 'Odometer',
                        initial: _car.totalKmDriven,
                        suffix: 'km',
                        decimals: 1,
                      );
                      if (km != null) {
                        await _saveKm(
                          KmChange.setOdometer(widget.userId, _car.id!, km),
                        );
                      }
                    },
            ),
            _InfoTile(
              icon: Icons.flag_outlined,
              title: 'Threshold',
              subtitle: 'Pay back every',
              value: '${formatKm(_car.kmTreshold)} km',
              onTap: _saving || !widget.isOwner
                  ? null
                  : () async {
                      final km = await _editNumber(
                        title: 'Threshold',
                        initial: _car.kmTreshold,
                        suffix: 'km',
                        decimals: 1,
                      );
                      if (km != null) {
                        await _save(_car.copyWith(kmTreshold: km));
                      }
                    },
            ),
            _InfoTile(
              icon: Icons.water_drop_outlined,
              title: 'Consumption',
              subtitle: 'Liters per 100 km',
              value: '${_car.consumption.toStringAsFixed(1)} L',
              onTap: _saving || !widget.isOwner
                  ? null
                  : () async {
                      final liters = await _editNumber(
                        title: 'Consumption',
                        initial: _car.consumption,
                        suffix: 'L / 100 km',
                        decimals: 1,
                      );
                      if (liters != null) {
                        await _save(_car.copyWith(consumption: liters));
                      }
                    },
            ),
            _InfoTile(
              icon: Icons.local_gas_station_outlined,
              title: 'Fuel type',
              value: _fuelTypeLabel(_car.fuelType),
              onTap: _saving || !widget.isOwner ? null : _editFuelType,
            ),
            FutureBuilder<CarPrice>(
              future: _price,
              builder: (context, snapshot) {
                final fuelPrice = snapshot.data?.fuelPrice;
                return _InfoTile(
                  icon: Icons.euro,
                  title: 'Fuel price',
                  subtitle: 'Latest weekly price per liter',
                  value: fuelPrice == null
                      ? '–'
                      : '€${fuelPrice.toStringAsFixed(3)}',
                );
              },
            ),
            _InfoTile(
              icon: Icons.public,
              title: 'Country',
              value: _car.countryCode,
              onTap: _saving || !widget.isOwner ? null : _editCountry,
            ),
            const Divider(height: 1),
            if (widget.isOwner)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.share_outlined),
                title: Text('Share', style: theme.textTheme.titleMedium),
                subtitle: const Text('Let others view this car'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ShareCarPage(
                      car: _car,
                      storage: widget.storage,
                      authStorage: widget.authStorage,
                    ),
                  ),
                ),
              ),
            if (widget.isOwner || widget.userId != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                iconColor: scheme.error,
                textColor: scheme.error,
                leading: Icon(
                  widget.isOwner ? Icons.delete_outline : Icons.logout,
                ),
                title: Text(widget.isOwner ? 'Delete car' : 'Leave car'),
                onTap: _saving ? null : _remove,
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Formats km with one decimal, without a trailing ".0".
String formatKm(double km) {
  final text = km.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

/// Money owed for the km driven since the last payment.
double? _owed(Car car, CarPrice? price) {
  final fuelPrice = price?.fuelPrice;
  // Use the unrounded fuel price when the server sends it.
  final pricePerKm = fuelPrice != null
      ? fuelPrice * car.consumption / 100
      : price?.pricePerKm;
  return pricePerKm == null ? null : pricePerKm * car.kmDriven;
}

String _fuelTypeLabel(FuelType fuelType) {
  return switch (fuelType) {
    FuelType.diesel => 'Diesel',
    FuelType.e95 => 'Petrol (E95)',
  };
}

/// Shows how far the car is to the next payment, like the battery bar in the
/// Tesla app.
class _ThresholdBar extends StatelessWidget {
  final Car car;

  const _ThresholdBar({required this.car});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = car.kmTreshold > 0
        ? (car.kmDriven / car.kmTreshold).clamp(0.0, 1.0)
        : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 56,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: scheme.surfaceContainerHighest,
              color: progress >= 1 ? scheme.error : scheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${formatKm(car.kmDriven)} / '
          '${formatKm(car.kmTreshold)} km',
          style: theme.textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _CarHero extends StatelessWidget {
  final double height;

  const _CarHero({required this.height});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft shadow under the car.
          Positioned(
            bottom: height * 0.12,
            child: Container(
              width: height * 1.4,
              height: height * 0.12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(
                  Radius.elliptical(height * 0.7, height * 0.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.35),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          Icon(
            Icons.directions_car_filled,
            size: height,
            color: scheme.onSurface,
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final Car car;
  final CarPrice? price;
  final Object? error;

  const _PriceRow({required this.car, this.price, this.error});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (error != null) {
      return ListTile(
        leading: Icon(Icons.error_outline, color: scheme.error),
        title: Text(error.toString()),
      );
    }

    final price = this.price;
    final owed = _owed(car, price);

    String euro(double? value) =>
        value == null ? '–' : '€${value.toStringAsFixed(2)}';

    return Row(
      children: [
        _PriceTile(
          icon: Icons.payments_outlined,
          label: 'Owed',
          value: euro(owed),
          highlight: true,
        ),
        const SizedBox(width: 12),
        _PriceTile(
          icon: Icons.straighten,
          label: 'Per km',
          value: euro(price?.pricePerKm),
        ),
        const SizedBox(width: 12),
        _PriceTile(
          icon: Icons.flag_outlined,
          label: 'Per ${formatKm(car.kmTreshold)} km',
          value: euro(price?.pricePerThreshold),
        ),
      ],
    );
  }
}

class _PriceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _PriceTile({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = highlight ? scheme.onPrimaryContainer : scheme.onSurface;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: highlight
              ? scheme.primaryContainer
              : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: foreground),
            const SizedBox(height: 8),
            FittedBox(
              child: Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: foreground.withValues(alpha: 0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String value;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: theme.textTheme.titleMedium),
          // Keep values aligned whether or not the row is editable.
          SizedBox(
            width: 32,
            child: onTap == null
                ? null
                : Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// Counter to log driven km. Tap or hold the -/+ buttons, use the quick
/// chips, or tap the number to type it.
class _AddKmCard extends StatefulWidget {
  final bool enabled;
  final Future<bool> Function(double km) onAdd;

  const _AddKmCard({required this.enabled, required this.onAdd});

  @override
  State<_AddKmCard> createState() => _AddKmCardState();
}

class _AddKmCardState extends State<_AddKmCard> {
  static const _quickAmounts = [5, 10, 25, 50];

  double _km = 0;
  Timer? _repeat;

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  void _change(int delta) {
    final next = (_km + delta).clamp(0.0, 99999.0);
    if (next == _km) return;
    HapticFeedback.selectionClick();
    setState(() => _km = next);
  }

  void _startRepeat(int delta) {
    _repeat?.cancel();
    var ticks = 0;
    _repeat = Timer.periodic(const Duration(milliseconds: 80), (_) {
      ticks++;
      // Speed up the longer the button is held.
      _change(ticks > 25 ? delta * 10 : delta);
    });
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  Future<void> _typeKm() async {
    final km = await _showNumberDialog(
      context,
      title: 'Add km',
      initial: _km,
      suffix: 'km',
      decimals: 1,
    );
    if (km != null) setState(() => _km = km);
  }

  Future<void> _submit() async {
    final km = _km;
    final added = await widget.onAdd(km);
    if (added && mounted) setState(() => _km = 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.add_road, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text('Add trip', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _RoundButton(
                icon: Icons.remove,
                onTap: _km > 0 ? () => _change(-1) : null,
                onHoldStart: () => _startRepeat(-1),
                onHoldEnd: _stopRepeat,
              ),
              Expanded(
                child: InkWell(
                  onTap: _typeKm,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 120),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: Text(
                          formatKm(_km),
                          key: ValueKey(_km),
                          style: theme.textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      Text(
                        'km',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _RoundButton(
                icon: Icons.add,
                onTap: () => _change(1),
                onHoldStart: () => _startRepeat(1),
                onHoldEnd: _stopRepeat,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final amount in _quickAmounts)
                ActionChip(
                  label: Text('+$amount'),
                  onPressed: () => _change(amount),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: _km > 0 ? () => setState(() => _km = 0) : null,
                child: const Text('Clear'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: widget.enabled && _km > 0 ? _submit : null,
                  icon: const Icon(Icons.check),
                  label: Text('Add ${formatKm(_km)} km'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  const _RoundButton({
    required this.icon,
    required this.onTap,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;

    return GestureDetector(
      onLongPressStart: enabled ? (_) => onHoldStart() : null,
      onLongPressEnd: (_) => onHoldEnd(),
      onLongPressCancel: onHoldEnd,
      child: IconButton.filledTonal(
        iconSize: 32,
        padding: const EdgeInsets.all(14),
        onPressed: onTap,
        icon: Icon(icon),
        color: enabled ? scheme.onSecondaryContainer : null,
      ),
    );
  }
}

Future<String?> _showTextDialog(
  BuildContext context, {
  required String title,
  required String initial,
  required String? Function(String value) validator,
  String? hint,
  int? maxLength,
  TextCapitalization capitalization = TextCapitalization.sentences,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _EditDialog(
      title: title,
      initial: initial,
      hint: hint,
      maxLength: maxLength,
      capitalization: capitalization,
      validator: validator,
    ),
  );
}

Future<double?> _showNumberDialog(
  BuildContext context, {
  required String title,
  required double initial,
  required String suffix,
  int decimals = 0,
}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (context) => _EditDialog(
      title: title,
      initial: initial.toStringAsFixed(decimals),
      suffix: suffix,
      keyboardType: TextInputType.numberWithOptions(decimal: decimals > 0),
      validator: (value) {
        final number = _parseNumber(value);
        if (number == null) return 'Enter a number';
        if (number < 0) return 'Must be 0 or more';
        return null;
      },
    ),
  );
  return result == null ? null : _parseNumber(result);
}

double? _parseNumber(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));

class _EditDialog extends StatefulWidget {
  final String title;
  final String initial;
  final String? hint;
  final String? suffix;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;
  final String? Function(String value) validator;

  const _EditDialog({
    required this.title,
    required this.initial,
    required this.validator,
    this.hint,
    this.suffix,
    this.maxLength,
    this.keyboardType,
    this.capitalization = TextCapitalization.none,
  });

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    final error = widget.validator(value);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.capitalization,
        maxLength: widget.maxLength,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: widget.hint,
          suffixText: widget.suffix,
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

/// Starts and stops a GPS trip. At the end the driven km can be checked and
/// corrected before they are added.
class _TripCard extends StatefulWidget {
  final int carId;
  final bool enabled;
  final Future<bool> Function(double km) onAdd;

  const _TripCard({
    required this.carId,
    required this.enabled,
    required this.onAdd,
  });

  @override
  State<_TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<_TripCard> {
  final _tracker = TripTracker.instance;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _tracker.addListener(_onTrackerChanged);
    _onTrackerChanged();
  }

  @override
  void dispose() {
    _tracker.removeListener(_onTrackerChanged);
    _clock?.cancel();
    super.dispose();
  }

  bool get _isThisCar => _tracker.carId == widget.carId;

  void _onTrackerChanged() {
    // Tick every second so the duration stays up to date.
    if (_isThisCar) {
      _clock ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
    } else {
      _clock?.cancel();
      _clock = null;
    }
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    try {
      await _tracker.start(widget.carId);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _stop() async {
    final result = await showDialog<_EndTripResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _EndTripDialog(km: _tracker.km, elapsed: _tracker.elapsed),
    );
    if (result == null) return; // Keep tracking.

    if (result.discard) {
      _tracker.stop();
      return;
    }
    // Only stop when the km are saved, so a failed save loses nothing.
    final added = await widget.onAdd(result.km);
    if (added) _tracker.stop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tracking = _isThisCar;
    final otherCar = _tracker.isTracking && !tracking;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tracking ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            tracking ? Icons.gps_fixed : Icons.gps_not_fixed,
            color: tracking
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: tracking
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // Meters on short trips, so walking tests show progress.
                        _tracker.km < 1
                            ? '${(_tracker.km * 1000).toStringAsFixed(0)} m'
                            : '${_tracker.km.toStringAsFixed(1)} km',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        'Trip running · ${_formatDuration(_tracker.elapsed)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      // GPS debug info.
                      Text(
                        _tracker.lastError ??
                            (_tracker.fixes == 0 &&
                                    _tracker.elapsed.inSeconds > 15
                                ? 'No GPS fix yet, check the logs'
                                : null) ??
                            [
                              '${_tracker.fixes} fixes',
                              '${_tracker.ignoredFixes} ignored',
                              if (_tracker.lastAccuracy != null)
                                '±${_tracker.lastAccuracy!.toStringAsFixed(0)} m',
                            ].join(' · '),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _tracker.lastError != null
                              ? scheme.error
                              : scheme.onPrimaryContainer.withValues(
                                  alpha: 0.7,
                                ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GPS trip', style: theme.textTheme.titleMedium),
                      Text(
                        otherCar
                            ? 'A trip is running for another car'
                            : 'Measure the km while you drive',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 12),
          if (tracking)
            FilledButton.icon(
              onPressed: widget.enabled ? _stop : null,
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
            )
          else
            FilledButton.icon(
              onPressed: widget.enabled && !otherCar ? _start : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'),
            ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

class _EndTripResult {
  const _EndTripResult.add(this.km) : discard = false;
  const _EndTripResult.discard() : km = 0, discard = true;

  final double km;
  final bool discard;
}

class _EndTripDialog extends StatefulWidget {
  final double km;
  final Duration elapsed;

  const _EndTripDialog({required this.km, required this.elapsed});

  @override
  State<_EndTripDialog> createState() => _EndTripDialogState();
}

class _EndTripDialogState extends State<_EndTripDialog> {
  late final _km = TextEditingController(text: widget.km.toStringAsFixed(1));
  String? _error;

  @override
  void dispose() {
    _km.dispose();
    super.dispose();
  }

  void _add() {
    final km = _parseNumber(_km.text);
    if (km == null || km < 0) {
      setState(() => _error = 'Enter a number');
      return;
    }
    Navigator.pop(context, _EndTripResult.add(km));
  }

  Future<void> _discard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard trip?'),
        content: const Text('The measured km are not added to the car.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.pop(context, const _EndTripResult.discard());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.flag),
      title: const Text('End trip?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You drove ${widget.km.toStringAsFixed(1)} km in '
            '${_formatDuration(widget.elapsed)}. Correct the km if needed.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _km,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: (_) => _add(),
            decoration: InputDecoration(
              labelText: 'Distance',
              suffixText: 'km',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _discard, child: const Text('Discard')),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep driving'),
        ),
        FilledButton(onPressed: _add, child: const Text('Add')),
      ],
    );
  }
}
