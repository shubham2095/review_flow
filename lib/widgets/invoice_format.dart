import 'package:flutter/material.dart';

import '../models/invoicing_models.dart';
import '../theme/brand.dart';
import 'date_format.dart';

const _symbols = {
  'INR': '₹',
  'USD': r'$',
  'EUR': '€',
  'GBP': '£',
  'AUD': r'A$',
  'CAD': r'C$',
  'SGD': r'S$',
};

/// Digits with thousands separators. Indian grouping (12,34,567) for rupees,
/// the usual 1,234,567 otherwise.
String groupDigits(String digits, {required bool indian}) {
  if (digits.length <= 3) return digits;
  final last3 = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final parts = <String>[];
  final size = indian ? 2 : 3;
  while (rest.length > size) {
    parts.insert(0, rest.substring(rest.length - size));
    rest = rest.substring(0, rest.length - size);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$last3';
}

/// An amount with its currency sign and two decimals: ₹12,34,567.50.
String invoiceMoney(double amount, [String currency = 'INR']) {
  final code = currency.toUpperCase();
  final negative = amount < 0;
  final fixed = amount.abs().toStringAsFixed(2);
  final dot = fixed.indexOf('.');
  final whole = groupDigits(fixed.substring(0, dot), indian: code == 'INR');
  final symbol = _symbols[code] ?? '$code ';
  return '${negative ? '-' : ''}$symbol$whole${fixed.substring(dot)}';
}

/// A quantity or percentage without a pointless ".0": 2, 2.5, 18.
String invoiceNumber(double v) {
  if (v == v.roundToDouble()) return v.round().toString();
  var s = v.toStringAsFixed(2);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// An invoice status as a word and a colour.
(String, Color) invoiceStatus(String status) => switch (status.toUpperCase()) {
  'DRAFT' => ('Draft', muted),
  'SENT' => ('Sent', brand),
  'OVERDUE' => ('Overdue', bad),
  'PAID' => ('Paid', good),
  _ => (
    status.isEmpty
        ? '—'
        : status[0].toUpperCase() + status.substring(1).toLowerCase(),
    muted,
  ),
};

/// What is wrong with one invoice line, or null.
String? invoiceLineProblem({
  required String description,
  required double? quantity,
  required double? unitPrice,
  double? gstPercent,
}) {
  if (description.trim().isEmpty) return 'Write what the line is for.';
  if (quantity == null || quantity < 0.01) {
    return 'The quantity must be at least 0.01.';
  }
  if (unitPrice == null || unitPrice < 0) {
    return 'Write the price (0 or more).';
  }
  if (gstPercent != null && (gstPercent < 0 || gstPercent > 100)) {
    return 'GST must be between 0 and 100.';
  }
  return null;
}

/// What is wrong with a whole new invoice, or null.
String? invoiceFormProblem({
  required String? customerId,
  required List<DraftLine> lines,
  required DateTime issueDate,
  DateTime? dueDate,
}) {
  if (customerId == null || customerId.isEmpty) return 'Choose a customer.';
  if (lines.isEmpty) return 'Add at least one line.';
  if (dueDate != null) {
    final issue = DateTime(issueDate.year, issueDate.month, issueDate.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    if (due.isBefore(issue)) return 'The due date cannot be before the date.';
  }
  return null;
}

/// A plain-text copy of an invoice to send in a chat or email.
String invoiceShareText(InvoiceDetail inv, InvoiceProfile p) {
  final cur = p.currency;
  final b = StringBuffer()..writeln('Invoice ${inv.number}');
  if (p.companyName.isNotEmpty) {
    b.writeln(
      'From: ${p.companyName}${p.gstin.isEmpty ? '' : ' (GSTIN ${p.gstin})'}',
    );
  }
  if (inv.customerName.isNotEmpty) b.writeln('To: ${inv.customerName}');
  if (inv.issueDate != null) b.writeln('Date: ${fmtDate(inv.issueDate!)}');
  if (inv.dueDate != null) b.writeln('Due: ${fmtDate(inv.dueDate!)}');
  b.writeln();
  for (final l in inv.lines) {
    b.writeln(
      '- ${l.description}: ${invoiceNumber(l.quantity)} x '
      '${invoiceMoney(l.unitPrice, cur)} + ${invoiceNumber(l.gstPercent)}% GST '
      '= ${invoiceMoney(l.amount, cur)}',
    );
  }
  b
    ..writeln()
    ..writeln('Subtotal: ${invoiceMoney(inv.subtotal, cur)}')
    ..writeln('GST: ${invoiceMoney(inv.gstTotal, cur)}')
    ..writeln('Total: ${invoiceMoney(inv.total, cur)}');
  if (p.bankName.isNotEmpty || p.bankAccount.isNotEmpty) {
    b
      ..writeln()
      ..writeln('Pay to: ${p.bankName}')
      ..writeln(
        'Account: ${p.bankAccount}${p.ifsc.isEmpty ? '' : '  IFSC: ${p.ifsc}'}',
      );
  }
  if (inv.notes.isNotEmpty) {
    b
      ..writeln()
      ..writeln(inv.notes);
  }
  return b.toString().trimRight();
}
