class ProductTaxonomy {
  static const Map<String, List<String>> categories = {
    'Mobile': [
      'Smartphone',
      'Feature Phone',
      'Charger',
      'Cable',
      'Power Bank',
      'Case & Cover',
      'Screen Protector',
      'Other Mobile Accessories',
    ],
    'Computer': [
      'Laptop',
      'Desktop',
      'Monitor',
      'Keyboard',
      'Mouse',
      'Printer',
      'Storage Device',
      'Laptop Accessories',
      'Other Computer Accessories',
    ],
    'Audio': [
      'Headphone',
      'Earbuds',
      'Speaker',
      'Microphone',
      'Soundbar',
      'Other Audio Devices',
    ],
    'Wearable': [
      'Smart Watch',
      'Fitness Band',
      'VR Headset',
      'Other Wearables',
    ],
    'Gaming': [
      'Gaming Console',
      'Controller',
      'Gaming Headset',
      'Gaming Keyboard',
      'Gaming Mouse',
      'Other Gaming Accessories',
    ],
    'Camera': [
      'DSLR',
      'Mirrorless Camera',
      'Action Camera',
      'Webcam',
      'Tripod',
      'Camera Accessories',
    ],
    'Networking': [
      'Router',
      'Modem',
      'Range Extender',
      'Network Switch',
      'Other Networking Devices',
    ],
    'Smart Device': [
      'Smart Bulb',
      'Smart Plug',
      'Smart Security Camera',
      'Smart Doorbell',
      'Smart Home Hub',
      'Other Smart Devices',
    ],
  };

  static List<String> get categoryList => categories.keys.toList();

  static List<String> subcategoriesFor(String category) {
    return categories[category] ?? const [];
  }

  static String defaultCategory() {
    return categoryList.first;
  }

  static String defaultSubcategoryFor(String category) {
    final subcategories = subcategoriesFor(category);
    if (subcategories.isEmpty) return 'Other';
    return subcategories.first;
  }
}