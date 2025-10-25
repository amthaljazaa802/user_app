// lib/screens/complaints/complaints_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/complaints_bloc.dart';

// هذا الكلاس يبقى كما هو، مسؤول عن توفير الـ BLoC
class ComplaintsScreen extends StatelessWidget {
  const ComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ComplaintsBloc(),
      child: const ComplaintsView(),
    );
  }
}

// هذا الكلاس يبقى كما هو، مسؤول عن إنشاء الحالة
class ComplaintsView extends StatefulWidget {
  const ComplaintsView({super.key});

  @override
  State<ComplaintsView> createState() => _ComplaintsViewState();
}

// --- هنا قمنا بإعادة كتابة وتصحيح كل شيء ---
class _ComplaintsViewState extends State<ComplaintsView> {
  // كل المتغيرات والدوال الأصلية تبقى كما هي
  final _formKey = GlobalKey<FormState>();
  final _detailsController = TextEditingController();
  final _busInfoController = TextEditingController();
  final _contactInfoController = TextEditingController();

  String? _selectedComplaintType;

  final List<String> _complaintTypes = [
    'سلوك السائق',
    'تأخر الحافلة',
    'نظافة الحافلة',
    'قيادة متهورة',
    'مشكلة في مسار الخط',
    'أخرى',
  ];

  void _submitComplaint() {
    if (!_formKey.currentState!.validate()) return;
    context.read<ComplaintsBloc>().add(
      ComplaintSubmitted(
        type: _selectedComplaintType!,
        details: _detailsController.text,
        busInfo: _busInfoController.text,
        contactInfo: _contactInfoController.text,
      ),
    );
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _busInfoController.dispose();
    _contactInfoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // BlocListener يبقى في الخارج للتعامل مع الأحداث
    return BlocListener<ComplaintsBloc, ComplaintsState>(
      listener: (context, state) {
        if (state is ComplaintSubmissionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('شكرًا لك، تم استلام ملاحظتك بنجاح.'),
              backgroundColor: Colors.green,
            ),
          );
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.of(context).pop();
          });
        }
        if (state is ComplaintSubmissionFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('حدث خطأ: ${state.errorMessage}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // الـ AppBar الديناميكي
            SliverAppBar(
              pinned: true,
              floating: true,
              expandedHeight: 120.0,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'تقديم شكوى',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
                centerTitle: true,
                titlePadding: const EdgeInsets.only(bottom: 16.0),
              ),
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0.5,
              foregroundColor: Theme.of(context).iconTheme.color,
            ),

            // محتوى النموذج
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // كل حقول النموذج القديمة كما هي
                      DropdownButtonFormField<String>(
                        initialValue:
                            _selectedComplaintType, // <-- تم الإصلاح هنا
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'اختر نوع الشكوى',
                        ),
                        items: _complaintTypes
                            .map(
                              (type) => DropdownMenuItem<String>(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedComplaintType = value),
                        validator: (value) =>
                            value == null ? 'الرجاء اختيار نوع الشكوى' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _detailsController,
                        decoration: const InputDecoration(
                          labelText: 'تفاصيل الشكوى',
                          hintText: 'الرجاء وصف المشكلة بالتفصيل...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 5,
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'هذا الحقل مطلوب'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _busInfoController,
                        decoration: const InputDecoration(
                          labelText: 'معلومات الحافلة / الخط (اختياري)',
                          hintText: 'مثال: خط الجامعة، حافلة رقم 5',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _contactInfoController,
                        decoration: const InputDecoration(
                          labelText: 'معلومات التواصل (اختياري)',
                          hintText: 'رقم هاتف أو بريد إلكتروني',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 32),
                      BlocBuilder<ComplaintsBloc, ComplaintsState>(
                        builder: (context, state) {
                          if (state is ComplaintSubmissionInProgress) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          return ElevatedButton.icon(
                            onPressed: _submitComplaint,
                            icon: const Icon(Icons.send),
                            label: const Text('إرسال'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(fontSize: 18),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
