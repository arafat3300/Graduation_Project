class Property {
  late int? id; 
  late String type;
  late int price;
  late int bedrooms;
  late int bathrooms;
  late int area;
  late String furnished;
  late int? level;
  late String? compound;
  late String paymentOption;
  late String city;
  late int? userId ;
  late List<String>? imgUrl;
  late String ?status ;

  Property({
    this.id,
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
this.userId,
    this.imgUrl,
     this.status,
  });

factory Property.fromJson(Map<String, dynamic> json) {
  return Property(
    id: json['id'] as int?,
    status : json['status'] as String ,
    type: json['type'] as String,
    price: (json['price'] as num).toInt(),
    bedrooms: (json['bedrooms'] as num).toInt(),
    bathrooms: (json['bathrooms'] as num).toInt(),
    area: (json['area'] as num).toInt(),
    furnished: json['furnished'] as String,
    level: json['level'] != null ? (json['level'] as num).toInt() : null,
    compound: json['compound'] as String?,
    paymentOption: json['payment_option'] as String,
    city: json['city'] as String,
  userId:json['user_id'] != null ? (json['user_id'] as num).toInt() : null,
    imgUrl: json['img_url'] != null
        ? (json['img_url'] as List<dynamic>).map((e) => e.toString()).toList()
        : [], 
  );
}



Map<String, dynamic> toJson() {
  return {
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
    'img_url': imgUrl,
    'user_id' : userId,
  };
}

}