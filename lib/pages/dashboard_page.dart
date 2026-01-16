
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _totalProjects = 0;
  int _certificatesGenerated = 0;
  int _aiRequests = 0;
  
  // Weekly data (simulated for now, could be persisted as detailed log)
  List<int> _projectCounts = [0, 0, 0, 0, 0, 0, 0]; 

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _totalProjects = prefs.getInt('total_projects') ?? 0;
      _certificatesGenerated = prefs.getInt('certificates_generated') ?? 0;
      _aiRequests = prefs.getInt('ai_requests') ?? 0;
      
      // For now, let's just make the chart dynamic based on total
      // In real implementation, we'd store daily logs.
      // This is a placeholder visual for "Last 7 Days"
      if (_totalProjects > 0) {
        _projectCounts = [2, 1, 4, 2, 5, 1, 3]; // Mock data for demo visual
        // Scale mock data roughly to total or just show static pattern for "Activity"
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        title: const Text('Project Analytics'),
        backgroundColor: const Color(0xFF1E1E2E),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overview',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                
                if (isMobile) {
                  return Column(
                    children: [
                      Row(children: [_buildKpiCard('Projects', '$_totalProjects', Colors.blueAccent, Icons.folder)]),
                      const SizedBox(height: 12),
                      Row(children: [_buildKpiCard('Certificates', '$_certificatesGenerated', Colors.greenAccent, Icons.workspace_premium)]),
                      const SizedBox(height: 12),
                      Row(children: [_buildKpiCard('AI Requests', '$_aiRequests', Colors.purpleAccent, Icons.smart_toy)]),
                      const SizedBox(height: 12),
                      Row(children: [_buildKpiCard('Storage', '12 MB', Colors.orangeAccent, Icons.sd_storage)]),
                    ],
                  );
                }
                
                return Column(
                   children: [
                      Row(
                        children: [
                          _buildKpiCard('Projects', '$_totalProjects', Colors.blueAccent, Icons.folder),
                          _buildKpiCard('Certificates', '$_certificatesGenerated', Colors.greenAccent, Icons.workspace_premium),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildKpiCard('AI Requests', '$_aiRequests', Colors.purpleAccent, Icons.smart_toy),
                          _buildKpiCard('Storage', '12 MB', Colors.orangeAccent, Icons.sd_storage),
                        ],
                      ),
                   ],
                );
              }
            ),
            const SizedBox(height: 40),
            const Text(
              'Activity (Last 7 Days)',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Container(
              height: 250,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A3D),
                borderRadius: BorderRadius.circular(16),
              ),
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                     leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                     topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                     rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                     bottomTitles: AxisTitles(
                       sideTitles: SideTitles(
                         showTitles: true,
                         getTitlesWidget: (val, meta) {
                            const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                            if (val.toInt() >= 0 && val.toInt() < 7) {
                               return Text(days[val.toInt()], style: const TextStyle(color: Colors.white54));
                            }
                            return const SizedBox.shrink();
                         }
                       ),
                     ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _projectCounts.asMap().entries.map((e) {
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: e.value.toDouble(),
                            color: Colors.blueAccent,
                            width: 16,
                            borderRadius: BorderRadius.circular(4),
                          )
                        ]
                      );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A3D),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
             BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
          ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
