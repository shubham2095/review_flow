import '../models/gbp_models.dart';
import '../models/whatsapp_models.dart';
import 'api_service.dart';

/// WhatsApp calls (/api/v1/whatsapp/...). Later phases add inbox, contacts,
/// templates and campaigns here.
class WhatsAppService {
  WhatsAppService._();

  static final _api = ApiService.instance;

  /// Free home summary: numbers plus inbox and message counts.
  static Future<WaOverview> overview() async =>
      WaOverview.fromJson(await _api.get('/whatsapp/overview'));

  static Future<List<WaNumber>> numbers() async {
    final res = await _api.get('/whatsapp/numbers');
    return asMaps(res['numbers']).map(WaNumber.fromJson).toList();
  }
}
