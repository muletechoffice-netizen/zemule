import 'package:flutter_test/flutter_test.dart';
import 'package:zemule/utils/colors.dart';

void main() {
  test('AppColors exposes expected light primary color', () {
    expect(AppColors.primaryLight.toARGB32(), 0xFF1E3A8A);
  });
}
