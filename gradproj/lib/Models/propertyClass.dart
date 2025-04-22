class Property {
  late int id; 
  late String type;
  late int price;
  late int bedrooms;
  late int bathrooms;
  late int area;
  late String furnished;
  late int? level;
  late String? compound;
  late String paymentOption;
  late String sale_rent;
  late String city;
  late int? userId;
  late List<String>? imgUrl;
  late String ?status ;
late double ?similarityScore;
late double ?downPayment;
late int ?installmentYears;
late int ?deliveryIn;
late String ?finishing;

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
    required this.sale_rent,
    this.userId,
    this.imgUrl,
     this.status, 
     this.similarityScore,
     this.downPayment,
     this.installmentYears,
     this.deliveryIn,
     this.finishing
  });

factory Property.fromJson(Map<String, dynamic> json) {
  return Property(
    id: json['id'] as int,
    status : json['status'] as String ,
    type: json['type'] as String,
    price: (json['price'] as num).toInt(),
    bedrooms: (json['bedrooms'] as num).toInt(),
    bathrooms: (json['bathrooms'] as num).toInt(),
    area: (json['area'] as num).toInt(),
    furnished: json['furnished'] as String,
    sale_rent: json['sale_rent'] !=null ? json['sale_rent'] as String : "",
    level: json['level'] != null ? (json['level'] as num).toInt() : null,
    compound: json['compound'] as String?,
    paymentOption: json['payment_option'] as String,
    city: json['city'] as String,
    userId: json['user_id'] as int?,
    imgUrl: json['img_url'] != null
        ? (json['img_url'] as List<dynamic>).map((e) => e.toString()).toList()
        : [], 
    similarityScore: (json['similarity_score'] as num?)?.toDouble() ?? 0.0,
    downPayment: json['down_payment'] != null 
        ? (json['down_payment'] is num 
            ? (json['down_payment'] as num).toDouble() 
            : double.tryParse(json['down_payment'].toString()) ?? 0.0)
        : null,
    installmentYears: json['installment_years'] != null 
        ? (json['installment_years'] is num 
            ? (json['installment_years'] as num).toInt() 
            : int.tryParse(json['installment_years'].toString()))
        : null,
    deliveryIn: json['delivery_in'] != null 
        ? (json['delivery_in'] is num 
            ? (json['delivery_in'] as num).toInt() 
            : int.tryParse(json['delivery_in'].toString()))
        : null,
    finishing: json['finishing'] != null ? json['finishing'] as String : "unknown",
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
    'user_id':userId,
    'id':id,
    'sale_rent' :sale_rent
  };
}
String test = 't';
}