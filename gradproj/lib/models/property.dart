
class Property {
  late String id;
  late String imgUrl;
  late String type;
  late String name;
  late String description;
  late List<String> feedback;
  late String city;
  late int rooms;
  late int toilets;
  late int? floor;
  late double sqft;
  late double price;
  late List<String>? amenities ;
  late String rentOrSale; 
  late String location;
  late String street;

  Property(
    {
   
    required this.name,
    required this.description,
    required this.feedback,
    required this.type,
    required this.city,
    required this.rooms,
    required this.toilets,
    required this.floor,
    required this.sqft,
    required this.price,
     this.amenities,
    required this.imgUrl,
    required this.rentOrSale,
    required this.location,
    required this.street,
    required this.id
  }
  );

  
}
