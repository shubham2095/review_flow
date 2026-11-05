import 'gbp_models.dart';

class AdminCompany {
  AdminCompany({
    required this.id,
    required this.name,
    required this.status,
    required this.usersCount,
    required this.ownerName,
    required this.ownerEmail,
    required this.agentsUsed,
    this.planId,
    this.planName,
    this.agentsLimit,
    this.trialEndsAt,
    this.createdAt,
  });

  factory AdminCompany.fromJson(Map<String, dynamic> j) => AdminCompany(
        id: asStr(j['id']),
        name: asStr(j['name']),
        status: asStr(j['status']),
        usersCount: asInt(j['users_count']),
        ownerName: asStr(j['owner_name']),
        ownerEmail: asStr(j['owner_email']),
        planId: j['plan_id']?.toString(),
        planName: j['plan_name']?.toString(),
        agentsUsed: asInt(j['agents_used']),
        agentsLimit: j['agents_limit'] == null ? null : asInt(j['agents_limit']),
        trialEndsAt: asDate(j['trial_ends_at']),
        createdAt: asDate(j['created_at']),
      );

  final String id;
  final String name;
  final String status;
  final int usersCount;
  final String ownerName;
  final String ownerEmail;
  final String? planId;
  final String? planName;
  final int agentsUsed;

  /// Null means unlimited.
  final int? agentsLimit;
  final DateTime? trialEndsAt;
  final DateTime? createdAt;

  bool get suspended => status == 'suspended';
}

class AdminPlanOption {
  AdminPlanOption(this.id, this.name);

  final String id;
  final String name;
}

class AdminUser {
  AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.status,
    required this.role,
  });

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
        id: asStr(j['id']),
        name: asStr(j['name']),
        email: asStr(j['email']),
        status: asStr(j['status']),
        role: asStr(j['role']),
      );

  final String id;
  final String name;
  final String email;
  final String status;
  final String role;
}

class AdminPlan {
  AdminPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.billingPeriod,
    required this.price,
    required this.currency,
    required this.credits,
    required this.modules,
    required this.limits,
    required this.features,
    required this.isActive,
    required this.isPublic,
    required this.sortOrder,
    required this.subscribers,
  });

  factory AdminPlan.fromJson(Map<String, dynamic> j) {
    final limits = <String, int>{};
    asMap(j['limits']).forEach((k, v) => limits[k] = asInt(v));
    final features = <String, bool>{};
    asMap(j['features']).forEach((k, v) {
      features[k] = v == true || v == 1 || v == '1';
    });
    return AdminPlan(
      id: asStr(j['id']),
      name: asStr(j['name']),
      description: asStr(j['description']),
      billingPeriod: asStr(j['billing_period']).isEmpty
          ? 'monthly'
          : asStr(j['billing_period']),
      price: asDouble(j['price']),
      currency: asStr(j['currency']).isEmpty ? 'INR' : asStr(j['currency']),
      credits: asInt(j['credits']),
      modules: asInt(j['modules']),
      limits: limits,
      features: features,
      isActive: j['is_active'] == true,
      isPublic: j['is_public'] == true,
      sortOrder: asInt(j['sort_order']),
      subscribers: asInt(j['subscribers']),
    );
  }

  final String id;
  final String name;
  final String description;
  final String billingPeriod;
  final double price;
  final String currency;
  final int credits;
  final int modules;

  /// Value -1 means unlimited.
  final Map<String, int> limits;
  final Map<String, bool> features;
  final bool isActive;
  final bool isPublic;
  final int sortOrder;
  final int subscribers;
}

class AdminPlansData {
  AdminPlansData(this.plans, this.limitKeys, this.featureKeys);

  final List<AdminPlan> plans;
  final List<String> limitKeys;
  final List<String> featureKeys;
}

class AdminCreditPack {
  AdminCreditPack({
    required this.id,
    required this.name,
    required this.credits,
    required this.price,
    required this.gstRate,
    required this.sortOrder,
    required this.isActive,
  });

