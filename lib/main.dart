import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: 'assets/.env');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Initialization successful');
  } catch (e) {
    debugPrint('Initialization error: $e');
  }
  runApp(const HealthAccessApp());
}

class HealthAccessApp extends StatelessWidget {
  const HealthAccessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HealthBridge AI',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
      home: const SymptomInputScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SymptomInputScreen extends StatefulWidget {
  const SymptomInputScreen({super.key});

  @override
  State<SymptomInputScreen> createState() => _SymptomInputScreenState();
}

class _SymptomInputScreenState extends State<SymptomInputScreen> {
  final TextEditingController _symptomController = TextEditingController();
  String _diagnosis = '';
  String _recommendations = '';
  bool _isLoading = false;
  Position? _currentPosition;
  String _errorMessage = '';
  bool _showDiagnosis = false;
  bool _showRecommendations = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() => _currentPosition = position);
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  Future<void> _analyzeSymptoms() async {
    if (_symptomController.text.isEmpty) {
      setState(() => _errorMessage = "Please enter your symptoms");
      return;
    }

    setState(() {
      _isLoading = true;
      _diagnosis = '';
      _recommendations = '';
      _errorMessage = '';
      _showDiagnosis = false;
      _showRecommendations = false;
    });

    try {
      final model = GenerativeModel(
        // Update this line:
        model: 'gemini-1.5-pro-latest',  // New model name
        apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
      );

      // Diagnosis prompt with improved instructions
      final diagnosisResponse = await model.generateContent([
        Content.text("Act as a medical expert. Based on these symptoms: ${_symptomController.text}\n\n"
            "Provide:\n1. Possible conditions (list 2-3 most likely)\n"
            "2. Brief explanation in simple terms\n"
            "3. Red flags to watch for\n\n"
            "Keep response under 150 words and format with bullet points.")
      ]);

      // Recommendations prompt with location context
      String locationContext = _currentPosition != null
          ? "User is located at ${_currentPosition!.latitude.toStringAsFixed(4)}, "
              "${_currentPosition!.longitude.toStringAsFixed(4)}. "
          : "";
      
      final recommendationResponse = await model.generateContent([
        Content.text("For someone with these symptoms: ${_symptomController.text}\n"
            "$locationContext\n\n"
            "Provide:\n1. Immediate self-care advice\n"
            "2. When to seek medical help\n"
            "3. Recommended healthcare facilities\n"
            "4. Prevention tips\n\n"
            "Format with clear sections and keep under 200 words.")
      ]);

      setState(() {
        _diagnosis = diagnosisResponse.text ?? 'Could not determine diagnosis';
        _recommendations = recommendationResponse.text ?? 'No recommendations available';
        _showDiagnosis = true;
        _showRecommendations = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error: ${e.toString().replaceAll('Exception:', '').trim()}";
        if (_errorMessage.contains('API_KEY')) {
          _errorMessage = "Invalid API key. Please check your configuration.";
        }
      });
      debugPrint("API Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HealthBridge AI', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAboutDialog(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Symptom Input Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Describe Your Symptoms',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _symptomController,
                      decoration: InputDecoration(
                        hintText: 'E.g., fever, headache, cough for 3 days',
                        suffixIcon: Icon(Icons.medical_services, color: Colors.blue[300]),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      ),
                      maxLines: 3,
                    ),
                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _errorMessage,
                          style: TextStyle(color: Colors.red[700], fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Analyze Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _analyzeSymptoms,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white),
                      )
                    : const Text('Analyze Symptoms',
                        style: TextStyle(fontSize: 16)),
              ),
            ),

            const SizedBox(height: 16),

            // Results Section
            if (_showDiagnosis || _showRecommendations)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (_showDiagnosis)
                        _buildResultCard(
                          title: 'Possible Diagnosis',
                          content: _diagnosis,
                          icon: Icons.medical_information,
                          color: Colors.blue[50]!,
                        ),

                      if (_showRecommendations)
                        _buildResultCard(
                          title: 'Recommendations',
                          content: _recommendations,
                          icon: Icons.assignment,
                          color: Colors.green[50]!,
                        ),

                      if (_currentPosition != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Location: ${_currentPosition!.latitude.toStringAsFixed(4)}, '
                            '${_currentPosition!.longitude.toStringAsFixed(4)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About HealthBridge AI'),
        content: const Text(
          'This app helps users in underserved communities get preliminary '
          'health assessments and find nearby healthcare solutions.\n\n'
          'Note: This is not a substitute for professional medical advice.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _symptomController.dispose();
    super.dispose();
  }
}