 class singletonSession {

  // Private constructor for singleton
  singletonSession._internal();

  // Singleton instance
  static final singletonSession _instance = singletonSession._internal();

  // Factory constructor to return the same instance
  factory singletonSession() {
    return _instance;
  }

  // Shared variable for userId
  int? userId;

 
}
