String formatCurrency(double cents, {bool showCents = false}) {
  if (showCents) {
    return '${cents.toStringAsFixed(0)}¢';
  }
  return '${(cents / 100).toStringAsFixed(2)}€';
} 