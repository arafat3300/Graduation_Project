class Property {
  late String id;
  late String imgUrl;
  late String name;
  late String description;
  late String feedback;
  late String city;
  late int rooms;
  late int toilets;
  late int? floor;
  late double sqft;
  late double price;
  late List amenities ; 

  Property(
    {
    required this.id,
    required this.name,
    required this.description,
    required this.feedback,
    required this.city,
    required this.rooms,
    required this.toilets,
    required this.floor,
    required this.sqft,
    required this.price,
    required this.amenities,
    required this.imgUrl
  }
  );
}
