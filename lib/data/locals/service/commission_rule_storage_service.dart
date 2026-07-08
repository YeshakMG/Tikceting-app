import 'package:hive/hive.dart';
import 'package:oro_ticket_app/data/locals/models/commission_rule_model.dart';

class CommissionRuleStorageService {
  static const _boxName = 'commissionRulesBox';

  static Future<Box<CommissionRuleModel>> _openBox() async {
    return await Hive.openBox<CommissionRuleModel>(_boxName);
  }

  static Future<void> saveCommissionRules(List<CommissionRuleModel> rules) async {
    final box = await _openBox();
    await box.clear();
    await box.addAll(rules);
  }

  static List<CommissionRuleModel> getCommissionRules() {
    final box = Hive.box<CommissionRuleModel>(_boxName);
    return box.values.toList();
  }

  static Future<void> clearCommissionRules() async {
    final box = await _openBox();
    await box.clear();
  }
}
