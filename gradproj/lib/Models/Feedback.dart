class propertyFeedbacks {
  late int? id;
  late int property_id;
  late String feedback;
  late int? user_id;
  String? email; // for UI only, not saved to DB


  
  propertyFeedbacks({
    this.id,
    required this.property_id,
    required this.feedback,
    this.user_id, 
    this.email,
  });

  factory propertyFeedbacks.fromJson(Map<String, dynamic> json) {
    return propertyFeedbacks(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      property_id: int.tryParse(json['property_id'].toString()) ?? 0,
      feedback: json['feedback'] as String,
      user_id: json['user_id'] != null ? int.tryParse(json['user_id'].toString()) : null,
    );
  }
}