  factory AdminCreditPack.fromJson(Map<String, dynamic> j) => AdminCreditPack(
        id: asStr(j['id']),
        name: asStr(j['name']),
        credits: asInt(j['credits']),
        price: asDouble(j['price']),
        gstRate: asInt(j['gst_rate']),
        sortOrder: asInt(j['sort_order']),
        isActive: j['is_active'] == true,
      );

  final String id;
  final String name;
  final int credits;
  final double price;
  final int gstRate;
  final int sortOrder;
  final bool isActive;
}

class AdminPayment {
  AdminPayment({
    required this.number,
    required this.company,
    required this.status,
    required this.total,
    this.customer,
    this.plan,
    this.gateway,
    this.issuedAt,
  });

  factory AdminPayment.fromJson(Map<String, dynamic> j) => AdminPayment(
        number: asStr(j['number']),
        company: asStr(j['company']),
        status: asStr(j['status']),
        total: asStr(j['total']),
        customer: j['customer']?.toString(),
        plan: j['plan']?.toString(),
        gateway: j['gateway']?.toString(),
        issuedAt: asDate(j['issued_at']),
      );

  final String number;
  final String company;
  final String status;
  final String total;
  final String? customer;
  final String? plan;
  final String? gateway;
  final DateTime? issuedAt;
}

class AdminPaymentsData {
  AdminPaymentsData({
    required this.payments,
    required this.count,
    required this.paid,
    required this.revenue,
  });

  final List<AdminPayment> payments;
  final int count;
  final int paid;
  final String revenue;
}

class AiProviderInfo {
  AiProviderInfo({
    required this.key,
    required this.hasKey,
    required this.keySource,
    required this.model,
    required this.modelDefault,
    this.keyLast4,
  });

  final String key;
  final bool hasKey;

  /// saved, env or none.
  final String keySource;
  final String? keyLast4;
  final String model;
  final String modelDefault;
}

class AiSettingsData {
  AiSettingsData({
    required this.isActive,
    required this.providers,
    required this.geminiImageModel,
    required this.canGenerateImages,
    this.activeProvider,
    this.effectiveProvider,
  });

  factory AiSettingsData.fromJson(Map<String, dynamic> j) {
    final providers = <AiProviderInfo>[];
    asMap(j['providers']).forEach((key, value) {
      final p = asMap(value);
      providers.add(
        AiProviderInfo(
          key: key,
          hasKey: p['has_key'] == true,
          keySource: asStr(p['key_source']),
          keyLast4: p['key_last4']?.toString(),
          model: asStr(p['model']),
          modelDefault: asStr(p['model_default']),
        ),
      );
    });
    return AiSettingsData(
      isActive: j['is_active'] == true,
      activeProvider: j['active_provider']?.toString(),
      effectiveProvider: j['effective_provider']?.toString(),
      providers: providers,
      geminiImageModel: asStr(j['gemini_image_model']),
      canGenerateImages: j['can_generate_images'] == true,
    );
  }

  final bool isActive;
  final String? activeProvider;
  final String? effectiveProvider;
  final List<AiProviderInfo> providers;
  final String geminiImageModel;
  final bool canGenerateImages;
}

class AiTestResult {
  AiTestResult({required this.ok, required this.message});

  final bool ok;
  final String message;
}

class InvoiceSettings {
  InvoiceSettings({
    required this.companyName,
    required this.address,
    required this.gstin,
    required this.email,
    required this.phone,
    required this.taxDetails,
    required this.invoicePrefix,
    required this.gstRate,
  });

  factory InvoiceSettings.fromJson(Map<String, dynamic> j) => InvoiceSettings(
        companyName: asStr(j['company_name']),
        address: asStr(j['address']),
        gstin: asStr(j['gstin']),
        email: asStr(j['email']),
        phone: asStr(j['phone']),
        taxDetails: asStr(j['tax_details']),
        invoicePrefix: asStr(j['invoice_prefix']),
        gstRate: asInt(j['gst_rate']),
      );

  final String companyName;
  final String address;
  final String gstin;
  final String email;
  final String phone;
  final String taxDetails;
  final String invoicePrefix;
  final int gstRate;
}
