// import 'dart:math';

import 'package:bubble_chart/bubble_chart.dart';
import 'package:flutter/material.dart';
import 'package:oro_ticket_app/core/constants/colors.dart';
import 'package:oro_ticket_app/core/constants/typography.dart';



class AppGraphs {
  // Default bubble chart configuration
  static BubbleChartLayout defaultChartLayout({
    required List<BubbleNode> children,
    Duration duration = const Duration(milliseconds: 800),
  }) {
    return BubbleChartLayout(
      children: children,
      duration: duration,
    );
  }

  // Dashboard specific bubbles
  static List<BubbleNode> get dashboardBubbles {
    return [
      BubbleNode.node(
        padding: 5,
        children: [
          BubbleNode.leaf(
            value: 50,
            options: BubbleOptions(
              child: Text(
                '50%',
                style: AppTextStyles.buttonSmall,
              ),
              color: AppColors.success,
              onTap: () => print('Main bubble tapped'),
            ),
          ),
          BubbleNode.leaf(
            value: 30,
            options: BubbleOptions(
              child: Text(
                '30%',
                style: AppTextStyles.buttonSmall,
              ),
              color: Colors.lightGreen,
              onTap: () => print('Secondary bubble tapped'),
            ),
          ),
          BubbleNode.leaf(
            value: 20,
            options: BubbleOptions(
              child: Text(
                '20%',
                style: AppTextStyles.buttonSmall,
              ),
              color: Colors.black87,
              onTap: () => print('Other bubble tapped'),
            ),
          ),
        ],
        options: BubbleOptions(color: Colors.transparent),
      ),
    ];
  }
}
