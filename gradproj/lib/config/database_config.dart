import 'package:postgres/postgres.dart';

class DatabaseConfig {
  // Network settings
  static const String host = '192.168.1.12';  // Your laptop's actual IP address
  static const int port = 5432;  // Standard PostgreSQL port
  
  // Database settings
  static const String databaseName = 'odoo18v3';
  static const String username = 'postgres';
  static const String password = 'postgres';  // PostgreSQL password
  
  // Connection settings
  static const int maxConnections = 5;
  static const Duration connectionTimeout = Duration(seconds: 10);
  
  // SSL Mode
  static const bool useSSL = false;
  
  // Static connection instance
  static PostgreSQLConnection? _connection;
  
  // Get shared connection instance
  static Future<PostgreSQLConnection> getConnection() async {
    if (_connection == null || _connection!.isClosed) {
      _connection = PostgreSQLConnection(
        host,
        port,
        databaseName,
        username: username,
        password: password,
        timeoutInSeconds: connectionTimeout.inSeconds,
        useSSL: useSSL,
        allowClearTextPassword: true  // Force encrypted password
      );
      await _connection!.open();
    }
    return _connection!;
  }
  
  // Connection string for debugging (properly escaped)
  static String get connectionString => 
    'postgresql://$username:${Uri.encodeComponent(password)}@$host:$port/$databaseName?sslmode=disable';
} 

// DON'T DELETE THIS COMMENTTTTT
// SELECT setval(
//   'real_estate_recommendedpropertiesdetails_id_seq',
//   (SELECT COALESCE(MAX(id), 0) FROM public.real_estate_recommendedpropertiesdetails)
// );
