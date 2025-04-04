class DatabaseConfig {
  static const String host = '172.20.10.1';
  static const int port = 5432;  // Explicitly set PostgreSQL port
  static const String database = 'odoo18v3';
  static const String username = 'postgres';
  static const String password = 'postgress@192';
  static const int maxConnections = 10;
  static const Duration connectionTimeout = Duration(seconds: 30);
} 