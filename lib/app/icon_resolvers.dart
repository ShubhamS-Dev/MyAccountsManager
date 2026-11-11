import 'package:flutter/material.dart';

IconData resolveAccountIcon(String? iconKey) {
  switch (iconKey?.trim().toLowerCase()) {
    case 'bank':
    case 'account_balance':
      return Icons.account_balance_rounded;
    case 'cash':
    case 'money':
      return Icons.payments_rounded;
    case 'card':
    case 'credit_card':
      return Icons.credit_card_rounded;
    case 'wallet':
      return Icons.account_balance_wallet_rounded;
    case 'savings':
      return Icons.savings_rounded;
    case 'investment':
      return Icons.trending_up_rounded;
    default:
      return Icons.account_balance_wallet_rounded;
  }
}

IconData resolveCategoryIcon(String? key, {required bool income}) {
  switch (key?.trim().toLowerCase()) {
    case 'food':
    case 'restaurant':
    case 'food_dining':
    case 'food & dining':
      return Icons.restaurant_rounded;
    case 'groceries':
    case 'grocery':
      return Icons.shopping_basket_rounded;
    case 'shopping':
      return Icons.shopping_bag_rounded;
    case 'transport':
    case 'transportation':
      return Icons.directions_car_rounded;
    case 'vehicle':
      return Icons.directions_car_filled_rounded;
    case 'vehicle_maintenance':
    case 'vehicle maintenance':
      return Icons.car_repair_rounded;
    case 'home':
    case 'housing':
    case 'housing_utilities':
    case 'housing & utilities':
      return Icons.home_rounded;
    case 'household':
      return Icons.chair_alt_rounded;
    case 'health':
    case 'medical':
    case 'health_medical':
    case 'health & medical':
      return Icons.medical_services_rounded;
    case 'salary':
    case 'business':
    case 'freelancing':
      return Icons.work_rounded;
    case 'gift':
    case 'family_gifts':
    case 'family & gifts':
    case 'gifts_rewards':
    case 'gifts & rewards':
      return Icons.card_giftcard_rounded;
    case 'education':
      return Icons.school_rounded;
    case 'travel':
    case 'travel_stay':
    case 'travel & stay':
      return Icons.flight_rounded;
    case 'entertainment':
      return Icons.movie_rounded;
    case 'personal_care':
    case 'personal care':
      return Icons.spa_rounded;
    case 'financial_payments':
    case 'financial payments':
    case 'payments':
      return Icons.account_balance_wallet_rounded;
    case 'donations':
      return Icons.volunteer_activism_rounded;
    case 'investments':
    case 'investment':
      return Icons.trending_up_rounded;
    case 'rental_income':
      return Icons.key_rounded;
    case 'refunds':
      return Icons.currency_exchange_rounded;
    case 'others':
      return Icons.category_rounded;
    default:
      return income ? Icons.south_west_rounded : Icons.north_east_rounded;
  }
}
