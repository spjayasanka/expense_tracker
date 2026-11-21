class DefaultCategory {
  const DefaultCategory(this.name, this.icon, this.color);
  final String name;
  final String icon;
  final int color;
}

const kDefaultExpenseCategories = [
  DefaultCategory('Food', 'restaurant', 0xFFE53935),
  DefaultCategory('Transport', 'directions_bus', 0xFF1E88E5),
  DefaultCategory('Bills', 'receipt_long', 0xFF5E35B1),
  DefaultCategory('Shopping', 'shopping_bag', 0xFFD81B60),
  DefaultCategory('Health', 'local_hospital', 0xFF00897B),
  DefaultCategory('Entertainment', 'movie', 0xFFFB8C00),
  DefaultCategory('Education', 'school', 0xFF3949AB),
  DefaultCategory('Home', 'home', 0xFF6D4C41),
  DefaultCategory('Gifts', 'card_giftcard', 0xFF8E24AA),
  DefaultCategory('Car', 'directions_car', 0xFF546E7A),
  DefaultCategory('Eating out', 'local_cafe', 0xFFF4511E),
  DefaultCategory('Personal care', 'spa', 0xFF43A047),
];

const kDefaultIncomeCategories = [
  DefaultCategory('Salary', 'payments', 0xFF2E7D32),
  DefaultCategory('Business', 'business_center', 0xFF00695C),
  DefaultCategory('Gifts', 'redeem', 0xFF6A1B9A),
  DefaultCategory('Other', 'savings', 0xFF039BE5),
];
