import 'package:flutter/material.dart';

enum CategoryKind { expense, income, bill }

class IconChoice {
  const IconChoice(this.id, this.label, this.icon, this.color);
  final String id, label;
  final IconData icon;
  final Color color;
}

// Keep the first six positions stable for bills saved by earlier app versions.
const categoryIcons = [
  IconChoice('internet', 'Internet', Icons.language_rounded, Color(0xFF087BFF)),
  IconChoice(
    'electricity',
    'Electricity',
    Icons.bolt_rounded,
    Color(0xFFFF9A1F),
  ),
  IconChoice('water', 'Water', Icons.water_drop_rounded, Color(0xFF087BFF)),
  IconChoice('streaming', 'Streaming', Icons.movie_rounded, Color(0xFFFF426B)),
  IconChoice('phone', 'Phone', Icons.phone_android_rounded, Color(0xFF5366FF)),
  IconChoice('rent', 'Rent', Icons.home_work_rounded, Color(0xFFFF8C32)),
  IconChoice('food', 'Food', Icons.ramen_dining_rounded, Color(0xFFFF5C83)),
  IconChoice('social', 'Social Life', Icons.people_rounded, Color(0xFFEA7A50)),
  IconChoice('pets', 'Pets', Icons.pets_rounded, Color(0xFFB67D4C)),
  IconChoice(
    'transport',
    'Transport',
    Icons.directions_bus_rounded,
    Color(0xFF57CFBA),
  ),
  IconChoice('culture', 'Culture', Icons.museum_rounded, Color(0xFF9A77CF)),
  IconChoice('household', 'Household', Icons.chair_rounded, Color(0xFFC77D4B)),
  IconChoice('apparel', 'Apparel', Icons.checkroom_rounded, Color(0xFFCE9645)),
  IconChoice(
    'beauty',
    'Beauty',
    Icons.face_retouching_natural_rounded,
    Color(0xFFE76B9C),
  ),
  IconChoice('health', 'Health', Icons.favorite_rounded, Color(0xFFFF5C83)),
  IconChoice('education', 'Education', Icons.school_rounded, Color(0xFFFF943B)),
  IconChoice('gift', 'Gift', Icons.card_giftcard_rounded, Color(0xFFE9A52A)),
  IconChoice('other', 'Other', Icons.more_horiz_rounded, Color(0xFF98A1AF)),
  IconChoice(
    'shopping',
    'Shopping',
    Icons.shopping_bag_rounded,
    Color(0xFFFFC56D),
  ),
  IconChoice('salary', 'Salary', Icons.work_rounded, Color(0xFF079D80)),
  IconChoice(
    'freelance',
    'Freelance',
    Icons.laptop_mac_rounded,
    Color(0xFF167BFF),
  ),
  IconChoice(
    'parttime',
    'Part-time',
    Icons.people_alt_rounded,
    Color(0xFFFF4F7F),
  ),
  IconChoice('bonus', 'Bonus', Icons.redeem_rounded, Color(0xFFFF8D24)),
  IconChoice('bills', 'Bills', Icons.receipt_long_rounded, Color(0xFFA48BFA)),
  IconChoice('travel', 'Travel', Icons.flight_rounded, Color(0xFF42A4CB)),
  IconChoice('car', 'Car', Icons.directions_car_rounded, Color(0xFF5484D4)),
  IconChoice(
    'fuel',
    'Fuel',
    Icons.local_gas_station_rounded,
    Color(0xFFE19B38),
  ),
  IconChoice(
    'groceries',
    'Groceries',
    Icons.local_grocery_store_rounded,
    Color(0xFF69AB49),
  ),
  IconChoice('coffee', 'Coffee', Icons.coffee_rounded, Color(0xFF9F7054)),
  IconChoice(
    'fitness',
    'Fitness',
    Icons.fitness_center_rounded,
    Color(0xFF8767C8),
  ),
  IconChoice(
    'insurance',
    'Insurance',
    Icons.health_and_safety_rounded,
    Color(0xFF369F92),
  ),
  IconChoice('savings', 'Savings', Icons.savings_rounded, Color(0xFFE77CA0)),
  IconChoice('baby', 'Baby', Icons.child_friendly_rounded, Color(0xFF7D9DDB)),
  IconChoice('games', 'Games', Icons.sports_esports_rounded, Color(0xFF6687F5)),
  IconChoice('music', 'Music', Icons.music_note_rounded, Color(0xFFB365C8)),
  IconChoice(
    'subscriptions',
    'Subscriptions',
    Icons.subscriptions_rounded,
    Color(0xFFE97653),
  ),
];

class AppCategory {
  const AppCategory(this.name, this.iconId, this.colorValue);
  final String name, iconId;
  final int colorValue;
  int get iconIndex =>
      categoryIcons.indexWhere((choice) => choice.id == iconId);
  IconData get icon => categoryIcons[iconIndex].icon;
  Color get color => Color(colorValue);
  Map<String, dynamic> toJson() => {
    'name': name,
    'icon': iconId,
    'color': colorValue,
  };
}

const defaultExpenseCategories = [
  AppCategory('Food', 'food', 0xFFFF5C83),
  AppCategory('Shopping', 'shopping', 0xFFFFC56D),
  AppCategory('Transportation', 'transport', 0xFF57CFBA),
  AppCategory('Bills', 'bills', 0xFFA48BFA),
  AppCategory('Entertainment', 'games', 0xFF6687F5),
  AppCategory('Others', 'other', 0xFF98A1AF),
  AppCategory('Health', 'health', 0xFFFF5C83),
  AppCategory('Education', 'education', 0xFFFF943B),
  AppCategory('Social Life', 'social', 0xFFEA7A50),
  AppCategory('Pets', 'pets', 0xFFB67D4C),
  AppCategory('Culture', 'culture', 0xFF9A77CF),
  AppCategory('Household', 'household', 0xFFC77D4B),
  AppCategory('Apparel', 'apparel', 0xFFCE9645),
  AppCategory('Beauty', 'beauty', 0xFFE76B9C),
  AppCategory('Gift', 'gift', 0xFFE9A52A),
];
const defaultIncomeCategories = [
  AppCategory('Salary', 'salary', 0xFF079D80),
  AppCategory('Freelance', 'freelance', 0xFF167BFF),
  AppCategory('Part-time', 'parttime', 0xFFFF4F7F),
  AppCategory('Bonus', 'bonus', 0xFFFF8D24),
  AppCategory('Others', 'other', 0xFF98A1AF),
];
const defaultBillCategories = [
  AppCategory('Internet', 'internet', 0xFF087BFF),
  AppCategory('Electricity', 'electricity', 0xFFFF9A1F),
  AppCategory('Water', 'water', 0xFF087BFF),
  AppCategory('Streaming', 'streaming', 0xFFFF426B),
  AppCategory('Phone', 'phone', 0xFF5366FF),
  AppCategory('Rent', 'rent', 0xFFFF8C32),
];
