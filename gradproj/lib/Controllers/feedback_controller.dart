import 'package:gradproj/Models/Feedback.dart';
import 'package:gradproj/Models/property.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FeedbackController {
  final SupabaseClient supabase;

  FeedbackController({required this.supabase});

  Future<List<propertyFeedbacks>> getFeedbacksByProperty(int propertyId) async {
    try {
      final response = await supabase
          .from('feedbacks')
          .select('*')
          .eq('property_id', propertyId)
          .order('created_at', ascending: false);

      return response
          .map((f) => propertyFeedbacks(
                property_id: f['property_id'],
                feedback: f['feedback'],
                user_id: f['user_id'],
              ))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<String> getMailOfFeedbacker(int user_id) async {
    try {
      final response =
          await supabase.from('users').select('email').eq('id', user_id);

      return response.toString();
    } catch (e) {
      rethrow;
    }
  }
Future<void> addFeedback(
    int propertyId, String feedbackText, String? userId) async {
  try {
    await supabase.from('feedbacks').insert({
      'property_id': propertyId,
      'feedback': feedbackText,
      'user_id': userId,
    });
  } catch (e) {
    rethrow;
  }
}

}
