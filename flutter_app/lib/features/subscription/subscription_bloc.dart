import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// ── Events ─────────────────────────────────────────────────────────────────────
abstract class SubscriptionEvent extends Equatable {
  const SubscriptionEvent();
  @override
  List<Object?> get props => [];
}

class LoadSubscription extends SubscriptionEvent {
  const LoadSubscription();
}

class PurchasePro extends SubscriptionEvent {
  const PurchasePro();
}

class PurchasePremium extends SubscriptionEvent {
  const PurchasePremium();
}

class RestorePurchases extends SubscriptionEvent {
  const RestorePurchases();
}

// ── State ──────────────────────────────────────────────────────────────────────
class SubscriptionState extends Equatable {
  final String plan; // free | pro | premium
  final String status; // active | cancelled | expired | trial
  final DateTime? periodEnd;
  final bool isLoading;
  final String? error;
  final bool isPurchasing;

  const SubscriptionState({
    this.plan = 'free',
    this.status = 'active',
    this.periodEnd,
    this.isLoading = false,
    this.error,
    this.isPurchasing = false,
  });

  bool get isPro => plan == 'pro' && status == 'active';
  bool get isPremium => plan == 'premium' && status == 'active';
  bool get canExport1080p => isPro || isPremium;
  bool get canExport4k => isPremium;
  bool get canUseAI => isPro || isPremium;

  SubscriptionState copyWith({
    String? plan,
    String? status,
    DateTime? periodEnd,
    bool? isLoading,
    String? error,
    bool? isPurchasing,
  }) =>
      SubscriptionState(
        plan: plan ?? this.plan,
        status: status ?? this.status,
        periodEnd: periodEnd ?? this.periodEnd,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        isPurchasing: isPurchasing ?? this.isPurchasing,
      );

  @override
  List<Object?> get props => [plan, status, periodEnd, isLoading, isPurchasing];
}

// ── BLoC ───────────────────────────────────────────────────────────────────────
class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  static const _proProductId = 'video_editor_pro_monthly';
  static const _premiumProductId = 'video_editor_premium_monthly';

  SubscriptionBloc() : super(const SubscriptionState()) {
    on<LoadSubscription>(_onLoad);
    on<PurchasePro>(_onPurchasePro);
    on<PurchasePremium>(_onPurchasePremium);
    on<RestorePurchases>(_onRestore);
  }

  Future<void> _onLoad(
      LoadSubscription event, Emitter<SubscriptionState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final info = await Purchases.getCustomerInfo();
      final plan = _planFromInfo(info);
      emit(state.copyWith(plan: plan, status: 'active', isLoading: false));
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onPurchasePro(
      PurchasePro event, Emitter<SubscriptionState> emit) async {
    emit(state.copyWith(isPurchasing: true, error: null));
    try {
      final offerings = await Purchases.getOfferings();
      final pkg = offerings.current?.availablePackages
          .firstWhere((p) => p.storeProduct.identifier == _proProductId);
      if (pkg == null) throw Exception('Product not found');
      final result = await Purchases.purchasePackage(pkg);
      emit(state.copyWith(
          plan: _planFromInfo(result.customerInfo), status: 'active', isPurchasing: false));
    } on PurchasesErrorCode catch (e) {
      emit(state.copyWith(
          isPurchasing: false,
          error: e == PurchasesErrorCode.purchaseCancelledError
              ? null
              : 'Purchase failed'));
    } catch (e) {
      emit(state.copyWith(isPurchasing: false, error: e.toString()));
    }
  }

  Future<void> _onPurchasePremium(
      PurchasePremium event, Emitter<SubscriptionState> emit) async {
    emit(state.copyWith(isPurchasing: true, error: null));
    try {
      final offerings = await Purchases.getOfferings();
      final pkg = offerings.current?.availablePackages
          .firstWhere((p) => p.storeProduct.identifier == _premiumProductId);
      if (pkg == null) throw Exception('Product not found');
      final result = await Purchases.purchasePackage(pkg);
      emit(state.copyWith(
          plan: _planFromInfo(result.customerInfo), status: 'active', isPurchasing: false));
    } on PurchasesErrorCode catch (e) {
      emit(state.copyWith(
          isPurchasing: false,
          error: e == PurchasesErrorCode.purchaseCancelledError
              ? null
              : 'Purchase failed'));
    } catch (e) {
      emit(state.copyWith(isPurchasing: false, error: e.toString()));
    }
  }

  Future<void> _onRestore(
      RestorePurchases event, Emitter<SubscriptionState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final info = await Purchases.restorePurchases();
      emit(state.copyWith(plan: _planFromInfo(info), isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Restore failed'));
    }
  }

  String _planFromInfo(CustomerInfo info) {
    if (info.entitlements.active.containsKey('premium')) return 'premium';
    if (info.entitlements.active.containsKey('pro')) return 'pro';
    return 'free';
  }
}
