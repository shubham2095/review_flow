import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/models/invoicing_models.dart';
import 'package:review_flow/screens/invoice_sheets.dart';
import 'package:review_flow/screens/invoicing_screen.dart';
import 'package:review_flow/services/invoicing_service.dart';
import 'package:review_flow/services/nav_access.dart';
import 'package:review_flow/services/session.dart';
import 'package:review_flow/theme/brand.dart';
import 'package:review_flow/widgets/invoice_format.dart';

const _lineA = DraftLine(
  description: 'Logo design',
  quantity: 2,
  unitPrice: 500,
);
const _lineB = DraftLine(
  description: 'Hosting',
  quantity: 1,
  unitPrice: 1000,
  gstPercent: 5,
);

void main() {
  group('invoiceTotals', () {
    test('uses the default GST for a line without its own', () {
      final t = invoiceTotals([_lineA], 18);
      expect(t.subtotal, 1000);
      expect(t.gst, 180);
      expect(t.total, 1180);
    });

    test('adds lines, each with its own GST', () {
      final t = invoiceTotals([_lineA, _lineB], 18);
      expect(t.subtotal, 2000);
      expect(t.gst, 230); // 180 + 50
      expect(t.total, 2230);
    });

    test('rounds each line to two places like the server', () {
      const l = DraftLine(description: 'x', quantity: 3, unitPrice: 33.33);
      final t = invoiceTotals([l], 18);
      expect(t.subtotal, 99.99);
      expect(t.gst, 18.0); // 17.9982 -> 18.00
      expect(t.total, 117.99);
    });

    test('no lines is zero', () {
      final t = invoiceTotals(const [], 18);
      expect(t.total, 0);
    });
  });

  group('money', () {
    test('rupees use Indian grouping', () {
      expect(invoiceMoney(1234567.5, 'INR'), '₹12,34,567.50');
      expect(invoiceMoney(999, 'INR'), '₹999.00');
      expect(invoiceMoney(1000, 'INR'), '₹1,000.00');
    });

    test('other currencies use the usual grouping and their sign', () {
      expect(invoiceMoney(1234567.5, 'USD'), r'$1,234,567.50');
      expect(invoiceMoney(50, 'GBP'), '£50.00');
    });

    test('an unknown currency shows its code', () {
      expect(invoiceMoney(10, 'AED'), 'AED 10.00');
    });

    test('negative and groupDigits', () {
      expect(invoiceMoney(-1500, 'INR'), '-₹1,500.00');
      expect(groupDigits('12345678', indian: true), '1,23,45,678');
      expect(groupDigits('12345678', indian: false), '12,345,678');
      expect(groupDigits('123', indian: true), '123');
    });

    test('invoiceNumber drops a pointless .0', () {
      expect(invoiceNumber(2), '2');
      expect(invoiceNumber(2.5), '2.5');
      expect(invoiceNumber(18), '18');
      expect(invoiceNumber(0.25), '0.25');
    });
  });

  group('invoiceStatus', () {
    test('words and colours', () {
      expect(invoiceStatus('DRAFT').$1, 'Draft');
      expect(invoiceStatus('SENT').$2, brand);
      expect(invoiceStatus('OVERDUE').$2, bad);
      expect(invoiceStatus('PAID').$2, good);
      expect(invoiceStatus('weird').$1, 'Weird');
      expect(invoiceStatus('').$1, '—');
    });
  });

  group('form rules', () {
    test('a line needs a description, quantity and price', () {
      expect(
        invoiceLineProblem(description: ' ', quantity: 1, unitPrice: 5),
        isNotNull,
      );
      expect(
        invoiceLineProblem(description: 'a', quantity: 0, unitPrice: 5),
        contains('quantity'),
      );
      expect(
        invoiceLineProblem(description: 'a', quantity: 1, unitPrice: null),
        contains('price'),
      );
      expect(
        invoiceLineProblem(
          description: 'a',
          quantity: 1,
          unitPrice: 5,
          gstPercent: 120,
        ),
        contains('GST'),
      );
      expect(
        invoiceLineProblem(description: 'a', quantity: 1, unitPrice: 0),
        isNull,
      );
    });

    test('an invoice needs a customer, a line and sane dates', () {
      final today = DateTime(2026, 11, 17);
      expect(
        invoiceFormProblem(customerId: null, lines: [_lineA], issueDate: today),
        contains('customer'),
      );
      expect(
        invoiceFormProblem(customerId: 'c1', lines: const [], issueDate: today),
        contains('line'),
      );
      expect(
        invoiceFormProblem(
          customerId: 'c1',
          lines: [_lineA],
          issueDate: today,
          dueDate: DateTime(2026, 11, 10),
        ),
        contains('due date'),
      );
      expect(
        invoiceFormProblem(
          customerId: 'c1',
          lines: [_lineA],
          issueDate: today,
          dueDate: today,
        ),
        isNull,
      );
    });

    test('a customer needs a name and a sane email', () {
      expect(customerProblem(name: ' ', email: ''), isNotNull);
      expect(customerProblem(name: 'A', email: 'nope'), contains('email'));
      expect(customerProblem(name: 'A', email: ''), isNull);
      expect(customerProblem(name: 'A', email: 'a@b.co'), isNull);
    });
  });

  group('models and service helpers', () {
    test('InvoiceList reads rows and stats', () {
      final l = InvoiceList.fromJson({
        'invoices': [
          {
            'id': 'i1',
            'invoice_number': 'INV-0001',
            'customer_name': 'Asha',
            'issue_date': '2026-11-01',
            'due_date': '2026-11-15',
            'status': 'OVERDUE',
            'total': 1180.0,
          },
        ],
        'stats': {'outstanding': 1180.0, 'paid_this_month': 500, 'drafts': 2},
      });
      expect(l.rows.single.status, 'OVERDUE');
      expect(l.rows.single.dueDate, isNotNull);
      expect(l.stats.outstanding, 1180);
      expect(l.stats.drafts, 2);
    });

    test('InvoiceWithProfile reads lines and the business profile', () {
      final d = InvoiceWithProfile.fromJson({
        'invoice': {
          'id': 'i1',
          'invoice_number': 'INV-0001',
          'customer': {'id': 'c1', 'name': 'Asha'},
          'status': 'DRAFT',
          'subtotal': 1000,
          'gst_total': 180,
          'total': 1180,
          'items': [
            {
              'description': 'Logo design',
              'quantity': 2,
              'unit_price': 500,
              'gst_percent': 18,
              'amount': 1180,
            },
          ],
        },
        'profile': {
          'company_name': 'Pizi India',
          'invoice_prefix': 'INV',
          'default_gst': '18.00',
          'currency': 'INR',
        },
      });
      expect(d.invoice.isDraft, isTrue);
      expect(d.invoice.customerName, 'Asha');
      expect(d.invoice.lines.single.amount, 1180);
      expect(d.profile.companyName, 'Pizi India');
      expect(d.profile.defaultGst, 18);
    });

    test('an empty profile uses safe defaults', () {
      final p = InvoiceProfile.fromJson({});
      expect(p.currency, 'INR');
      expect(p.invoicePrefix, 'INV');
      expect(p.defaultGst, 18);
    });

    test('DraftLine sends only what it has', () {
      expect(_lineA.toJson(), {
        'description': 'Logo design',
        'quantity': 2.0,
        'unit_price': 500.0,
      });
      expect(
        const DraftLine(
          description: 'x',
          quantity: 1,
          unitPrice: 1,
          gstPercent: 0,
          serviceId: 's1',
        ).toJson(),
        containsPair('gst_percent', 0.0),
      );
    });

    test('apiDate pads month and day', () {
      expect(apiDate(DateTime(2026, 3, 5)), '2026-03-05');
    });

    test('filterInvoices keeps one status or everything', () {
      const rows = [
        InvoiceRow(
          id: '1',
          number: 'A',
          customerName: '',
          status: 'PAID',
          total: 1,
        ),
        InvoiceRow(
          id: '2',
          number: 'B',
          customerName: '',
          status: 'DRAFT',
          total: 1,
        ),
      ];
      expect(filterInvoices(rows, null), hasLength(2));
      expect(filterInvoices(rows, 'PAID').single.id, '1');
    });
  });

  test('invoiceShareText lists the lines, totals and bank details', () {
    const inv = InvoiceDetail(
      id: 'i1',
      number: 'INV-0001',
      status: 'SENT',
      customerId: 'c1',
      customerName: 'Asha',
      subtotal: 1000,
      gstTotal: 180,
      total: 1180,
      notes: 'Thank you!',
      lines: [
        InvoiceLine(
          description: 'Logo design',
          quantity: 2,
          unitPrice: 500,
          gstPercent: 18,
          amount: 1180,
        ),
      ],
    );
    const profile = InvoiceProfile(
      companyName: 'Pizi India',
      gstin: '27ABCDE1234F1Z5',
      bankName: 'HDFC',
      bankAccount: '1234567890',
      ifsc: 'HDFC0001',
    );
    final text = invoiceShareText(inv, profile);
    expect(text, startsWith('Invoice INV-0001'));
    expect(text, contains('From: Pizi India (GSTIN 27ABCDE1234F1Z5)'));
    expect(text, contains('To: Asha'));
    expect(text, contains('- Logo design: 2 x ₹500.00 + 18% GST = ₹1,180.00'));
    expect(text, contains('Total: ₹1,180.00'));
    expect(text, contains('Account: 1234567890  IFSC: HDFC0001'));
    expect(text, endsWith('Thank you!'));
  });

  test('the Invoicing menu needs the invoicing plan feature', () {
    AppUser user(List<String>? f) =>
        AppUser(id: '1', name: 'A', email: 'a@b.c', planFeatures: f);
    expect(navAllowed(user(['seo']), NavRules.invoicing), isFalse);
    expect(navAllowed(user(['invoicing']), NavRules.invoicing), isTrue);
    expect(navAllowed(user(null), NavRules.invoicing), isTrue);
  });
}
