import 'package:flutter/material.dart';
import 'package:gradproj/Controllers/oodo_rpc_controller.dart';

class Feedbacktest extends StatefulWidget {
  const Feedbacktest({Key? key}) : super(key: key);

  @override
  _FeedbacktestState createState() => _FeedbacktestState();
}

class _FeedbacktestState extends State<Feedbacktest> {
  final OdooRPCController _odooRPCController = OdooRPCController();
  bool _isLoading = false;

  Future<void> _submitTestFeedback() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // First, check the connection to the Odoo server.
      bool isConnected = await _odooRPCController.checkConnection();
      if (!isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to connect to the Odoo server.")),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // If connected, submit the test feedback.
      bool submitted = await _odooRPCController.submitTestFeedback();

      if (submitted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Test feedback submitted successfully!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to submit test feedback.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Feedback Test"),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submitTestFeedback,
          child: Text(_isLoading ? "Submitting..." : "Submit Test Feedback to Odoo"),
        ),
      ),
    );
  }
}
