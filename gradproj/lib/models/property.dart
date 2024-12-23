class Property {
  late int id; 
  late String type;
  late double price;
  late int bedrooms;
  late int bathrooms;
  late int area;
  late String furnished;
  late int? level;
  late String? compound;
  late String paymentOption;
  late String city;
  late List<String> feedback;
  late String? imgUrl;

  Property({
    required this.id,
    required this.type,
    required this.price,
    required this.bedrooms,
    required this.bathrooms,
    required this.area,
    required this.furnished,
    this.level,
    this.compound,
    required this.paymentOption,
    required this.city,
    required this.feedback,
    this.imgUrl,
  });

  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: json['id'], 
      type: json['type'],
      price: (json['price'] as num).toDouble(), 
      bedrooms: json['bedrooms'],
      bathrooms: json['bathrooms'],
      area: json['area'],
      furnished: json['furnished'],
      level: json['level'],
      compound: json['compound'],
      paymentOption: json['payment_option'],
      city: json['city'],
      feedback: (json['feedback'] as List<dynamic>).cast<String>(),
      imgUrl: json['img_url'], 
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'price': price,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'area': area,
      'furnished': furnished,
      'level': level,
      'compound': compound,
      'payment_option': paymentOption,
      'city': city,
      'feedback': feedback,
      'img_url': imgUrl,
    };
  }
}
