class propertyFeedbacks {
  late int? id;
  late int property_id;
  late String feedback;
  late int? user_id;

  
  propertyFeedbacks({
    this.id,
    required this.property_id,
    required this.feedback,
    this.user_id, 
  });

  factory propertyFeedbacks.fromJson(Map<String, dynamic> json) {
    return propertyFeedbacks(
      id: json['id'],
      property_id: json['property_id'],
      feedback: json['feedback'],
      user_id: json['user_id'],
    );
  }
}
