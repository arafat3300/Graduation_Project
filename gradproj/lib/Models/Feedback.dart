class propertyFeedbacks {
  late int? id;
  late int property_id;
  late String feedback;
  late int? user_id;

  propertyFeedbacks({
    required this.property_id,
    required this.feedback,
    this.user_id, 
  });
}
