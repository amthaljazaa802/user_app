import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../repositories/transport_repository.dart';
import '../map/map_screen.dart';
import 'bloc/routes_bloc.dart';

// هذا الجزء يبقى كما هو، مسؤول عن توفير الـ BLoC
class RoutesScreen extends StatelessWidget {
  const RoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          RoutesBloc(repository: context.read<TransportRepository>())
            ..add(LoadRoutes()),
      child: const RoutesView(), // الواجهة الفعلية تأتي من هنا
    );
  }
}

// --- هنا قمنا بتطبيق كل التعديلات على تصميم الواجهة ---
class RoutesView extends StatelessWidget {
  const RoutesView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutesBloc, RoutesState>(
      builder: (context, state) {
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                floating: true,
                expandedHeight: 120.0,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    'خطوط النقل',
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
              // عرض المحتوى بناءً على الحالة
              _buildSliverContent(context, state),
            ],
          ),
        );
      },
    );
  }

  // دالة مساعدة جديدة لعرض المحتوى داخل CustomScrollView
  Widget _buildSliverContent(BuildContext context, RoutesState state) {
    if (state is RoutesInitial) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state is RoutesLoadSuccess) {
      final busLines = state.busLines;

      if (busLines.isEmpty) {
        return const SliverFillRemaining(
          child: Center(child: Text('لا توجد خطوط متاحة حاليًا.')),
        );
      }

      return SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final line = busLines[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: const Icon(Icons.route, color: Colors.orange),
              title: Text(
                line.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(line.description),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => MapScreen(lineId: line.id)),
                );
              },
            ),
          );
        }, childCount: busLines.length),
      );
    }

    if (state is RoutesLoadFailure) {
      return SliverFillRemaining(
        child: Center(child: Text('فشل تحميل الخطوط: ${state.errorMessage}')),
      );
    }

    return const SliverFillRemaining(
      child: Center(child: Text('حدث خطأ غير متوقع')),
    );
  }
}
