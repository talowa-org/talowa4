// Analytics Chart Widget for TALOWA
// Implements Task 23: Implement content analytics - Chart Visualization

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

enum ChartType { line, bar, pie }

class ChartDataPoint {
  final DateTime x;
  final double y;
  final String? label;

  ChartDataPoint({
    required this.x,
    required this.y,
    this.label,
  });
}

class AnalyticsChartWidget extends StatelessWidget {
  final List<ChartDataPoint> data;
  final ChartType chartType;
  final String? title;
  final Color? primaryColor;
  final bool showGrid;
  final bool showLabels;

  const AnalyticsChartWidget({
    super.key,
    required this.data,
    required this.chartType,
    this.title,
    this.primaryColor,
    this.showGrid = true,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = primaryColor ?? Theme.of(context).primaryColor;

    switch (chartType) {
      case ChartType.line:
        return _buildLineChart(color);
      case ChartType.bar:
        return _buildBarChart(color);
      case ChartType.pie:
        return _buildPieChart(color);
    }
  }

  Widget _buildLineChart(Color color) {
    if (data.isEmpty) return _buildEmptyChart();

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: showGrid),
        titlesData: FlTitlesData(
          show: showLabels,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < data.length) {
                  final date = data[index].x;
                  return Text(
                    '${date.day}/${date.month}',
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatYAxisValue(value),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value.y);
            }).toList(),
            isCurved: true,
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.2),
            ),
          ),
        ],
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: data.map((e) => e.y).reduce((a, b) => a < b ? a : b) * 0.9,
        maxY: data.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.1,
      ),
    );
  }

  Widget _buildBarChart(Color color) {
    if (data.isEmpty) return _buildEmptyChart();

    return BarChart(
      BarChartData(
        gridData: FlGridData(show: showGrid),
        titlesData: FlTitlesData(
          show: showLabels,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < data.length) {
                  final date = data[index].x;
                  return Text(
                    '${date.hour}:00',
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatYAxisValue(value),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        barGroups: data.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.y,
                color: color,
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
        maxY: data.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.1,
      ),
    );
  }

  Widget _buildPieChart(Color color) {
    if (data.isEmpty) return _buildEmptyChart();

    return PieChart(
      PieChartData(
        sections: data.asMap().entries.map((entry) {
          final colors = [
            color,
            color.withValues(alpha: 0.2),
            color.withValues(alpha: 0.2),
            color.withValues(alpha: 0.2),
            color.withValues(alpha: 0.2),
          ];
          
          return PieChartSectionData(
            value: entry.value.y,
            title: entry.value.label ?? '${entry.value.y.round()}',
            color: colors[entry.key % colors.length],
            radius: 60,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }

  Widget _buildEmptyChart() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'No data available',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  String _formatYAxisValue(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return value.toInt().toString();
    }
  }
}

// Specialized chart widgets for different analytics

class EngagementTrendChart extends StatelessWidget {
  final List<ChartDataPoint> data;
  final String title;

  const EngagementTrendChart({
    super.key,
    required this.data,
    this.title = 'Engagement Trend',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: AnalyticsChartWidget(
                data: data,
                chartType: ChartType.line,
                primaryColor: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HourlyActivityChart extends StatelessWidget {
  final List<ChartDataPoint> data;
  final String title;

  const HourlyActivityChart({
    super.key,
    required this.data,
    this.title = 'Hourly Activity',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: AnalyticsChartWidget(
                data: data,
                chartType: ChartType.bar,
                primaryColor: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DemographicsChart extends StatelessWidget {
  final Map<String, int> demographics;
  final String title;

  const DemographicsChart({
    super.key,
    required this.demographics,
    this.title = 'Demographics',
  });

  @override
  Widget build(BuildContext context) {
    final data = demographics.entries.map((entry) {
      return ChartDataPoint(
        x: DateTime.now(),
        y: entry.value.toDouble(),
        label: entry.key,
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: AnalyticsChartWidget(
                data: data,
                chartType: ChartType.pie,
                primaryColor: Colors.purple,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Real-time chart that updates automatically
class RealTimeChart extends StatefulWidget {
  final Stream<List<ChartDataPoint>> dataStream;
  final String title;
  final ChartType chartType;
  final Color? color;

  const RealTimeChart({
    super.key,
    required this.dataStream,
    required this.title,
    this.chartType = ChartType.line,
    this.color,
  });

  @override
  State<RealTimeChart> createState() => _RealTimeChartState();
}

class _RealTimeChartState extends State<RealTimeChart> {
  List<ChartDataPoint> _data = [];

  @override
  void initState() {
    super.initState();
    widget.dataStream.listen((data) {
      if (mounted) {
        setState(() {
          _data = data;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.green[600],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: AnalyticsChartWidget(
                data: _data,
                chartType: widget.chartType,
                primaryColor: widget.color ?? Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

