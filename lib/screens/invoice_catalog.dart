import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/invoicing_models.dart';
import '../services/access_problem.dart';
import '../services/api_service.dart';
import '../services/invoicing_service.dart';
import '../theme/brand.dart';
import '../widgets/invoice_format.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';
import '../widgets/tab_label.dart';
import '../widgets/wa_ui.dart';
import 'invoice_catalog_sheets.dart';
import 'invoice_sheets.dart';

/// "₹500.00 + 18% GST" for a service.
String serviceSummary(InvoiceServiceItem s, String currency) =>
    '${invoiceMoney(s.price, currency)} + ${invoiceNumber(s.gstPercent)}% GST';

/// The things an invoice is made from: customers, services and the categories
/// that group services. A tab of the Invoicing page.
class InvoiceCatalogTab extends StatefulWidget {
  const InvoiceCatalogTab({super.key});

  @override
  State<InvoiceCatalogTab> createState() => _InvoiceCatalogTabState();
}

class _InvoiceCatalogTabState extends State<InvoiceCatalogTab> {
  List<InvoiceCustomer> _customers = [];
  List<InvoiceServiceItem> _services = [];
  List<InvoiceCategory> _categories = [];
  InvoiceProfile _profile = const InvoiceProfile();
  int _part = 0;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        InvoicingService.customers(),
        InvoicingService.services(),
        InvoicingService.categories(),
      ]);
      // The currency only decorates prices: do without it if it fails.
      InvoiceProfile profile = _profile;
      try {
        profile = await InvoicingService.profile();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _customers = results[0] as List<InvoiceCustomer>;
        _services = results[1] as List<InvoiceServiceItem>;
        _categories = results[2] as List<InvoiceCategory>;
        _profile = profile;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<T?> _sheet<T>(Widget sheet) => showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => sheet,
  );

  Future<bool> _confirm({required String title, required String text}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: bad),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return ok == true && mounted;
  }

  Future<void> _delete(Future<String> Function() action) async {
    try {
      final message = await action();
      if (!mounted) return;
      showToast(context, message);
      _load();
    } catch (e) {
      if (mounted) showToast(context, errorLine(e));
    }
  }

  // ---- Customers ----

  Future<void> _editCustomer([InvoiceCustomer? c]) async {
    final saved = await _sheet<InvoiceCustomer>(CustomerSheet(customer: c));
    if (saved == null || !mounted) return;
    showToast(context, c == null ? 'Customer added.' : 'Changes saved.');
    _load();
  }

  Future<void> _deleteCustomer(InvoiceCustomer c) async {
    final extra = c.invoicesCount > 0
        ? ' ${c.invoicesCount} ${c.invoicesCount == 1 ? 'invoice was' : 'invoices were'} made for them.'
        : '';
    if (!await _confirm(
      title: 'Delete ${c.name}?',
      text: 'The customer is removed.$extra',
    )) {
      return;
    }
    await _delete(() => InvoicingService.deleteCustomer(c.id));
  }

  // ---- Services ----

  Future<void> _editService([InvoiceServiceItem? s]) async {
    final saved = await _sheet<bool>(
      ServiceSheet(
        categories: _categories,
        defaultGst: _profile.defaultGst,
        service: s,
      ),
    );
    if (saved != true || !mounted) return;
    showToast(context, s == null ? 'Service added.' : 'Changes saved.');
    _load();
  }

  Future<void> _deleteService(InvoiceServiceItem s) async {
    if (!await _confirm(
      title: 'Delete ${s.name}?',
      text: 'The service is removed. Invoices already made keep their lines.',
    )) {
      return;
    }
    await _delete(() => InvoicingService.deleteService(s.id));
  }

  // ---- Categories ----

  Future<void> _addCategory() async {
    final saved = await _sheet<bool>(const CategorySheet());
    if (saved != true || !mounted) return;
    showToast(context, 'Category added.');
    _load();
  }

  Future<void> _deleteCategory(InvoiceCategory c) async {
    final extra = c.servicesCount > 0
        ? ' ${c.servicesCount} ${c.servicesCount == 1 ? 'service is' : 'services are'} in it and may lose the category.'
        : '';
    if (!await _confirm(
      title: 'Delete ${c.name}?',
      text: 'The category is removed.$extra',
    )) {
      return;
    }
    await _delete(() => InvoicingService.deleteCategory(c.id));
  }

  // ---- Lists ----

  Widget _header(String count, String addLabel, VoidCallback onAdd) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            count,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(addLabel),
        ),
      ],
    ),
  );

  Widget _card({
    required String label,
    required Widget child,
    required VoidCallback? onTap,
    required String menuTooltip,
    required List<(String, String)> menu,
    required ValueChanged<String> onMenu,
  }) {
    return Semantics(
      container: true,
      label: label,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: cardDecoration(),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 2, 10),
              child: Row(
                children: [
                  Expanded(child: ExcludeSemantics(child: child)),
                  PopupMenuButton<String>(
                    tooltip: menuTooltip,
                    onSelected: onMenu,
                    itemBuilder: (_) => [
                      for (final (value, text) in menu)
                        PopupMenuItem(value: value, child: Text(text)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _customersList() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _customers.isEmpty ? 2 : _customers.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return _header(
            '${_customers.length} ${_customers.length == 1 ? 'customer' : 'customers'}',
            'Add customer',
            () => _editCustomer(),
          );
        }
        if (_customers.isEmpty) {
          return const StateView(
            icon: Icons.people_outline_rounded,
            title: 'No customers yet',
            text: 'Add the people and businesses you send invoices to.',
          );
        }
        final c = _customers[i - 1];
        final detail = [
          if (c.phone.isNotEmpty) c.phone,
          if (c.email.isNotEmpty) c.email,
        ].join(' · ');
        return _card(
          label:
              '${c.name}${detail.isEmpty ? '' : ', $detail'}, '
              '${c.invoicesCount} ${c.invoicesCount == 1 ? 'invoice' : 'invoices'}',
          onTap: () => _editCustomer(c),
          menuTooltip: 'More for ${c.name}',
          menu: const [('edit', 'Edit'), ('delete', 'Delete')],
          onMenu: (v) => v == 'edit' ? _editCustomer(c) : _deleteCustomer(c),
          child: Row(
            children: [
              ContactAvatar(name: c.name, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    if (detail.isNotEmpty)
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: muted,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          InfoChip(
                            '${c.invoicesCount} ${c.invoicesCount == 1 ? 'invoice' : 'invoices'}',
                          ),
                          if (c.gstin.isNotEmpty) InfoChip('GSTIN ${c.gstin}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _servicesList() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _services.isEmpty ? 2 : _services.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return _header(
            '${_services.length} ${_services.length == 1 ? 'service' : 'services'}',
            'Add service',
            () => _editService(),
          );
        }
        if (_services.isEmpty) {
          return const StateView(
            icon: Icons.inventory_2_outlined,
            title: 'No services yet',
            text:
                'Save what you sell with its price and GST, then pick it on '
                'an invoice.',
          );
        }
        final s = _services[i - 1];
        final summary = serviceSummary(s, _profile.currency);
        return _card(
          label:
              '${s.name}, $summary'
              '${s.category.isEmpty ? '' : ', ${s.category}'}, '
              '${s.active ? 'active' : 'inactive'}',
          onTap: () => _editService(s),
          menuTooltip: 'More for ${s.name}',
          menu: const [('edit', 'Edit'), ('delete', 'Delete')],
          onMenu: (v) => v == 'edit' ? _editService(s) : _deleteService(s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.name,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  color: s.active ? ink : muted,
                ),
              ),
              Text(
                summary,
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
              ),
              if (s.category.isNotEmpty || !s.active)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (s.category.isNotEmpty) InfoChip(s.category),
                      if (!s.active) const StatusBadge('Inactive', muted),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _categoriesList() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _categories.isEmpty ? 2 : _categories.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return _header(
            '${_categories.length} ${_categories.length == 1 ? 'category' : 'categories'}',
            'Add category',
            _addCategory,
          );
        }
        if (_categories.isEmpty) {
          return const StateView(
            icon: Icons.category_outlined,
            title: 'No categories yet',
            text: 'Group your services, for example Design or Hosting.',
          );
        }
        final c = _categories[i - 1];
        return _card(
          label:
              '${c.name}, ${c.servicesCount} ${c.servicesCount == 1 ? 'service' : 'services'}',
          onTap: null,
          menuTooltip: 'More for ${c.name}',
          menu: const [('delete', 'Delete')],
          onMenu: (_) => _deleteCategory(c),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  c.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
              ),
              InfoChip(
                '${c.servicesCount} ${c.servicesCount == 1 ? 'service' : 'services'}',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _content() {
    final list = switch (_part) {
      1 => _servicesList(),
      2 => _categoriesList(),
      _ => _customersList(),
    };
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: TabLabel('Customers')),
                ButtonSegment(value: 1, label: TabLabel('Services')),
                ButtonSegment(value: 2, label: TabLabel('Categories')),
              ],
              selected: {_part},
              onSelectionChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _part = v.first);
              },
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: brand,
            onRefresh: _load,
            child: ContentWidth(child: list),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SkeletonList(count: 4, itemHeight: 82, headerHeight: 52);
    }
    final error = _error;
    if (error != null) {
      final access = accessProblem(error);
      return Center(
        child: SingleChildScrollView(
          child: access != null
              ? StateView(
                  icon: access.icon,
                  title: access.title,
                  text: access.text,
                )
              : StateView.error(
                  title: 'Could not load your catalog',
                  text: friendlyException(error).message,
                  onRetry: () {
                    setState(() => _loading = true);
                    _load();
                  },
                ),
        ),
      );
    }
    return _content();
  }
}
